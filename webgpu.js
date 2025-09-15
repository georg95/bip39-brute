async function prepareCompute() {
    const PRECOMPUTE_WINDOW = 8
    const PRECOMPUTE_SIZE = 2 ** (PRECOMPUTE_WINDOW - 1) * (Math.ceil(256 / PRECOMPUTE_WINDOW)) * 64
    const precomputeTable = new Uint32Array(PRECOMPUTE_SIZE / 4).fill(0)
    precompute(PRECOMPUTE_WINDOW, (batch, i) => {
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
    shaders.push(await buildShader(secp256k1Code, 'main', WORKGROUP_SIZE))
    swapBuffers()
    shaders.push(await buildShader(deriveCode, 'derive2', WORKGROUP_SIZE))
    swapBuffers()
    shaders.push(await buildShader(secp256k1Code, 'main', WORKGROUP_SIZE))
    swapBuffers()
    shaders.push(await buildShader(deriveCode, 'derive2', WORKGROUP_SIZE))
    swapBuffers()
    shaders.push(await buildShader(secp256k1Code, 'main', WORKGROUP_SIZE))
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

async function webGPUinit({ BUF_SIZE, adapter, device, precomputeTable }) {
    assert(navigator.gpu, 'Browser not support WebGPU')
    assert(BUF_SIZE, 'no BUF_SIZE passed')
    assert(precomputeTable, 'no precompute table passed')
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
        size: BUF_SIZE,
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
        commandEncoder.copyBufferToBuffer(buffers.out, 0, stagingBuffer, 0, BUF_SIZE)
        device.queue.submit([commandEncoder.finish()])
        await stagingBuffer.mapAsync(GPUMapMode.READ, 0, BUF_SIZE)
        const copyArrayBuffer = stagingBuffer.getMappedRange(0, count * 20)
        const data = new Uint32Array(copyArrayBuffer.slice(), 0, count * 5)
        stagingBuffer.unmap()
        return data
    }

    async function buildShader(code, func) {
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
        const inpBuf = buffers.inp
        const outBuf = buffers.out
        const bindGroup = device.createBindGroup({
            layout: bindGroupLayout,
            entries: [{
                binding: 0,
                resource: { buffer: inpBuf },
            }, {
                binding: 1,
                resource: { buffer: outBuf },
            }, {
                binding: 2,
                resource: { buffer: secp256k1PrecomputeBuffer },
            }],
        })
        const pipeline = device.createComputePipeline({
            layout: device.createPipelineLayout({
                bindGroupLayouts: [bindGroupLayout],
            }),
            compute: {
                module: device.createShaderModule({
                    code,
                }),
                entryPoint: func,
            },
        });
        return {
            bindGroup,
            pipeline,
        }
    }

    return {
        name: adapter.info.description || adapter.info.vendor,
        clean,
        swapBuffers() {
            var inp = buffers.inp
            var out = buffers.out
            buffers.inp = out
            buffers.out = inp
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
  const totalBytes = Number(resp.headers.get("Content-Length")) || null
  let bytesRead = 0
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
    bytesRead += totalLen

    return {
      passwords: flat.buffer,
      offsets: offsets.slice(0, count).buffer,
      count,
      bytesRead,
      totalBytes,
      progress: totalBytes ? bytesRead / totalBytes : null
    };
  }

  return batch;
}

function assert(cond, text) {
    if (!cond) {
        const err = new Error(text || 'unknown error')
        window.output.innerHTML += `❌ ${text || 'unknown error'}\n`
        err.stack = err.stack.split('\n').filter(x => !x.includes('at assert')).join('\n')
        throw err
    }
}

function leSwap(str) {
    return str[6]+str[7]+str[4]+str[5]+str[2]+str[3]+str[0]+str[1]
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

function toHex(arr) {
    if (arr instanceof Uint8Array) {
        return Array.from(arr).map(b => b.toString(16).padStart(2, '0')).join('');
    }
    if (arr instanceof Uint32Array) {
        return Array.from(arr).map(b => b.toString(16).padStart(8, '0')).join('');
    }
    throw new Error('toHex expect u8/u32')
}

function u32Buf(hex) {
    const inp = new Uint32Array(1024).fill(0)
    assert(hex.length % 8 === 0, `setBuf expect input of length 8*n, got: ${hex}`)
    const values = hex.match(/.{1,8}/g).map(x => parseInt(x, 16))
    inp.set(new Uint32Array(values), 0)
    return inp
}

function BigToU32_reverse(n) {
    const hex = n.toString(16).padStart(64, '0')
    return hex.match(/.{1,8}/g).map(x => parseInt(x, 16)).reverse()
}

function log(text, clear=false) {
    if (clear) window.output.innerHTML = ''
    window.output.innerHTML += text + '\n'
}
