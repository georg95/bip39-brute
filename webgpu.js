const ADDRTYPEMAP = {
  'p2wphk': [84, 0],
  'p2pkh': [44, 0],
  'p2sh': [49, 0],
  'eth': [44, 60],
  'tron': [44, 195],
  'solana': [44, 501],
}
async function buildEntirePipeline({ addrType, MNEMONIC, WORKGROUP_SIZE, buildShader, swapBuffers, hashList }) {
    assert(addrType && ADDRTYPEMAP[addrType] && MNEMONIC && WORKGROUP_SIZE && buildShader && swapBuffers && hashList)
    const [NETWORK, COIN_TYPE] = ADDRTYPEMAP[addrType]
    let shaders = []
    let pbkdf2Code = (await fetch('wgsl/pbkdf2_template.wgsl').then(r => r.text()))
    pbkdf2Code = (await unrolledSha512_wgpu(pbkdf2Code, MNEMONIC))
        .replaceAll('WORKGROUP_SIZE', WORKGROUP_SIZE.toString(10))
    // unrolled code
    // console.log(pbkdf2Code)
    let deriveCode = (await fetch('wgsl/derive_coin.wgsl').then(r => r.text()))
        .replaceAll('WORKGROUP_SIZE', WORKGROUP_SIZE.toString(10))
        .replaceAll('NETWORK', NETWORK)
        .replaceAll('COIN_TYPE', COIN_TYPE)

    console.time('[COMPILE] pbkdf2');
    shaders.push(await buildShader(pbkdf2Code, 'main', WORKGROUP_SIZE))
    console.timeEnd('[COMPILE] pbkdf2');
    swapBuffers()
    console.time('[COMPILE] deriveCoin');
    shaders.push(await buildShader(deriveCode, addrType === 'solana' ? 'deriveSolana' : 'deriveCoin', WORKGROUP_SIZE))
    console.timeEnd('[COMPILE] deriveCoin');
    swapBuffers()

    if (addrType === 'solana') {
        let ed25519Code = (await fetch('wgsl/ed25519.wgsl').then(r => r.text()))
          .replaceAll('WORKGROUP_SIZE', WORKGROUP_SIZE.toString(10))
          .replaceAll('CHECK_COUNT', hashList.length.toString(10))
          .replaceAll('CHECK_KEYS', solanaPkListToWGSLArray(hashList))
        console.time('[COMPILE] ed25519');
        shaders.push(await buildShader(ed25519Code, 'main', WORKGROUP_SIZE))
        console.timeEnd('[COMPILE] ed25519');
        swapBuffers()
        return shaders
    }

    let secp256k1Code = (await fetch('wgsl/secp256k1.wgsl').then(r => r.text())).replaceAll('WORKGROUP_SIZE', WORKGROUP_SIZE.toString(10))
    console.time('[COMPILE] secp256k1');
    const secp256k1Shader = await buildShader(secp256k1Code, 'main', WORKGROUP_SIZE)
    console.timeEnd('[COMPILE] secp256k1');
    shaders.push(secp256k1Shader)
    swapBuffers()
    console.time('[COMPILE] deriveAddr');
    const derive2Shader = await buildShader(deriveCode, 'deriveAddr', WORKGROUP_SIZE)
    console.timeEnd('[COMPILE] deriveAddr');
    shaders.push(derive2Shader)
    swapBuffers()
    shaders.push(secp256k1Shader)
    swapBuffers()
    shaders.push(derive2Shader)
    swapBuffers()
    shaders.push(secp256k1Shader)
    swapBuffers()


    console.time('[COMPILE] keccak/hash160');
    if (addrType === 'eth' || addrType === 'tron') {
      let keccakCode = (await fetch('wgsl/keccak256.wgsl').then(r => r.text()))
        .replaceAll('WORKGROUP_SIZE', WORKGROUP_SIZE.toString(10))
        .replaceAll('CHECK_COUNT', hashList.length.toString(10))
        .replaceAll('CHECK_HASHES', hash160ToWGSLArray(hashList))
      shaders.push(await buildShader(keccakCode, 'main', WORKGROUP_SIZE))
    } else if (addrType === 'p2sh') {
      let hash160Code = (await fetch('wgsl/hash160.wgsl').then(r => r.text()))
        .replaceAll('WORKGROUP_SIZE', WORKGROUP_SIZE.toString(10))
        .replaceAll('CHECK_COUNT', hashList.length.toString(10))
        .replaceAll('CHECK_HASHES', hash160ToWGSLArray(hashList))
      shaders.push(await buildShader(hash160Code, 'p2sh', WORKGROUP_SIZE))
    } else {
      let hash160Code = (await fetch('wgsl/hash160.wgsl').then(r => r.text()))
        .replaceAll('WORKGROUP_SIZE', WORKGROUP_SIZE.toString(10))
        .replaceAll('CHECK_COUNT', hashList.length.toString(10))
        .replaceAll('CHECK_HASHES', hash160ToWGSLArray(hashList))
      shaders.push(await buildShader(hash160Code, 'main', WORKGROUP_SIZE))
    }

    console.timeEnd('[COMPILE] keccak/hash160');
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

function solanaPkListToWGSLArray(publicKeyList) {
    function valueLE(publicKey, x) {
        return '0x'+(((publicKey[x*4 + 3] << 24) |
            (publicKey[x*4 + 2] << 16) |
            (publicKey[x*4 + 1] << 8) | 
            publicKey[x*4]) >>> 0).toString(16)+'u'
    }
    const arr = Array(8).fill(0)
    return publicKeyList.map(publicKey => 
        `array<u32, 8>(${arr.map((_, i) => valueLE(publicKey, i)).join(', ')})`
    ).join(',\n')
}

async function webGPUinit({ BUF_SIZE, eccType, adapter, device }) {
    assert(navigator.gpu, 'Browser not support WebGPU')
    assert(BUF_SIZE, 'no BUF_SIZE passed')
    const precomputeTable = await precomputeEccTable(eccType)
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
        size: 4096,
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

    async function inference({ shaders, inp, count }) {
        assert(inp?.length <= BUF_SIZE / 4, `expected input size to be <= ${BUF_SIZE / 4}, got ${inp?.length}`)
        device.queue.writeBuffer(shaders[0].bufferIn, 0, inp)
        const commandEncoder = device.createCommandEncoder()
        const passEncoder = commandEncoder.beginComputePass()
        for(let { binding, pipeline, workPerWarp } of shaders) {
            passEncoder.setBindGroup(0, binding)
            passEncoder.setPipeline(pipeline)
            passEncoder.dispatchWorkgroups(Math.ceil(count / workPerWarp))
        }
        passEncoder.end()
        commandEncoder.copyBufferToBuffer(shaders[shaders.length - 1].bufferOut, 0, stagingBuffer, 0, 4096)
        device.queue.submit([commandEncoder.finish()])
        await stagingBuffer.mapAsync(GPUMapMode.READ, 0, 4096)
        const copyArrayBuffer = stagingBuffer.getMappedRange(0, 4096)
        const result = new Uint32Array(copyArrayBuffer.slice(), 0, 1024)
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
    const bindGroup1 = {
      binding: device.createBindGroup({
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
      }),
      bufferIn: buffers.inp,
      bufferOut: buffers.out,
    }

    const bindGroup2 = {
      binding: device.createBindGroup({
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
      }),
      bufferIn: buffers.out,
      bufferOut: buffers.inp,
    }

    let bindGroup = bindGroup1

    async function buildShader(code, entryPoint, workPerWarp) {
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
      return { ...bindGroup, pipeline, workPerWarp }
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

async function precomputeEccTable(type) {
    if (type !== 'ed25519' && type !== 'secp256k1') {
       console.warn(`Unknown ecc type ${type} - empty precompute table`)
       return new Uint32Array(1024)
    }
    const W = 16;
    const ELEMENT_SIZE = type === 'ed25519' ? 3 * 8 : 2 * 8;
    const TOTAL_POINTS = (256 / W) * (1 << (W - 1));
    const CHUNK_SIZE = TOTAL_POINTS * ELEMENT_SIZE / 16
    const workerCode = `
    self.onmessage = function(e) {
        const { w, type } = e.data;
        if (type === 'ed25519') {
            precomputeEd25519Table(w);
        } else {
            precomputeSecp256k1Table(w);
        }
    };

    function BigToU32_reverse(n) {
        const hex = n.toString(16).padStart(64, '0')
        return hex.match(/.{1,8}/g).map(x => parseInt(x, 16)).reverse()
    }
    function batchAff(pointsBatch, P) {
        const M = (a, b = P) => { const r = a % b; return r >= 0n ? r : b + r; };
        let acc = 1n
        const invert = (num, P) => {
            let a = M(num, P), b = P, x = 0n, y = 1n, u = 1n, v = 0n;
            while (a !== 0n) {
                const q = b / a, r = b % a;
                const m = x - u * q, n = y - v * q;
                b = a, a = r, x = u, y = v, u = m, v = n;
            }
            return M(x, P);
        };
        const scratch = [1n].concat(pointsBatch.map(ni => acc = (acc * ni.Z) % P))
        let inv = invert(acc, P)
        const Zinv = new Array(pointsBatch.length);
        for (let i = pointsBatch.length - 1; i >= 0; i--) {
            Zinv[i] = (scratch[i] * inv) % P
            inv = (inv * pointsBatch[i].Z) % P
        }
        return Zinv.map((iz, i) => ({ X: M(pointsBatch[i].X * iz), Y: M(pointsBatch[i].Y * iz), Z: 1n }));
    }

    function precomputeSecp256k1Table(w) {
        const table = new Uint32Array(${CHUNK_SIZE});
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
        let p = { X: 0x79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798n, Y: 0x483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8n, Z: 1n };
        for (let i = 0; i < 16 * w; i++) {
            p = secp256k1_add(p, p)
        }
        var pointsBatch = [p]
        var b = p
        for (let i = 1; i < ${2 ** (W - 1)}; i++) {
            b = secp256k1_add(b, p)
            pointsBatch.push(b)
        }
        batchAff(pointsBatch, P).forEach(({X, Y}, i) => {
            const xx = BigToU32_reverse(X)
            for (var k = 0; k < 8; k++) { table[i*16 + k] = xx[k] }
            const yy = BigToU32_reverse(Y)
            for (var k = 0; k < 8; k++) { table[i*16 + 8 + k] = yy[k] }
        })
        self.postMessage({ table });
    }

    function precomputeEd25519Table(w) {
        const table = new Uint32Array(${CHUNK_SIZE});
        const P = 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffedn;
        const d = 0x52036cee2b6ffe738cc740797779e89800700a4d4141d8ab75eb4dca135978a3n;
        const d2 = (d * 2n) % P;
        const M = (a, b = P) => { const r = a % b; return r >= 0n ? r : b + r; };
        function ed25519_add({ X: X1, Y: Y1, Z: Z1, T: T1 }, { X: X2, Y: Y2, Z: Z2, T: T2 }) {
            const a = 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffecn;
            const A = M(X1 * X2), B = M(Y1 * Y2), C = M(T1 * d * T2), D = M(Z1 * Z2);
            const E = M((X1 + Y1) * (X2 + Y2) - A - B), F = M(D - C), G = M(D + C), H = M(B - a * A);
            return { X: M(E * F), Y: M(G * H), T: M(E * H), Z: M(F * G) }
        }
        let p = { X: 0x216936d3cd6e53fec0a4e231fdd6dc5c692cc7609525a7b2c9562d608f25d51an, Y: 0x6666666666666666666666666666666666666666666666666666666666666658n, Z: 1n }
        p.T = M(p.X * p.Y)
        for (let i = 0; i < 16 * w; i++) {
            p = ed25519_add(p, p)
        }
        var pointsBatch = [p]
        var b = p
        for (let i = 1; i < ${2 ** (W - 1)}; i++) {
            b = ed25519_add(b, p)
            pointsBatch.push(b)
        }
        batchAff(pointsBatch, P).forEach(({X, Y}, i) => {
            const xx = BigToU32_reverse(X)
            for (var k = 0; k < 8; k++) { table[i*24 + k] = xx[k] }
            const yy = BigToU32_reverse(Y)
            for (var k = 0; k < 8; k++) { table[i*24 + 8 + k] = yy[k] }
            const d2xy = BigToU32_reverse((d2*X*Y) % P)
            for (var k = 0; k < 8; k++) { table[i*24 + 16 + k] = d2xy[k] }
        })
        self.postMessage({ table });
    }
    `;

    const table = new Uint32Array(TOTAL_POINTS * ELEMENT_SIZE)
    const blob = new Blob([workerCode], { type: "application/javascript" });
    var start = performance.now()
    await Promise.all(Array(16).fill(0).map((_, w) => {
        const worker = new Worker(URL.createObjectURL(blob));
        worker.postMessage({ w, type });
        return new Promise(res => {
            worker.onmessage = ({ data }) => { table.set(data.table, w * CHUNK_SIZE); res() };
        })
    }))
    console.log(`Created ${type} table,`, TOTAL_POINTS * ELEMENT_SIZE * 4 / 1024 / 1024 | 0, 'Mb, in', performance.now() - start | 0, 'ms')
    return table
}

async function precomputeEccTable_(type) {
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
        onBatch(batchAff(pointsBatch, P), w)
        p = batchAff([secp256k1_add(b, b)], P)[0];
      }
    }

    function batchAff(pointsBatch, P) {
        const M = (a, b = P) => { const r = a % b; return r >= 0n ? r : b + r; };
        let acc = 1n
        const invert = (num, P) => {
            let a = M(num, P), b = P, x = 0n, y = 1n, u = 1n, v = 0n;
            while (a !== 0n) {
                const q = b / a, r = b % a;
                const m = x - u * q, n = y - v * q;
                b = a, a = r, x = u, y = v, u = m, v = n;
            }
            return M(x, P);
        };
        const scratch = [1n].concat(pointsBatch.map(ni => acc = (acc * ni.Z) % P))
        let inv = invert(acc, P)
        const Zinv = new Array(pointsBatch.length);
        for (let i = pointsBatch.length - 1; i >= 0; i--) {
            Zinv[i] = (scratch[i] * inv) % P
            inv = (inv * pointsBatch[i].Z) % P
        }
        return Zinv.map((iz, i) => ({ X: M(pointsBatch[i].X * iz), Y: M(pointsBatch[i].Y * iz), Z: 1n }));
    }

    function precomputeEd25519Table(W, onBatch) {
      const P = 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffedn
      const M = (a, b = P) => { const r = a % b; return r >= 0n ? r : b + r; };
      function ed25519_add({ X: X1, Y: Y1, Z: Z1, T: T1 }, { X: X2, Y: Y2, Z: Z2, T: T2 }) {
          const a = 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffecn;
          const d = 0x52036cee2b6ffe738cc740797779e89800700a4d4141d8ab75eb4dca135978a3n;
          const A = M(X1 * X2), B = M(Y1 * Y2), C = M(T1 * d * T2), D = M(Z1 * Z2);
          const E = M((X1 + Y1) * (X2 + Y2) - A - B), F = M(D - C), G = M(D + C), H = M(B - a * A);
          return { X: M(E * F), Y: M(G * H), T: M(E * H), Z: M(F * G) }
      }
      let p = { X: 0x216936d3cd6e53fec0a4e231fdd6dc5c692cc7609525a7b2c9562d608f25d51an, Y: 0x6666666666666666666666666666666666666666666666666666666666666658n, Z: 1n }
      let b;
      for (let w = 0; w < Math.ceil(256 / W); w++) {
        p.T = M(p.X * p.Y)
        b = p
        var pointsBatch = []
        pointsBatch.push(b)
        for (let i = 1; i < 2 ** (W - 1); i++) {
          b = ed25519_add(b, p)
          pointsBatch.push(b)
        }
        onBatch(batchAff(pointsBatch, P), w)
        p = batchAff([ed25519_add(b, b)], P)[0]
      }
    }

    const PRECOMPUTE_WINDOW = 16
    const PRECOMPUTE_SIZE = 2 ** (PRECOMPUTE_WINDOW - 1) * (Math.ceil(256 / PRECOMPUTE_WINDOW)) * (type === 'ed25519' ? 96 : 64)
    const precomputeTable = new Uint32Array(PRECOMPUTE_SIZE / 4).fill(0)
    const start = performance.now()
    if (type === 'ed25519') {
      const d2 = 0x52036cee2b6ffe738cc740797779e89800700a4d4141d8ab75eb4dca135978a3n * 2n;
      const P = 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffedn;
      precomputeEd25519Table(PRECOMPUTE_WINDOW, (batch, i) => {
        batch.forEach(({X, Y}, j) => {
          const index = i * batch.length + j
          const xx = BigToU32_reverse(X)
          for (var k = 0; k < 8; k++) { precomputeTable[index*24 + k] = xx[k] }
          const yy = BigToU32_reverse(Y)
          for (var k = 0; k < 8; k++) { precomputeTable[index*24 + 8 + k] = yy[k] }
          const d2xy = BigToU32_reverse((d2*X*Y) % P)
          for (var k = 0; k < 8; k++) { precomputeTable[index*24 + 16 + k] = d2xy[k] }
        })
      })
    } else {
      precomputeSecp256k1Table(PRECOMPUTE_WINDOW, (batch, i) => {
        batch.forEach(({X, Y}, j) => {
          const index = i * batch.length + j
          const xx = BigToU32_reverse(X)
          for (var x = 0; x < 8; x++) { precomputeTable[index*16 + x] = xx[x] }
          const yy = BigToU32_reverse(Y)
          for (var y = 0; y < 8; y++) { precomputeTable[index*16 + 8 + y] = yy[y] }
        })
      })
    }
    console.log(`precompute ${type} table in`, performance.now() - start | 0, 'ms')
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

async function unrolledSha512_wgpu(template, MNEMONIC) {
  var snippet0 = (i) => `
      t1_lo = hlo + (((elo >> 14) | (ehi << 18)) ^ ((elo >> 18) | (ehi << 14)) ^ ((ehi >> 9) | (elo << 23)));
      t1_hi = hhi + (((ehi >> 14) | (elo << 18)) ^ ((ehi >> 18) | (elo << 14)) ^ ((elo >> 9) | (ehi << 23))) + select(0u, 1u, t1_lo < hlo);
      tmp = (elo & flo) ^ ((~elo) & glo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((ehi & fhi) ^ ((~ehi) & ghi)) + select(0u, 1u, t1_lo < tmp);
      t1_lo = t1_lo + K[${i + 1}];
      t1_hi = t1_hi + K[${i}] + select(0u, 1u, t1_lo < K[${i + 1}]);
      t1_lo = t1_lo + W[${i + 1}];
      t1_hi = t1_hi + W[${i}] + select(0u, 1u, t1_lo < W[${i + 1}]);
      tmp = ((alo >> 28) | (ahi << 4)) ^ ((ahi >> 2) | (alo << 30)) ^ ((ahi >> 7) | (alo << 25));
      t2_lo = tmp + ((alo & blo) ^ (alo & clo) ^ (blo & clo));
      t2_hi = (((ahi >> 28) | (alo << 4)) ^ ((alo >> 2) | (ahi << 30)) ^ ((alo >> 7) | (ahi << 25))) + ((ahi & bhi) ^ (ahi & chi) ^ (bhi & chi)) + select(0u, 1u, t2_lo < tmp);
      dlo += t1_lo;
      dhi += t1_hi + select(0u, 1u, dlo < t1_lo);
      hlo = t1_lo + t2_lo;
      hhi = t1_hi + t2_hi + select(0u, 1u, hlo < t1_lo);`;

  var snippet = (i) => {
    var xhi1 = `W[${(i + 28) & 0x1f}]`
    var xlo1 = `W[${(i + 29) & 0x1f}]`
    var xhi2 = `W[${(i + 2) & 0x1f}]`
    var xlo2 = `W[${(i + 3) & 0x1f}]`
    return `
      t1_lo = ((${xhi1} >> 19) | (${xlo1} << 13)) ^ ((${xlo1} >> 29) | (${xhi1} << 3)) ^ (${xhi1} >> 6);
      t1_hi = ((${xlo1} >> 19) | (${xhi1} << 13)) ^ ((${xhi1} >> 29) | (${xlo1} << 3)) ^ ((${xlo1} >> 6) | (${xhi1} << 26));
      t2_hi = ((${xhi2} >> 1) | (${xlo2} << 31)) ^ ((${xhi2} >> 8) | (${xlo2} << 24)) ^ (${xhi2} >> 7);
      t2_lo = ((${xlo2} >> 1) | (${xhi2} << 31)) ^ ((${xlo2} >> 8) | (${xhi2} << 24)) ^ ((${xlo2} >> 7) | (${xhi2} << 25));
      acc_lo = W[${(i + 19) & 0x1f}] + W[${(i + 1) & 0x1f}];
      acc_hi = W[${(i + 18) & 0x1f}] + W[${i & 0x1f}] + select(0u, 1u, acc_lo < W[${(i + 19) & 0x1f}]);
      acc_lo = acc_lo + t1_hi;
      acc_hi = acc_hi + t1_lo + select(0u, 1u, acc_lo < t1_hi);
      W[${(i + 1) & 0x1f}] = acc_lo + t2_lo;
      W[${i & 0x1f}] = acc_hi + t2_hi + select(0u, 1u, W[${(i + 1) & 0x1f}] < t2_lo);
      t1_lo = hlo + (((elo >> 14) | (ehi << 18)) ^ ((elo >> 18) | (ehi << 14)) ^ ((ehi >> 9) | (elo << 23)));
      t1_hi = hhi + (((ehi >> 14) | (elo << 18)) ^ ((ehi >> 18) | (elo << 14)) ^ ((elo >> 9) | (ehi << 23))) + select(0u, 1u, t1_lo < hlo);
      tmp = (elo & flo) ^ ((~elo) & glo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((ehi & fhi) ^ ((~ehi) & ghi)) + select(0u, 1u, t1_lo < tmp);
      t1_lo = t1_lo + K[i + ${i + 1}];
      t1_hi = t1_hi + K[i + ${i}] + select(0u, 1u, t1_lo < K[i + ${i + 1}]);
      t1_lo = t1_lo + W[${(i + 1) & 0x1f}];
      t1_hi = t1_hi + W[${i & 0x1f}] + select(0u, 1u, t1_lo < W[${(i + 1) & 0x1f}]);
      tmp = ((alo >> 28) | (ahi << 4)) ^ ((ahi >> 2) | (alo << 30)) ^ ((ahi >> 7) | (alo << 25));
      t2_lo = tmp + ((alo & blo) ^ (alo & clo) ^ (blo & clo));
      t2_hi = (((ahi >> 28) | (alo << 4)) ^ ((alo >> 2) | (ahi << 30)) ^ ((alo >> 7) | (ahi << 25))) + ((ahi & bhi) ^ (ahi & chi) ^ (bhi & chi)) + select(0u, 1u, t2_lo < tmp);
      dlo += t1_lo;
      dhi += t1_hi + select(0u, 1u, dlo < t1_lo);
      hlo = t1_lo + t2_lo;
      hhi = t1_hi + t2_hi + select(0u, 1u, hlo < t1_lo);`
  };

  function rollX(snippet, x) {
    function roll(curSnippet) {
      const letters = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']
      let curS = curSnippet.replaceAll('ahi', 'XXXXhi').replaceAll('alo', 'XXXXlo')
      for (let letter of letters.slice(1)) {
        const next = letters[letters.indexOf(letter) - 1]
        curS = curS.replaceAll(letter+'hi', next+'hi').replaceAll(letter+'lo', next+'lo')
      }
      curS = curS.replaceAll('XXXXhi', 'hhi').replaceAll('XXXXlo', 'hlo')
      return curS
    }
    let curS = snippet
    for (let i = 0; i < x; i++) { curS = roll(curS) }
    return curS
  }

  var INIT_ROUNDS = ''
  for (let i = 0; i < 32; i+=2) {
    INIT_ROUNDS += rollX(snippet0(i), i / 2)
  }

  var MAIN_ROUNDS = ''
  for (let i = 0; i < 32; i+=2) {
    MAIN_ROUNDS += rollX(snippet(i), i / 2)
  }

  const seed1 = Array.from(await sha512round(MNEMONIC, 0x36)).map(x => '0x'+x.toString(16)+'u')
  const seed2 = Array.from(await sha512round(MNEMONIC, 0x5c)).map(x => '0x'+x.toString(16)+'u')

  for (let i = 15; i >= 0; i--) {
    template = template.replaceAll(`SEED1_${i}`, seed1[i]).replaceAll(`SEED2_${i}`, seed2[i])
  }
  template = template.replaceAll('INIT_BUF', Array(32).fill(0).map((_, i) => `var W${i} = buf[${i}];`).join(' '))

  template = template.replaceAll('INIT_ROUNDS', INIT_ROUNDS).replaceAll('MAIN_ROUNDS', `
    for (var i: u32 = 32u; i < 160u; i += 32u) {
      ${MAIN_ROUNDS}
    }
  `)

  for (let i = 31; i >= 0; i--) {
    template = template.replaceAll(`W[${i}]`, `W${i}`)
  }

  return template
}


async function sha512round(mnemo, XOR) {
  const SHA512_WASM = new Uint8Array((
  "0061736d010000000105016000017f030302000005030100110619037f01418080c0000b7f00418085c0000b7f00418086c0000b073805066d656d6f" +
  "727902000b6765744d6e656d6f5074720000086d6e656d6f6e696303010b7368613531325f7761736d0001047365656403020afc0a020800418085c0" +
  "80000bf00a01277f2380808080004180056b220024808080800041002101037f02402001418001470d00412021024100210303400240200241a00149" +
  "0d0041f9c2f89b01210441999a83df05210541ebfa865a210641abb38ffc01210741e7cca7d0062108418892f39d7f21094185dd9edb7b210a41bbce" +
  "aaa678210341f2e6bbe303210b41abf0d374210c41baeabfaa7a210d41f1edf4f805210e41ffa4b98805210f41d1859aef7a2101418cd195d8792110" +
  "419fd8f9d9022111410021124100211302400340200621142007211520102107201121062013419f014b0d012001410e742116200141127421172001" +
  "41097621182012418080c080006a21192012418480c080006a2102200020126a211a2003200c71211b2003200c73211c2009410276211d2009410474" +
  "211e2009410776211f200a200b712120200a200b732121201241086a2112201341026a211320012111200f2110201a41046a28020022222002280200" +
  "22232004200f4112742001410e7672200f410e74200141127672732001411774200f41097672736a222420142001417f73712001200671726a22256a" +
  "22266a2202200e6a220e210120052017200f410e76722016200f41127672732018200f41177472736a2015200f417f7371200f200771726a20242004" +
  "496a20252024496a20192802006a20262023496a201a2802006a20022022496a2204200d6a200e2002496a210f200c210e200b210d2003210c200a21" +
  "0b200921032008210a200220084104742009411c76722009411e7420084102767273200941197420084107767273221a201b2009201c71736a22246a" +
  "22052109201e2008411c7672201d2008411e747273201f2008411974727320202008202171736a2024201a496a20046a20052002496a210820152105" +
  "201421040c000b0b4100200441f9c2f89b016a3602bc86c080004100201441ebfa865a6a3602b486c0800041002006419fd8f9d9026a3602ac86c080" +
  "004100200141d1859aef7a6a3602a486c080004100200e41f1edf4f8056a36029c86c080004100200c41abf0d3746a36029486c080004100200341bb" +
  "ceaaa6786a36028c86c0800041002009418892f39d7f6a36028486c080004100419a9a83df0541999a83df0520044186bd87e47e4b1b20056a3602b8" +
  "86c08000410041acb38ffc0141abb38ffc012014419485f9254b1b20156a3602b086c080004100418dd195d879418cd195d879200641e0a786a67d4b" +
  "1b20076a3602a886c0800041004180a5b9880541ffa4b98805200141aefae590054b1b200f6a3602a086c08000410041bbeabfaa7a41baeabfaa7a20" +
  "0e418e928b877a4b1b200d6a36029886c08000410041f3e6bbe30341f2e6bbe303200c41d48fac0b4b1b200b6a36029086c0800041004186dd9edb7b" +
  "4185dd9edb7b200341c4b1d5d9074b1b200a6a36028886c08000410041e8cca7d00641e7cca7d006200941f7ed8ce2004b1b20086a36028086c08000" +
  "20004180056a248080808000418086c080000f0b200020036a22014184016a200141046a280200220b200141cc006a2802006a220c200141f0006a28" +
  "0200220f410d74200141f4006a2802002208411376722008410374200f411d767273200f411a74200841067672736a220a200141086a280200220941" +
  "1f742001410c6a2802002212410176722009411874201241087672732009411974201241077672736a220636020020014180016a200141c8006a2802" +
  "00200f4103742008411d7672200f410676732008410d74200f41137672736a20124118742009410876722009410776732012411f7420094101767273" +
  "6a20012802006a200c200b496a200a200c496a2006200a496a360200200341086a2103200241026a21020c000b0b200020016a2001418085c080006a" +
  "280200360200200141046a21010c000b0b0b8a050100418080c0000b8005982f8a4222ae28d791443771cd65ef23cffbc0b52f3b4deca5dbb5e9bcdb" +
  "89815bc2563938b548f3f111f15919d005b6a4823f929b4f19afd55e1cab18816dda98aa07d8420203a3015b8312be6f7045be8531248cb2e44ec37d" +
  "0c55e2b4ffd5745dbe726f897bf2feb1de80b196163ba706dc9b3512c72574f19bc1942669cfc1699be4d24af19e8647beefe3254f38c69dc10fb5d5" +
  "8c8bcca10c24659cac776f2ce92d75022b59aa84744a83e4a66edca9b05cd4fb41bdda88f976b553118352513e98abdf66ee6dc631a81032b42dc827" +
  "03b03f21fb98c77f59bfe40eefbef30be0c6c28fa83d4791a7d525a70a935163ca066f8203e067292914706e0e0a850ab727fc2fd24638211b2e26c9" +
  "265cfc6d2c4ded2ac45a130d3853dfb3959d54730a65de63af8bbb0a6a76a8b2773c2ec9c281e6aeed47852c72923b358214a1e8bfa26403f14c4b66" +
  "1aa8013042bc708b4bc29197f8d0a3516cc730be540619e892d11852efd6240699d610a9655585350ef42a20715770a06a10b8d1bb3216c1a419c8d0" +
  "d2b8086c371e53ab41514c77482799eb8edfb5bcb034a8489be1b30c1c39635ac9c54aaad84ecb8a41e34fca9c5b73e36377f36f2e68a3b8b2d6ee82" +
  "8f74fcb2ef5d6f63a578602f17431478c88472abf0a10802c78cec39641afaffbe90281e6323eb6c50a4e9bd82def7a3f9be1579c6b2f27871c62b53" +
  "72e3ce3e27ca9c6126eac7b886d107c2c021d67ddaea1eebe0cd7f4f7df578d16eeeaa67f006ba6f1772c57d630aa698c8a204983f11ae0df9be350b" +
  "711b1b471c13f577db28847d04237babca329324c7400abe9e3cbcbec915c4671d434c0d109cbed4c54cb6423ecb9c297f592a7e65fcab6fcb5fecfa" +
  "d63a8c19446c1758474a").match(/.{2}/g).map(x => parseInt(x, 16)))
  const {instance: { exports: { mnemonic: { value: mnemonicPtr }, seed: { value: seedPtr }, sha512_wasm, memory: {buffer} } }} =
  await WebAssembly.instantiate(SHA512_WASM)
  const buf = new Uint8Array(buffer, mnemonicPtr, 128);
  const outMemory = new Uint32Array(buffer, seedPtr, 16);
  const MNEMONIC = new TextEncoder().encode(mnemo)
  for (let i = 0; i < 128; i++) { buf[i] = 0 }
  if (MNEMONIC.length <= 128) {
    buf.set(MNEMONIC)
  } else {
    buf.set(new Uint8Array(await crypto.subtle.digest('SHA-512', MNEMONIC)))
  }
  for (let i = 0; i < 128; i+=4) {
    ([buf[i+3], buf[i+2], buf[i+1], buf[i]] = [buf[i]^XOR, buf[i+1]^XOR, buf[i+2]^XOR, buf[i+3]^XOR])
  }
  sha512_wasm()
  return outMemory.slice()
}
