/*
  1. pbkdf2
  2. derive1
  3. secp256k1
  4. derive2
  5. secp256k1

  TODO: 6. derive3
  TODO: 7. secp256k1.2
  8. sha256
  TODO: 9. ripemd160
*/ 

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

async function mnemonicToSeed(mnemonic, password="") {
    const encoder = new TextEncoder()
    const saltBuffer = encoder.encode("mnemonic"+password)
    const mnemonicBuffer = encoder.encode(mnemonic)
    const keyMaterial = await crypto.subtle.importKey(
        "raw", mnemonicBuffer, { name: "PBKDF2" }, false, ["deriveBits"]);
    const derivedBits = await crypto.subtle.deriveBits({
        name: "PBKDF2", salt: saltBuffer, iterations: 2048, hash: "SHA-512" }, keyMaterial, 512);
    return new Uint8Array(derivedBits);
}
function toHex(u8) { return Array.from(u8).map(b => b.toString(16).padStart(2, '0')).join(''); }

async function testPbkdf2() {
    const inp = new Uint32Array(1024).fill(0)
    var strbuf = new Uint8Array(inp.buffer, inp.byteOffset, inp.byteLength)
    const MNEMONIC = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'
    const PASSWORD = 'passwordTest'
    strbuf.set(new TextEncoder().encode(MNEMONIC))
    strbuf.set(new TextEncoder().encode(PASSWORD), 200)
    bufUint32LESwap(strbuf)

    const infer = await webGPUinit({})
    const out = await infer({ shader: 'wgsl/pbkdf2.wgsl', inp })
    const pbkdf2 = toHex(await mnemonicToSeed(MNEMONIC, PASSWORD))
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

function prepareSha256Block(input) {
  assert(input.length <= 61, `sha256 input ${toHex(input)} is loner than 61 bytes`)
  const blockBytes = new Uint8Array(64);
  blockBytes.set(input, 0);
  blockBytes[input.length] = 0x80;
  blockBytes[62] = (input.length * 8) >> 8;
  blockBytes[63] = (input.length * 8) & 0xff;
  const words = new Uint32Array(16);
  for (let i = 0; i < 16; i++) {
    const j = i * 4;
    words[i] =
      (blockBytes[j] << 24) |
      (blockBytes[j + 1] << 16) |
      (blockBytes[j + 2] << 8) |
      (blockBytes[j + 3]);
    words[i] >>>= 0;
  }
  return words;
}

async function testSha256() {
    const inp = new Uint32Array(1024).fill(0)
    const PASSWORD = new TextEncoder().encode('')
    inp.set(prepareSha256Block(PASSWORD))

    const infer = await webGPUinit({})
    const out = await infer({ shader: 'wgsl/sha256.wgsl', func: 'sha256', inp })
    const sha256 = toHex(new Uint8Array(await crypto.subtle.digest('SHA-256', PASSWORD)))
    const resSha256 = Array.from(out.slice(0, 8)).map(x => x.toString(16).padStart(8, '0')).join('')
    console.log(resSha256)
    console.log(sha256)
    if (resSha256 === sha256) {
        console.log('✅ sha256 wgsl PASSED')
    } else {
        console.log('❌ sha256 wgsl FAILED')
    }
}
testSha256()

async function testDerive1() {
    const inp = new Uint32Array(1024).fill(0)
    var strbuf = new Uint8Array(inp.buffer, inp.byteOffset, inp.byteLength)
    const KEY = new TextEncoder().encode('Bitcoin seed')
    const seed = await mnemonicToSeed('abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about', '')
    console.log('seed:', toHex(seed))
    strbuf.set(KEY)
    strbuf.set(seed, 64)
    bufUint32LESwap(strbuf)

    const infer = await webGPUinit({})
    const out = await infer({ shader: 'wgsl/derive_coin.wgsl', func: 'derive1', inp })
    const privKeyExp = 'fe64af825b5b78554c33a28b23085fc082f691b3c712cc1d4e66e133297da87a'
    const chainCodeExp = '3da4bc190a2680111d31fadfdc905f2a7f6ce77c6f109919116f253d43445219'
    const privKey = Array.from(out.slice(0, 8)).map(x => x.toString(16).padStart(8, '0')).join('')
    const chainCode = Array.from(out.slice(8, 16)).map(x => x.toString(16).padStart(8, '0')).join('')
    console.log('Priv key(exp):', '0x'+privKeyExp+'n');
    console.log('Priv key(got):', '0x'+privKey+'n');
    console.log('Chain (exp):', '0x'+chainCodeExp+'n');
    console.log('Chain (got):', '0x'+chainCode+'n');
    if (privKey === privKeyExp) {
        console.log('✅ testDerive1 privKey PASSED')
    } else {
        console.log('❌ testDerive1 privKey FAILED')
    }
    if (chainCode === chainCodeExp) {
        console.log('✅ testDerive1 chainCode PASSED')
    } else {
        console.log('❌ testDerive1 chainCode FAILED')
    }
}
// testDerive1()

async function testDerive2() {
    const inp = new Uint32Array(1024).fill(0)
    var strbuf = new Uint8Array(inp.buffer, inp.byteOffset, inp.byteLength)
    const data = fromHexString('fe64af825b5b78554c33a28b23085fc082f691b3c712cc1d4e66e133297da87a3da4bc190a2680111d31fadfdc905f2a7f6ce77c6f109919116f253d43445219774c910fcf07fa96886ea794f0d5caed9afe30b44b83f7e213bb92930e7df4bdde7cb503e9309ba5adeadebe758bfdbade58ffe4d362964bd4c982a4245973d9')
    strbuf.set(data, 0)
    bufUint32LESwap(strbuf)

    const privKeyS = 0x774c910fcf07fa96886ea794f0d5caed9afe30b44b83f7e213bb92930e7df4bdn
    const chainCodeS = 0x3da4bc190a2680111d31fadfdc905f2a7f6ce77c6f109919116f253d43445219n
    // inp.set(BigToU32(privKeyS), 0)
    // inp.set(BigToU32(chainCodeS), 8)
    console.log('pk_in:', Array.from(inp.slice(16, 24)).map(x => x.toString(16).padStart(8, '0')).join(''))
    console.log('pkBig:', privKeyS.toString(16))
    console.log('ch_in:', Array.from(inp.slice(8, 16)).map(x => x.toString(16).padStart(8, '0')).join(''))
    console.log('chBig:', chainCodeS.toString(16))

    const infer = await webGPUinit({})
    const out = await infer({ shader: 'wgsl/derive_coin.wgsl', func: 'derive2', inp })
    const privKeyExp = '83bda5c7add17ef9bbc1f03391913fe6cc947aa18c4a343607724e815c83eeb7'
    const chainCodeExp = 'bce80dd580792cd18af542790e56aa813178dc28644bb5f03dbd44c85f2d2e7a'
    const privKey = Array.from(out.slice(0, 8)).map(x => x.toString(16).padStart(8, '0')).join('')
    const chainCode = Array.from(out.slice(8, 16)).map(x => x.toString(16).padStart(8, '0')).join('')
    console.log('Priv key(exp):', '0x'+privKeyExp+'n');
    console.log('Priv key(got):', '0x'+privKey+'n');
    console.log('Chain (exp):', '0x'+chainCodeExp+'n');
    console.log('Chain (got):', '0x'+chainCode+'n');
    if (privKey === privKeyExp) {
        console.log('✅ testDerive2 privKey PASSED')
    } else {
        console.log('❌ testDerive2 privKey FAILED')
    }
    if (chainCode === chainCodeExp) {
        console.log('✅ testDerive2 chainCode PASSED')
    } else {
        console.log('❌ testDerive2 chainCode FAILED')
    }
}
// testDerive2()

function fromHexString (hexString) { return Uint8Array.from(hexString.match(/.{1,2}/g).map((byte) => parseInt(byte, 16))) }
function BigToU32_reverse(n) {
    const hex = n.toString(16).padStart(64, '0')
    return hex.match(/.{1,8}/g).map(x => parseInt(x, 16)).reverse()
}
function BigToU32(n) {
    const hex = n.toString(16).padStart(64, '0')
    return hex.match(/.{1,8}/g).map(x => parseInt(x, 16))
}
async function testSecp256k1() {
    const PRECOMPUTE_WINDOW = 8
    const PRECOMPUTE_SIZE = 2 ** (PRECOMPUTE_WINDOW - 1) * (Math.ceil(256 / PRECOMPUTE_WINDOW)) * 64
    const precomputeTable = new Uint32Array(PRECOMPUTE_SIZE / 4).fill(0)
    var start = performance.now()
    precompute(PRECOMPUTE_WINDOW, (batch, i) => {
        batch.forEach(({X, Y}, j) => {
            const index = i * batch.length + j
            const xx = BigToU32_reverse(X)
            for (var x = 0; x < 8; x++) { precomputeTable[index*16 + x] = xx[x] }
            const yy = BigToU32_reverse(Y)
            for (var y = 0; y < 8; y++) { precomputeTable[index*16 + 8 + y] = yy[y] }
        })
    })
    console.log('Precomputed table in', performance.now() - start | 0, 'ms')
    start = performance.now()
    const inp = new Uint32Array(1024).fill(0)
    const privKey = 0xfe64af825b5b78554c33a28b23085fc082f691b3c712cc1d4e66e133297da87an
    const chainCode = 0x3da4bc190a2680111d31fadfdc905f2a7f6ce77c6f109919116f253d43445219n
    inp.set(BigToU32_reverse(privKey))
    inp.set(BigToU32_reverse(chainCode), 8)

    const infer = await webGPUinit({ PRECOMPUTE_SIZE })
    console.log('Init in', performance.now() - start | 0, 'ms')
    start = performance.now()
    const out = await infer({ shader: 'wgsl/secp256k1.wgsl', inp, precomputeTable })
    console.log('Inference in', performance.now() - start | 0, 'ms')
    const exp = toHex(getPublicKey(privKey))
    const prefix = out[31] % 2 === 0 ? '02' : '03'
    const res = prefix + Array.from(out.slice(16, 24)).map(x => x.toString(16).padStart(8, '0')).join('')
    const copiedChainCode = Array.from(out.slice(8, 16)).map(x => x.toString(16).padStart(8, '0')).join('')
    console.log('prefix:', prefix);
    console.log(exp)
    console.log(res)
    console.log('full data:', Array.from(out.slice(0, 32)).map(x => x.toString(16).padStart(8, '0')).join(''))
    if (exp === res) {
        console.log('✅ secp256k1 wgsl PASSED')
    } else {
        console.log('❌ secp256k1 wgsl FAILED')
    }

    if (copiedChainCode === chainCode.toString(16)) {
        console.log('✅ secp256k1 chain code copy PASSED')
    } else {
        console.log('❌ secp256k1 chain code copy FAILED')
        console.log(chainCode.toString(16))
        console.log(copiedChainCode)
    }
}
// testSecp256k1()

async function webGPUinit({ PRECOMPUTE_SIZE, INP_SIZE }) {
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
        size: PRECOMPUTE_SIZE || BUF_SIZE,
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC,
    })

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

    async function inference({ shader, func, inp, precomputeTable }) {
        assert(inp?.length === (INP_SIZE || BUF_SIZE) / 4, `expected input size to be ${BUF_SIZE / 4}, got ${inp?.length}`)
        device.queue.writeBuffer(inpBuffer, 0, inp)
        if (precomputeTable) {
            device.queue.writeBuffer(secp256k1PrecomputeBuffer, 0, precomputeTable)
        }
        const commandEncoder = device.createCommandEncoder()
        const passEncoder = commandEncoder.beginComputePass()
        const { bindGroup, pipeline } = await runShader(shader, func)
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


        secp256k1PrecomputeBuffer.destroy()
        inpBuffer.destroy()
        outBuffer.destroy()
        stagingBuffer.destroy()
        closed = true
        device.destroy()
        return data
    }

    async function runShader(shaderURL, func='main') {
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
        const bindGroup = device.createBindGroup({
            layout: bindGroupLayout,
            entries: [{
                binding: 0,
                resource: { buffer: inpBuffer },
            }, {
                binding: 1,
                resource: { buffer: outBuffer },
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
                    code: await fetch(shaderURL).then(r => r.text()),
                }),
                entryPoint: func,
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
