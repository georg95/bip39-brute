async function test() {
    const infer = await webGPUinit()
    const inp = new Uint32Array(1024).fill(1)
    const out = await infer(inp)
    const sha512_EMPTY = "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"
    const resHash = Array.from(out.slice(0, 16)).map(x => x.toString(16).padStart(8, '0')).join('')
    console.log(resHash)
    console.log(sha512_EMPTY)
    if (resHash === sha512_EMPTY) {
        console.log('✅ sha512 wgsl PASSED')
    } else {
        console.log('❌ sha512 wgsl FAILED')
    }
}
test()

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

    async function inference(input) {
        assert(input?.length === BUF_SIZE / 4, `expected input size to be ${BUF_SIZE / 4}, got ${input?.length}`)
        device.queue.writeBuffer(inpBuffer, 0, input)
        const commandEncoder = device.createCommandEncoder()
        const passEncoder = commandEncoder.beginComputePass()
        const { bindGroup, pipeline } = await runShader()
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

    async function runShader() {
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
                    code: await fetch('wgsl/sha512.wgsl').then(r => r.text()),
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
