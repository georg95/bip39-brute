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

async function buildEntirePipeline({ buildShader, swapBuffers }) {
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
    return shaders
}

document.addEventListener('DOMContentLoaded', () => {
    function log(text, clear=false) {
        if (clear) window.output.innerHTML = ''
        window.output.innerHTML += text + '\n'
    }
    async function runBenchmark(options) {
        const { name, clean, inference, buildShader, swapBuffers } = await webGPUinit(options)
        log(`\n[${name}]\n`)
        window.output.innerHTML += 'Initialize data... '
        const start = performance.now()
        const pipeline = await buildEntirePipeline({ buildShader, swapBuffers })
        const passwords = 1024 * 8
        const PASSWORD = 'password'
        const digits = passwords.toString(10).length
        const PASS_LEN = Math.ceil((PASSWORD.length + digits + 1) / 4) + 1
        const inp = new Uint32Array(32 + PASS_LEN * passwords).fill(0)
        var strbuf = new Uint8Array(inp.buffer, inp.byteOffset, inp.byteLength)
        const MNEMONIC = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'
        strbuf.set(new TextEncoder().encode(MNEMONIC))

        let passwordOffset = 128 + passwords * 4
        for (let i = 0; i < passwords; i++) {
            const curPass = PASSWORD + i.toString(10)
            strbuf.set(new TextEncoder().encode(curPass), passwordOffset)
            inp[32 + i] = passwordOffset
            passwordOffset += curPass.length + 1
        }
        bufUint32LESwap(strbuf, 0, 128)
        bufUint32LESwap(strbuf, 128 + passwords * 4, strbuf.length)
        
        log(`[${((performance.now() - start) / 1000).toFixed(1)}s]\n`)
        for (let mode of ['pbkdf2', 'all']) {
            if (mode === 'pbkdf2') {
                log('Pbkdf2-hmac-sha512:')
                shaders = [pipeline[0]]
            }
            if (mode === 'all') {
                log('\nMnemonic to address:')
                shaders = pipeline
            }
            for (let i = 0; i < 8; i++) {
                const batchSize = 64 * (2 ** i)
                const start = performance.now()
                let out
                for (let x = 0; x < 5; x++) {
                    out = await inference({ shaders, inp, count: batchSize })
                }
                const time = (performance.now() - start) / 1000
                const resHash160 = Array.from(out.slice(35 * 5, 35 * 5 + 5)).map(x => leSwap(x.toString(16).padStart(8, '0'))).join('')
                const addrToHex = 'f679bc9f7c11c33741b410f7a1801840f7bdf754'
                if (mode === 'all' && resHash160 !== addrToHex) {
                    log('❌ wgsl pipeline FAILED')
                    log(resHash160)
                    log(addrToHex)
                    break
                }

                log(`Batch: ${batchSize}, Speed: ${(batchSize * 5 / time) | 0} ops/s`);

                if (time > 3) {
                    break
                }
            }
        }
        clean()
    }
    window.benchmark.onclick = async () => {
        assert(window.isSecureContext, 'WebGPU disabled for http:// protocol, works only on https://')
        assert(navigator.gpu, 'Browser not support WebGPU')
        window.benchmark.style.display = 'none'
        window.output.innerHTML += 'Precompute secp256k1 table... '
        const start = performance.now()
        const precomputeTable = await prepareCompute()
        log(`[${((performance.now() - start) / 1000).toFixed(1)}s]`)
        const adapter1 = await navigator.gpu.requestAdapter({ powerPreference: "high-performance" })
        const device1 = await adapter1.requestDevice()
        await runBenchmark({ precomputeTable, device: device1, adapter: adapter1 })

        const adapter2 = await navigator.gpu.requestAdapter({ powerPreference: "low-power" })
        const device2 = await adapter2.requestDevice()
        if (adapter1.info.device !== adapter2.info.device || adapter1.info.description !== adapter2.info.description) {
            window.output.innerHTML += '\n'
            await runBenchmark({ precomputeTable, device: device2, adapter: adapter2 })
        }
        log('\n✅ DONE')
        window.benchmark.style.display = ''
    }
})

async function webGPUinit({ adapter, device, precomputeTable }) {
    assert(precomputeTable, 'no precompute table passed')
    var closed = false
    device.lost.then(()=>{
        assert(closed, 'WebGPU logical device was lost.')
        console.log('Cleaned WebGPU device resources')
    })

    const BUF_SIZE = 128 * 1024 * 32

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

    async function inference({ shaders, inp, count }) {
        assert(inp?.length <= BUF_SIZE / 4, `expected input size to be <= ${BUF_SIZE / 4}, got ${inp?.length}`)
        device.queue.writeBuffer(inpBuffer, 0, inp)
        const commandEncoder = device.createCommandEncoder()
        const passEncoder = commandEncoder.beginComputePass()

        for(let { bindGroup, pipeline } of shaders) {
            passEncoder.setBindGroup(0, bindGroup)
            passEncoder.setPipeline(pipeline)
            passEncoder.dispatchWorkgroups(Math.ceil(count / 32))
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

    async function buildShader(shaderURL, func='main') {
        var start = performance.now()
        const code = await fetch(shaderURL).then(r => r.text())
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
