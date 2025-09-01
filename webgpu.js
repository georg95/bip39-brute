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

async function testPbkdf2() {
    const inp = new Uint32Array(1024).fill(0)
    var strbuf = new Uint8Array(inp.buffer, inp.byteOffset, inp.byteLength)
    strbuf.set(new TextEncoder().encode("abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"))
    bufUint32LESwap(strbuf)

    const infer = await webGPUinit()
    const out = await infer('wgsl/pbkdf2.wgsl', inp)
    const pbkdf2 = "5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5fc19a5ac40b389cd370d086206dec8aa6c43daea6690f20ad3d8d48b2d2ce9e38e4"
    const resHash = Array.from(out.slice(0, 16)).map(x => x.toString(16).padStart(8, '0')).join('')
    console.log(resHash)
    console.log(pbkdf2)
    if (resHash === pbkdf2) {
        console.log('✅ pbkdf2 wgsl PASSED')
    } else {
        console.log('❌ pbkdf2 wgsl FAILED')
    }
}
testPbkdf2()

async function webGPUinit() {
    assert(window.isSecureContext, 'WebGPU disabled for http:// protocol, works only on https://')
    assert(navigator.gpu, 'Browser not support WebGPU')
     const adapter = await navigator.gpu.requestAdapter()
    const device = await adapter.requestDevice()
    device.lost.then(()=>{ throw Error("WebGPU logical device was lost.") })

    const BUF_SIZE = 1024 * 4

    const inpBuffer = device.createBuffer({
        size: BUF_SIZE,
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC,
    })

    const outBuffer = device.createBuffer({
        size: BUF_SIZE,
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC,
    })

    const stagingBuffer = device.createBuffer({
        size: BUF_SIZE,
        usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST,
    });

    async function inference(shaderURL, input) {
        assert(input?.length === BUF_SIZE / 4, `expected input size to be ${BUF_SIZE / 4}, got ${input?.length}`)
        device.queue.writeBuffer(inpBuffer, 0, input)
        const commandEncoder = device.createCommandEncoder()
        const passEncoder = commandEncoder.beginComputePass()
        const { bindGroup, pipeline } = await runShader(shaderURL)
        passEncoder.setBindGroup(0, bindGroup)
        passEncoder.setPipeline(pipeline)
        passEncoder.dispatchWorkgroups(1)
        passEncoder.end()
        commandEncoder.copyBufferToBuffer(outBuffer, 0, stagingBuffer, 0, BUF_SIZE)
        device.queue.submit([commandEncoder.finish()])
        await stagingBuffer.mapAsync(GPUMapMode.READ, 0, BUF_SIZE)
        const copyArrayBuffer = stagingBuffer.getMappedRange(0, BUF_SIZE)
        const data = new Uint32Array(copyArrayBuffer.slice(), 0, BUF_SIZE / 4)
        stagingBuffer.unmap()
        return data
    }

    async function runShader(shaderURL) {
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
            ],
        });
        const bindGroup = device.createBindGroup({
            layout: bindGroupLayout,
            entries: [{
                binding: 0,
                resource: { buffer: inpBuffer },
            }, {
                binding: 1,
                resource: { buffer: outBuffer },
            }],
        })
        const pipeline = device.createComputePipeline({
            layout: device.createPipelineLayout({
                bindGroupLayouts: [bindGroupLayout],
            }),
            compute: {
                module: device.createShaderModule({
                    code: await fetch(shaderURL).then(r => r.text()),
                }),
                entryPoint: "main",
            },
        });

        return {
            bindGroup,
            pipeline,
        }
    }

    return inference
}

function assert(cond, text) {
    if (!cond) {
        const err = new Error(text)
        err.stack = err.stack.split('\n').filter(x => !x.includes('at assert')).join('\n')
        throw err
    }
}
