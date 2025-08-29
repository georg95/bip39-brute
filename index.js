const biplist = fetch('bip39.txt').then(r => r.text()).then(t => t.split('\n').map(x => x.trim()).filter(x => x))

let THREADS = 1
let DERIVE_ADDRESSES = 5
document.addEventListener('DOMContentLoaded', () => {
  window.brute.onclick = startBrute
  window['show-settings'].onclick = () => {
    window['brute-pane'].style.display = 'none'
    window['settings-pane'].style.display = 'block'
  }
  window['hide-settings'].onclick = () => {
    window['brute-pane'].style.display = 'block'
    window['settings-pane'].style.display = 'none'
  }
  window.threads.max = navigator.hardwareConcurrency || 4
  window.threads.onchange = () => {
    THREADS = Number(window.threads.value)
    window.threadsView.innerText = THREADS
  }
  window.threads.value = navigator.hardwareConcurrency || 4
  THREADS = navigator.hardwareConcurrency || 4
  window.threadsView.innerText = THREADS
  window.derive.onchange = () => {
    DERIVE_ADDRESSES = Number(window.derive.value)
    window.deriveView.innerText = Math.max(DERIVE_ADDRESSES, 1)
  }
  window.derive.value = DERIVE_ADDRESSES
  window.deriveView.innerText = DERIVE_ADDRESSES

  async function checkInput() {
    window.brute.style.visibility = await validateInput() ? 'visible' : 'hidden'
  }
  window.bipmask.onchange = checkInput
  window.bipmask.oninput = checkInput
  window.addrlist.onchange = checkInput
  window.addrlist.oninput = checkInput
  checkInput()
})

async function startBrute() {
  const start = performance.now()
  const { bip39mask, addrHash160list, addrTypes } = await validateInput()
  const allWords = await biplist
  const VALID_SEEDS = { '12': 16, '15': 32, '18': 64, '24': 256 }[bip39mask.split(' ').length];
  let i = 0
  const { permCount, next } = permutations(bip39mask, allWords)
  const EFFECIVE_THREADS = Math.min(permCount, THREADS)
  const { waitFree, waitAll, workers } = threadPool(EFFECIVE_THREADS)
  for (; i < permCount; i++) {
    const { res, postMessage, isNew } = await waitFree()
    const message = { mnemonicPartial: next(), addrHash160list, addrTypes }
    if (isNew) {
      message.allWords = allWords
      message.deriveCount = DERIVE_ADDRESSES
    }
    postMessage(message)
    if (i >= EFFECIVE_THREADS) {
      const time = (performance.now() - start) / 1000
      const ops = 2048 * (i - EFFECIVE_THREADS) / VALID_SEEDS
      window.output.innerHTML = `${(100 * (i - EFFECIVE_THREADS) / permCount).toFixed(1)}%, ${ops / time | 0} mnemonic/s\n`
    } else {
      window.output.innerHTML = `Starting...\n`
    }
    if (res.data) {
      window.output.innerHTML = `FOUND! ${res.data}\n`;
      break
    }
  }
  if (i === permCount) {
    window.output.innerHTML = `Finishing...\n`
    const arr = await waitAll()
    arr.forEach(r => {
      if (r[0].data) {
        window.output.innerHTML = `FOUND! ${r[0].data}\n`;
      }
    })
  }
  const time = (performance.now() - start) / 1000
  const totalOps = 2048 * i / VALID_SEEDS
  window.output.innerHTML += `\nChecked all in ${time | 0} seconds (${totalOps / time | 0} mnemonic/s)\n`;
  workers.forEach(w => w.terminate())
}

function permutations(input, bip39words) {
  const tokens = input.split(" ");
  var starCount = tokens.filter(t => t === "*").length;
  const choices = tokens.map(token => {
    if (token === "*") {
      starCount--;
      return starCount === 0 ? ["*"] : bip39words
    }
    return token.split(",")
  })
  const indices = new Array(choices.length).fill(0)
  let done = false
  return {
    permCount: choices.reduce((acc, cur) => acc * cur.length, 1),
    next() {
      if (done) return null
      const result = choices.map((opts, i) => opts[indices[i]]).join(" ")
      for (let i = choices.length - 1; i >= 0; i--) {
        indices[i]++
        if (indices[i] < choices[i].length) break
        indices[i] = 0
        if (i === 0) done = true
      }
      return result
    }
  }
}

function threadPool(THREADS) {
  console.log(`spawning ${THREADS} threads`);
  const workers = Array(THREADS).fill(0).map((x, i) => new Worker(`worker.js?i=${i}`))
  const pool = Array(THREADS).fill(0).map((x, i) => ([Promise.resolve(), i, true]))
  async function waitFree() {
    const [res, index, isNew] = await Promise.any(pool);
    pool[index] = new Promise(() => {})
    function postMessage(params) {
      pool[index] = new Promise(async (resolve) => {
        workers[index].postMessage(params)
        resolve([await new Promise(res => { workers[index].onmessage = res }), index])
      })
      return [index]
    }

    return { res, isNew, postMessage }
  }
  async function waitAll() {
    return Promise.all(pool)
  }
  return { waitFree, waitAll, workers }
}

async function validateInput() {
  window.output.innerHTML = ''
  const allWords = await biplist
  const bip39mask = window.bipmask.value
  let result = true
  const words = bip39mask.trim().split(/[\s \t]+/)
  if (![12, 15, 18, 24].includes(words.length)) {
      window.output.innerHTML += `Expected 12/15/18/24 words, got ${words.length}\n`
      result = false
  }
  let asterisks = 0
  for (let word of words) {
    if (word === '*') { asterisks++; continue }
    for (let wordPart of word.split(',')) {
      if (!allWords.includes(wordPart)) {
        window.output.innerHTML += `${wordPart} is invalid bip39 word\n`
        result = false
      }
    }

  }
  if (asterisks == 0) {
    window.output.innerHTML += `Enter at least 1 asterisk\n`
    result = false
  }
  if (asterisks > 2) {
    window.output.innerHTML += `Can't brute with ${asterisks} * - too long to brute\n`
    result = false
  }
  const addrlist = window.addrlist.value.split('\n').map(x => x.trim()).filter(x => x)
  if (addrlist.length === 0) {
    window.output.innerHTML = `Enter at least 1 address`;
    result = false
  }
  const addrHash160list = []
  const addrTypes = new Set()
  for (let addr of addrlist) {
    const { hash160, type } = await addrToScriptHash(addr) || {}
    if (hash160) {
      addrTypes.add(type)
      addrHash160list.push(hash160)
    } else {
      window.output.innerHTML += `${addr} is invalid address\n`
      result = false
    }
  }
  return result && { bip39mask: words.join(' '), addrHash160list, addrTypes }
}

async function addrToScriptHash(address) {
    const sha256HashSync = async (data) => {
      return new Uint8Array(await crypto.subtle.digest('SHA-256', new Uint8Array(data)))
    }
    if (address.match(/^0x[0-9a-fA-F]{40}$/)) {
      return { hash160: hexToUint8Array(address.slice(2)), type: 'eth' }
    }
    if (address.startsWith('bc1')) {
      const hash160 = decodeBech32(address)
      return hash160 && { hash160, type: 'p2wphk' }
    }
    let decodedData = base58Decode(address)
    if (!decodedData) return null
    const doubleSha256 = await sha256HashSync(await sha256HashSync(decodedData.slice(0, -4)))
    const checksumValid = Array.from(doubleSha256.slice(0, 4)).every((byte, i) => byte === decodedData.slice(-4)[i])
    if (!checksumValid) return null
    const type = { '0': 'p2pkh', '5': 'p2sh', '65': 'tron' }[decodedData[0]]
    if (!type) return null
    return { hash160: decodedData.slice(1, 21), type }
}

function hexToUint8Array(hexString) {
    const bytes = [];
    for (let i = 0; i < hexString.length; i += 2) {
        bytes.push(parseInt(hexString.substr(i, 2), 16));
    }
    return new Uint8Array(bytes);
}

function base58Decode(str) {
  const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  const bytes = [0];
  for (let i = 0; i < str.length; i++) {
    const char = str[i];
    const value = alphabet.indexOf(char);
    if (value === -1) return null;
    let carry = value;
    for (let j = 0; j < bytes.length; j++) {
      carry += bytes[j] * 58;
      bytes[j] = carry & 0xff;
      carry >>= 8;
    }
    while (carry > 0) {
      bytes.push(carry & 0xff);
      carry >>= 8;
    }
  }
  let zeros = 0;
  while (str[zeros] === '1') zeros++;
  const result = new Uint8Array(zeros + bytes.length);
  for (let i = 0; i < bytes.length; i++) {
    result[result.length - 1 - i] = bytes[i];
  }
  return result;
}

function decodeBech32(address) {
  if (typeof address !== 'string') return null
  const lower = address.toLowerCase()
  if (lower !== address && address.toUpperCase() !== address) return null
  address = lower
  const SEP = address.lastIndexOf('1')
  if (SEP < 1 || SEP + 7 > address.length) return null
  const hrp = address.slice(0, SEP)
  const dataPart = address.slice(SEP + 1)
  if (!(hrp === 'bc' || hrp === 'tb' || hrp === 'bcrt')) return null
  const CHARSET = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l'
  const CHARMAP = (() => {
    const map = new Int16Array(128).fill(-1)
    for (let i = 0; i < CHARSET.length; i++) map[CHARSET.charCodeAt(i)] = i
    return map
  })();
  const data = new Uint8Array(dataPart.length)
  for (let i = 0; i < dataPart.length; i++) {
    const v = dataPart.charCodeAt(i) < 128 ? CHARMAP[dataPart.charCodeAt(i)] : -1
    if (v === -1) return null
    data[i] = v
  }
  function hrpExpand(h) {
    const ret = []
    for (let i = 0; i < h.length; i++) ret.push(h.charCodeAt(i) >> 5)
    ret.push(0)
    for (let i = 0; i < h.length; i++) ret.push(h.charCodeAt(i) & 31)
    return ret
  }
  function polymod(values) {
    const GEN = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]
    let chk = 1
    for (let p = 0; p < values.length; p++) {
      const top = chk >>> 25
      chk = ((chk & 0x1ffffff) << 5) ^ values[p]
      for (let i = 0; i < 5; i++) {
        if ((top >>> i) & 1) chk ^= GEN[i]
      }
    }
    return chk >>> 0;
  }
  const BECH32_CONST  = 1 >>> 0
  const BECH32M_CONST = 0x2bc830a3 >>> 0
  const values = new Uint8Array(hrpExpand(hrp).concat(Array.from(data)))
  const pm = polymod(values)
  const encConst = pm === BECH32_CONST ? 'bech32' :
                   pm === BECH32M_CONST ? 'bech32m' : null
  if (!encConst) return null
  const payload = data.slice(0, data.length - 6)
  if (payload.length === 0) return null
  const version = payload[0]
  if (version > 16) return null
  if ((version === 0 && encConst !== 'bech32') ||
      (version !== 0 && encConst !== 'bech32m')) {
    return null
  }

  function convertBits(data5, from, to, pad) {
    let acc = 0, bits = 0, out = []
    const maxv = (1 << to) - 1
    for (let i = 0; i < data5.length; i++) {
      const value = data5[i]
      if (value < 0 || value >> from) return null
      acc = (acc << from) | value
      bits += from
      while (bits >= to) {
        bits -= to
        out.push((acc >> bits) & maxv)
      }
    }
    if (pad) {
      if (bits) out.push((acc << (to - bits)) & maxv);
    } else if (bits >= from || ((acc << (to - bits)) & maxv)) {
      return null
    }
    return new Uint8Array(out)
  }

  const program5 = payload.slice(1)
  const program = convertBits(program5, 5, 8, false)
  if (!program) return null
  if (program.length < 2 || program.length > 40) return null
  if (version === 0 && !(program.length === 20 || program.length === 32)) return null
  if (program.length !== 20) return null
  return program
}
