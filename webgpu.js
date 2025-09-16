async function buildEntirePipeline({ WORKGROUP_SIZE, buildShader, swapBuffers, hashList }) {
    let shaders = []
    let pbkdf2Code = (await fetch('wgsl/pbkdf2.wgsl').then(r => r.text())).replaceAll('WORKGROUP_SIZE', WORKGROUP_SIZE.toString(10))
    let deriveCode = (await fetch('wgsl/derive_coin.wgsl').then(r => r.text())).replaceAll('WORKGROUP_SIZE', WORKGROUP_SIZE.toString(10))
    let secp256k1Code = (await fetch('wgsl/secp256k1.wgsl').then(r => r.text())).replaceAll('WORKGROUP_SIZE', WORKGROUP_SIZE.toString(10))
    let hash160Code = (await fetch('wgsl/hash160.wgsl').then(r => r.text()))
        .replaceAll('WORKGROUP_SIZE', WORKGROUP_SIZE.toString(10))
        .replaceAll('CHECK_COUNT', hashList.length.toString(10))
        .replaceAll('CHECK_HASHES', hash160ToWGSLArray(hashList))
    
    shaders.push(await buildShader(pbkdf2Code, 'main'))
    swapBuffers()
    shaders.push(await buildShader(deriveCode, 'derive1'))
    swapBuffers()
    const secp256k1Shader = await buildShader(secp256k1Code, 'main')
    shaders.push(secp256k1Shader)
    swapBuffers()
    const derive2Shader = await buildShader(deriveCode, 'derive2', WORKGROUP_SIZE)
    shaders.push(derive2Shader)
    swapBuffers()
    shaders.push(secp256k1Shader)
    swapBuffers()
    shaders.push(derive2Shader)
    swapBuffers()
    shaders.push(secp256k1Shader)
    swapBuffers()
    shaders.push(await buildShader(hash160Code, 'main', WORKGROUP_SIZE))
    return shaders
}

function hash160ToWGSLArray(hash160List) {
    function valueLE(hash160, x) {
        return '0x'+(((hash160[x*4 + 3] << 24) |
            (hash160[x*4 + 2] << 16) |
            (hash160[x*4 + 1] << 8) | 
            hash160[x*4]) >>> 0).toString(16)+'u'
    }
    return hash160List.map(hash160 => 
      `array<u32, 5>(${valueLE(hash160, 0)}, ${valueLE(hash160, 1)}, ${valueLE(hash160, 2)}, ${valueLE(hash160, 3)}, ${valueLE(hash160, 4)})`
    ).join(',\n')
}

async function webGPUinit({ BUF_SIZE, adapter, device }) {
    assert(navigator.gpu, 'Browser not support WebGPU')
    assert(BUF_SIZE, 'no BUF_SIZE passed')
    const precomputeTable = await prepareCompute()
    if (!adapter && !device) {
        adapter = await navigator.gpu.requestAdapter({ powerPreference: 'high-performance' })
        device = await adapter.requestDevice() 
    }
    var closed = false
    device.lost.then(()=>{
        assert(closed, 'WebGPU logical device was lost.')
        console.log('Cleaned WebGPU device resources')
    })

    const secp256k1PrecomputeBuffer = device.createBuffer({
        size: precomputeTable.length * 4,
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC,
    })

    var buffers = {
        inp: device.createBuffer({
            size: BUF_SIZE,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC,
        }),
        out: device.createBuffer({
            size: BUF_SIZE,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC,
        }),
    }

    const stagingBuffer = device.createBuffer({
        size: 1024,
        usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST,
    });

    device.queue.writeBuffer(secp256k1PrecomputeBuffer, 0, precomputeTable)

    function clean() {
        secp256k1PrecomputeBuffer.destroy()
        buffers.inp.destroy()
        buffers.out.destroy()
        stagingBuffer.destroy()
        closed = true
        device.destroy()
    }

    const inpBuffer = buffers.inp
    let outBuffer = buffers.out

    async function inference({ WORKGROUP_SIZE, shaders, inp, count }) {
        assert(WORKGROUP_SIZE, `expected WORKGROUP_SIZE, got ${inp?.length}`)
        assert(inp?.length <= BUF_SIZE / 4, `expected input size to be <= ${BUF_SIZE / 4}, got ${inp?.length}`)
        device.queue.writeBuffer(inpBuffer, 0, inp)
        const commandEncoder = device.createCommandEncoder()
        const passEncoder = commandEncoder.beginComputePass()
        for(let { bindGroup, pipeline } of shaders) {
            passEncoder.setBindGroup(0, bindGroup)
            passEncoder.setPipeline(pipeline)
            passEncoder.dispatchWorkgroups(Math.ceil(count / WORKGROUP_SIZE))
        }
        passEncoder.end()
        commandEncoder.copyBufferToBuffer(outBuffer, 0, stagingBuffer, 0, 1024)
        device.queue.submit([commandEncoder.finish()])
        await stagingBuffer.mapAsync(GPUMapMode.READ, 0, 1024)
        const copyArrayBuffer = stagingBuffer.getMappedRange(0, 1024)
        const result = new Uint32Array(copyArrayBuffer.slice(), 0, 256)
        stagingBuffer.unmap()
        return result
    }

    const bindGroupLayout = device.createBindGroupLayout({
        entries: [
            {
                binding: 0,
                visibility: GPUShaderStage.COMPUTE,
                buffer: { type: 'read-only-storage' }
            },
            {
                binding: 1,
                visibility: GPUShaderStage.COMPUTE,
                buffer: { type: 'storage' },
            },
            {
                binding: 2,
                visibility: GPUShaderStage.COMPUTE,
                buffer: { type: 'read-only-storage' },
            },
        ],
    });
    const bindGroup1 = device.createBindGroup({
        layout: bindGroupLayout,
        entries: [{
            binding: 0,
            resource: { buffer: buffers.inp },
        }, {
            binding: 1,
            resource: { buffer: buffers.out },
        }, {
            binding: 2,
            resource: { buffer: secp256k1PrecomputeBuffer },
        }],
    })

    const bindGroup2 = device.createBindGroup({
        layout: bindGroupLayout,
        entries: [{
            binding: 0,
            resource: { buffer: buffers.out },
        }, {
            binding: 1,
            resource: { buffer: buffers.inp },
        }, {
            binding: 2,
            resource: { buffer: secp256k1PrecomputeBuffer },
        }],
    })

    let bindGroup = bindGroup1

    async function buildShader(code, entryPoint) {
      const module = device.createShaderModule({ code })
      const shaderInfo = await module.getCompilationInfo()
      if (shaderInfo.messages?.length > 0) {
        console.error(shaderInfo.messages)
        log('Some error ocurred during shader compiling')
      }
  
      let pipeline
      try {
        pipeline = await device.createComputePipelineAsync({
          layout: device.createPipelineLayout({
            bindGroupLayouts: [bindGroupLayout],
          }),
          compute: { module, entryPoint},
        });
      } catch (e) {
        console.error(e)
        log(`Pipeline creation error: ${e.message}`)
      }
      return { bindGroup, pipeline }
    }

    return {
        name: adapter.info.description || adapter.info.vendor,
        clean,
        swapBuffers() {
            if (bindGroup === bindGroup1) {
              bindGroup = bindGroup2
              outBuffer = buffers.inp
            } else {
              bindGroup = bindGroup1
              outBuffer = buffers.out
            }
        },
        inference,
        buildShader,
    }
}

// ====================================== helper methods


async function getPasswords(url) {
  const resp = await fetch(url)
  if (!resp.ok) throw new Error(`HTTP ${resp.status}`)
  const reader = resp.body.getReader()
  let partialBuf = new Uint8Array(0)
  let ended = false

  async function batch(passwordsCount) {
    if (ended) return null
    const offsets = new Uint32Array(passwordsCount)
    const chunks = []
    let totalLen = 0
    let count = 0
    const PASSW_OFFSET = 128 + passwordsCount*4

    while (count < passwordsCount && !ended) {
      let newlinePos
      while (
        count < passwordsCount &&
        (newlinePos = partialBuf.indexOf(10)) !== -1
      ) {
        const pwd = partialBuf.subarray(0, newlinePos + 1)
        offsets[count] = totalLen + PASSW_OFFSET
        chunks.push(pwd)
        totalLen += pwd.length
        count++
        partialBuf = partialBuf.subarray(newlinePos + 1)
      }

      if (count < passwordsCount && !ended) {
        const { done, value } = await reader.read()
        if (done) {
          ended = true
          if (partialBuf.length > 0 && count < passwordsCount) {
            offsets[count] = totalLen + PASSW_OFFSET
            chunks.push(partialBuf)
            totalLen += partialBuf.length
            count++
            partialBuf = new Uint8Array(0)
          }
          break
        } else {
          const buf = new Uint8Array(partialBuf.length + value.length)
          buf.set(partialBuf, 0)
          buf.set(value, partialBuf.length)
          partialBuf = buf
        }
      }
    }

    if (count === 0) return null

    let bufLen = 128 + offsets.byteLength + totalLen
    bufLen += 4 - bufLen % 4
    const flat = new Uint8Array(bufLen)
    var strbuf = new Uint8Array(offsets.buffer, offsets.byteOffset, offsets.byteLength)
    flat.set(strbuf, 128)
    let off = PASSW_OFFSET
    for (const c of chunks) {
      flat.set(c, off)
      off += c.length
    }
    return { passwords: flat.buffer, count };
  }

  return batch;
}

async function prepareCompute() {
    function precomputeSecp256k1Table(W, onBatch) {
    const P = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2fn;
    const M = (a, b = P) => { const r = a % b; return r >= 0n ? r : b + r; };
    function secp256k1_add({ X: X1, Y: Y1, Z: Z1 }, { X: X2, Y: Y2, Z: Z2 }) {
        let X3 = 0n, Y3 = 0n, Z3 = 0n; let t0 = M(X1 * X2); let t1 = M(Y1 * Y2); let t2 = M(Z1 * Z2);
        let t3 = M(X1 + Y1); let t4 = M(X2 + Y2); let t5 = M(X2 + Z2); t3 = M(t3 * t4);
        t4 = M(t0 + t1); t3 = M(t3 - t4); t4 = M(X1 + Z1); t4 = M(t4 * t5); t5 = M(t0 + t2);
        t4 = M(t4 - t5); t5 = M(Y1 + Z1); X3 = M(Y2 + Z2); t5 = M(t5 * X3); X3 = M(t1 + t2);
        t5 = M(t5 - X3); t2 = M(21n * t2); X3 = M(t1 - t2); Z3 = M(t1 + t2); Y3 = M(X3 * Z3);
        t1 = M(t0 + t0); t1 = M(t1 + t0); t4 = M(21n * t4); t0 = M(t1 * t4); Y3 = M(Y3 + t0);
        t0 = M(t5 * t4); X3 = M(t3 * X3); X3 = M(X3 - t0); t0 = M(t3 * t1); Z3 = M(t5 * Z3);
        Z3 = M(Z3 + t0); return { X: X3, Y: Y3, Z: Z3 };
    }
    function batchAff(pointsBatch) {
      let acc = 1n
      const invert = (num) => {
        let a = M(num, P), b = P, x = 0n, y = 1n, u = 1n, v = 0n;
        while (a !== 0n) {
            const q = b / a, r = b % a;
            const m = x - u * q, n = y - v * q;
            b = a, a = r, x = u, y = v, u = m, v = n;
          }
          return M(x, P);
        };
        const scratch = [1n].concat(pointsBatch.map(ni => acc = (acc * ni.Z) % P))
        let inv = invert(acc)
        const Zinv = new Array(pointsBatch.length);
        for (let i = pointsBatch.length - 1; i >= 0; i--) {
          Zinv[i] = (scratch[i] * inv) % P
          inv = (inv * pointsBatch[i].Z) % P
        }
        return Zinv.map((iz, i) => ({ X: M(pointsBatch[i].X * iz), Y: M(pointsBatch[i].Y * iz), Z: 1n }));
    }
    let p = { X: 0x79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798n, Y: 0x483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8n, Z: 1n };
    let b = p;
    for (let w = 0; w < Math.ceil(256 / W); w++) {
        b = p
        var pointsBatch = []
        pointsBatch.push(b);
        for (let i = 1; i < 2 ** (W - 1); i++) {
          b = secp256k1_add(b, p);
          pointsBatch.push(b);
        }
        onBatch(batchAff(pointsBatch), w)
        p = batchAff([secp256k1_add(b, b)])[0];
      }
    }

    const PRECOMPUTE_WINDOW = 8
    const PRECOMPUTE_SIZE = 2 ** (PRECOMPUTE_WINDOW - 1) * (Math.ceil(256 / PRECOMPUTE_WINDOW)) * 64
    const precomputeTable = new Uint32Array(PRECOMPUTE_SIZE / 4).fill(0)
    precomputeSecp256k1Table(PRECOMPUTE_WINDOW, (batch, i) => {
      batch.forEach(({X, Y}, j) => {
        const index = i * batch.length + j
        const xx = BigToU32_reverse(X)
        for (var x = 0; x < 8; x++) { precomputeTable[index*16 + x] = xx[x] }
        const yy = BigToU32_reverse(Y)
        for (var y = 0; y < 8; y++) { precomputeTable[index*16 + 8 + y] = yy[y] }
      })
    })
    return precomputeTable
}

function assert(cond, text) {
    if (!cond) {
        const err = new Error(text || 'unknown error')
        window.output.innerHTML += `❌ ${text || 'unknown error'}\n`
        err.stack = err.stack.split('\n').filter(x => !x.includes('at assert')).join('\n')
        throw err
    }
}

function bufUint32LESwap(buf, start, end) {
    for (let i = start; i + 3 < (end || buf.length); i += 4) {
        const a = buf[i]
        const b = buf[i + 1]
        const c = buf[i + 2]
        const d = buf[i + 3]

        buf[i] = d
        buf[i + 1] = c
        buf[i + 2] = b
        buf[i + 3] = a
    }
}

function BigToU32_reverse(n) {
    const hex = n.toString(16).padStart(64, '0')
    return hex.match(/.{1,8}/g).map(x => parseInt(x, 16)).reverse()
}

function log(text, clear=false) {
    if (clear) window.output.innerHTML = ''
    window.output.innerHTML += text + '\n'
}
