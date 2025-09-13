async function testPipeline() {
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

    const inp = new Uint32Array(1024).fill(0)
    var strbuf = new Uint8Array(inp.buffer, inp.byteOffset, inp.byteLength)
    const MNEMONIC = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'
    const PASSWORD = ''
    strbuf.set(new TextEncoder().encode(MNEMONIC))
    strbuf.set(new TextEncoder().encode(PASSWORD), 200)
    bufUint32LESwap(strbuf)

    const { inference, buildShader, swapBuffers } = await webGPUinit({ precomputeTable })
    let shaders = []
    shaders.push(await buildShader('wgsl/pbkdf2.wgsl'))
    swapBuffers()
    shaders.push(await buildShader('wgsl/derive_coin.wgsl', 'derive1'))
    swapBuffers()
    shaders.push(await buildShader('wgsl/secp256k1.wgsl'))
    swapBuffers()
    shaders.push(await buildShader('wgsl/derive_coin.wgsl', 'derive2'))
    swapBuffers()
    shaders.push(await buildShader('wgsl/secp256k1.wgsl'))
    swapBuffers()
    shaders.push(await buildShader('wgsl/derive_coin.wgsl', 'derive2'))
    swapBuffers()
    shaders.push(await buildShader('wgsl/secp256k1.wgsl'))
    swapBuffers()
    shaders.push(await buildShader('wgsl/hash160.wgsl'))
    const out = await inference({ shaders, inp })
    const resHash160 = Array.from(out.slice(0, 5)).map(x => leSwap(x.toString(16).padStart(8, '0'))).join('')
    console.log(resHash160)
    if (resHash160 === 'd986ed01b7a22225a70edbf2ba7cfb63a15cb3aa') {
        console.log('✅ wgsl pipeline PASSED')
    } else {
        console.log('❌ wgsl pipeline FAILED')
    }
}
testPipeline()


async function webGPUinit({ precomputeTable }) {
    assert(precomputeTable, 'no precompute table passed')
    assert(window.isSecureContext, 'WebGPU disabled for http:// protocol, works only on https://')
    assert(navigator.gpu, 'Browser not support WebGPU')
    const adapter = await navigator.gpu.requestAdapter()
    const device = await adapter.requestDevice()
    var closed = false
    device.lost.then(()=>{
        if (!closed) throw Error("WebGPU logical device was lost.")
        console.log('Cleaned WebGPU device resources')
    })

    const BUF_SIZE = 1024 * 4

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

    const inpBuffer = buffers.inp

    async function inference({ shaders, inp }) {
        var start = performance.now()
        assert(inp?.length === (BUF_SIZE) / 4, `expected input size to be ${BUF_SIZE / 4}, got ${inp?.length}`)
        device.queue.writeBuffer(inpBuffer, 0, inp)
        device.queue.writeBuffer(secp256k1PrecomputeBuffer, 0, precomputeTable)

        const commandEncoder = device.createCommandEncoder()
        const passEncoder = commandEncoder.beginComputePass()

        for(let { bindGroup, pipeline } of shaders) {
            passEncoder.setBindGroup(0, bindGroup)
            passEncoder.setPipeline(pipeline)
            passEncoder.dispatchWorkgroups(1)
        }

        passEncoder.end()
        commandEncoder.copyBufferToBuffer(buffers.out, 0, stagingBuffer, 0, BUF_SIZE)
        device.queue.submit([commandEncoder.finish()])
        console.log('inference.initCompute:', performance.now() - start | 0, 'ms'); start = performance.now()
        await stagingBuffer.mapAsync(GPUMapMode.READ, 0, BUF_SIZE)
        console.log('inference.waitGpu:', performance.now() - start | 0, 'ms'); start = performance.now()
        const copyArrayBuffer = stagingBuffer.getMappedRange(0, BUF_SIZE)
        const data = new Uint32Array(copyArrayBuffer.slice(), 0, BUF_SIZE / 4)
        stagingBuffer.unmap()
        console.log('inference.copy:', performance.now() - start | 0, 'ms'); start = performance.now()
        secp256k1PrecomputeBuffer.destroy()
        buffers.inp.destroy()
        buffers.out.destroy()
        stagingBuffer.destroy()
        closed = true
        device.destroy()
        console.log('inference.clean:', performance.now() - start | 0, 'ms'); start = performance.now()
        return data
    }

    async function buildShader(shaderURL, func='main') {
        var start = performance.now()
        const code = await fetch(shaderURL).then(r => r.text())
        const bindGroupLayout = device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "read-only-storage" }
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "storage" },
                },
                {
                    binding: 2,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "read-only-storage" },
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

function assert(cond, text) {
    if (!cond) {
        const err = new Error(text)
        err.stack = err.stack.split('\n').filter(x => !x.includes('at assert')).join('\n')
        throw err
    }
}

function leSwap(str) {
    return str[6]+str[7]+str[4]+str[5]+str[2]+str[3]+str[0]+str[1]
}

function bufUint32LESwap(buf) {
    for (let i = 0; i + 3 < buf.length; i += 4) {
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

function fromHexString (hexString) { return Uint8Array.from(hexString.match(/.{1,2}/g).map((byte) => parseInt(byte, 16))) }
function BigToU32_reverse(n) {
    const hex = n.toString(16).padStart(64, '0')
    return hex.match(/.{1,8}/g).map(x => parseInt(x, 16)).reverse()
}
