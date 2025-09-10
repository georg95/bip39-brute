import { precompute } from './worker.js';

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
// testPbkdf2()

function BigToU32(n) {
    const hex = n.toString(16).padStart(64, '0')
    return hex.match(/.{1,8}/g).map(x => parseInt(x, 16)).reverse()
}
async function testSecp256k1() {
    const PRECOMPUTE_WINDOW = 8
    const PRECOMPUTE_SIZE = 2 ** (PRECOMPUTE_WINDOW - 1) * (Math.ceil(256 / PRECOMPUTE_WINDOW)) * 64
    const inp = new Uint32Array(PRECOMPUTE_SIZE / 4).fill(0)
    precompute(PRECOMPUTE_WINDOW, (batch, i) => {
        batch.forEach(({X, Y}, j) => {
            const index = i * batch.length + j
            const xx = BigToU32(X)
            for (var x = 0; x < 8; x++) { inp[index*16 + x] = xx[x] }
            const yy = BigToU32(Y)
            for (var y = 0; y < 8; y++) { inp[index*16 + 8 + y] = yy[y] }
        })
    })
    const infer = await webGPUinit(PRECOMPUTE_SIZE)
    const out = await infer('wgsl/secp256k1.wgsl', inp)
    const exp = [
        // x
     83643075, 76069071,
     55469393, 21767991,
     10937513, 34532574,
     44697786, 43417801,
    111230169,  1911620,
        // y
    470864147, 421433767,
    456796015, 435566382,
    474743752, 492879811,
    471075114, 479116549,
    458988899,  25782099,
        // z
    22585090,  2251927,
     2778108, 25262302,
    37498620,  5439290,
    15831125, 21874988,
    33853260,  2110620,
  ].join(',')
    const res = Array.from(out.slice(0, 30)).join(',')
    console.log(exp)
    console.log(res)
    if (exp === res) {
        console.log('✅ secp256k1 wgsl PASSED')
    } else {
        console.log('❌ secp256k1 wgsl FAILED')
    }
}
testSecp256k1()

async function webGPUinit(INP_SIZE) {
    assert(window.isSecureContext, 'WebGPU disabled for http:// protocol, works only on https://')
    assert(navigator.gpu, 'Browser not support WebGPU')
    const adapter = await navigator.gpu.requestAdapter()
    const device = await adapter.requestDevice()
    device.lost.then(()=>{ throw Error("WebGPU logical device was lost.") })

    const BUF_SIZE = 1024 * 4

    const inpBuffer = device.createBuffer({
        size: INP_SIZE || BUF_SIZE,
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
        assert(input?.length === (INP_SIZE || BUF_SIZE) / 4, `expected input size to be ${BUF_SIZE / 4}, got ${input?.length}`)
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
