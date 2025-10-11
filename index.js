let DERIVE_ADDRESSES = 1
let PASSWORD_SOURCE = 'default'
let PASSWORD_FILES = []
let MNEMONIC_PASSWORD = ''
document.addEventListener('DOMContentLoaded', () => {
  let pausedBruteforce = false
  window.resume_btn.onclick = () => {
    let savedProgress = localStorage.getItem('progress')
    if (savedProgress) {
      savedProgress = JSON.parse(savedProgress)
    }
    startBruteforce(savedProgress)
  }
  window.start_btn.onclick = () => startBruteforce()
  window.stop_btn.onclick = () => { stopCurrentBruteforce(); validateInput(true) }
  function stopCurrentBruteforce() {
    window.pause_btn.style.display = 'none'
    window.stop_btn.style.display = 'none'
    window.resume_btn.style.display = 'none'
    window.start_btn.style.display = 'block'
    localStorage.setItem('progress', '')
    window['show-settings'].style.display = ''
    window.passwords_source.disabled = false
    window.derive.disabled = false
    window.mnemonic_password.disabled = false
    window.bipmask.disabled = false
    window.addrlist.disabled = false
    pausedBruteforce = false
  }
  function showPausedBruteforce() {
    window.pause_btn.style.display = 'none'
    window.start_btn.style.display = 'none'
    window.stop_btn.style.display = 'block'
    window.resume_btn.style.display = 'block'
    window['show-settings'].style.display = 'none'
    window.passwords_source.disabled = true
    window.derive.disabled = true
    window.mnemonic_password.disabled = true
    window.bipmask.disabled = true
    window.addrlist.disabled = true
    pausedBruteforce = true
  }
  async function startBruteforce(SAVED_PROGRESS) {
    const { permCount, bip39mask, addrHash160list, addrTypes } = await validateInput(false)
    if (permCount === 1 && SAVED_PROGRESS && PASSWORD_SOURCE === 'file') {
      if (localStorage.getItem('password_files') !== PASSWORD_FILES.map(f => f.name).join(',')) {
        log(`Select these files to resume: ${localStorage.getItem('password_files')}`)
        return
      }
    }

    window.start_btn.style.display = 'none'
    window.resume_btn.style.display = 'none'
    window.stop_btn.style.display = 'none'
    window.pause_btn.style.display = 'block'
    window['show-settings'].style.display = 'none'
    window.passwords_source.disabled = true
    window.derive.disabled = true
    window.mnemonic_password.disabled = true
    window.bipmask.disabled = true
    window.addrlist.disabled = true
    pausedBruteforce = true
    let paused = false
    if (permCount > 1) {
      if (SAVED_PROGRESS) {
        SAVED_PROGRESS = SAVED_PROGRESS.seeds
      }
      paused = await bruteSeedGPU({ SAVED_PROGRESS, bip39mask, hashList: addrHash160list, addrType: addrTypes[0] })
    } else {
      paused = await brutePasswordGPU({ SAVED_PROGRESS, bip39mask, hashList: addrHash160list, addrType: addrTypes[0] })
    }
    if (paused) { showPausedBruteforce() }
    else { stopCurrentBruteforce() }
  }
  window.passwords_source.onchange = (e) => {
    PASSWORD_SOURCE = e.target.options[e.target.selectedIndex].getAttribute('name')
    window.passwords_files_view.style.display = PASSWORD_SOURCE === 'file' ? 'block' : 'none'
    localStorage.setItem('password_source', PASSWORD_SOURCE)
  }
  window.passwords_files.onchange = (e) => {
    if (e.target.files.length === 0) {
      return
    }
    PASSWORD_FILES = Array.from(e.target.files)
    localStorage.setItem('password_files', PASSWORD_FILES.map(f => f.name).join(','))
    function formatSize({ size }) {
      if (size > 1024 * 1024 * 1024) { return `${(size/1024/1024/1024).toFixed(1)} Gb` }
      if (size > 1024 * 1024) { return `${(size/1024/1024).toFixed(1)} Mb` }
      return `${(size/1024).toFixed(1)} kb`
    }
    const maxLen = Math.max.apply(Math, PASSWORD_FILES.map(f => f.name.length))
    window.passwords_files_view.innerText = PASSWORD_FILES.map(f => `${f.name.padEnd(maxLen, ' ')} ${formatSize(f)}`).join('\n')
  }
  window['show-settings'].onclick = () => {
    setCurerntBruteforceLink()
    window['brute-pane'].style.display = 'none'
    window['settings-pane'].style.display = 'block'
  }
  window['hide-settings'].onclick = () => {
    window['brute-pane'].style.display = 'block'
    window['settings-pane'].style.display = 'none'
    console.log('validateInput')
    validateInput(true)
  }
  window.derive.oninput = () => {
    DERIVE_ADDRESSES = 2 ** Number(window.derive.value)
    window.deriveView.innerText = DERIVE_ADDRESSES
    localStorage.setItem('derive_addresses', DERIVE_ADDRESSES)
    setCurerntBruteforceLink()
  }
  window.mnemonic_password.onchange = window.mnemonic_password.oninput = (e) => {
    MNEMONIC_PASSWORD = e.target.value
    localStorage.setItem('mnemonic_password', MNEMONIC_PASSWORD)
    setCurerntBruteforceLink()
  }

  async function checkInput() {
    const res = await validateInput(!pausedBruteforce)
    window.start_btn.style.display = (res && !pausedBruteforce) ? 'block' : 'none'
    if (res && res.permCount === 1) {
      window.passwords_source.style.display = 'inline-block'
      window.passwords_files_view.style.display = PASSWORD_SOURCE === 'file' ? 'block' : 'none'
    } else {
      window.passwords_source.style.display = 'none'
      window.passwords_files_view.style.display = 'none'
    }
  }

  function setCurerntBruteforceLink() {
    const state = {
      list:	window.addrlist.value,
      bip: window.bipmask.value,
    }
    if (window.derive.value > 0) { state.derive = 2 ** window.derive.value }
    if (MNEMONIC_PASSWORD) { state.password = MNEMONIC_PASSWORD }
    var url = new URL(location.href)
    url.searchParams.set('state', btoa(JSON.stringify(state)))
    window.bruteforce_link.href = url.toString()
    window.bruteforce_link.innerText = url.toString()
  }

  function loadSavedState() {
    var url = new URL(location.href)
    var state = url.searchParams.get('state')
    if (url.searchParams.get('state')) {
      state = JSON.parse(atob(url.searchParams.get('state')))
      console.log('set saved state', state)
      window.bipmask.value = state.bip
      window.addrlist.value = state.list
      DERIVE_ADDRESSES = state.derive || 1
      PASSWORD_SOURCE = 'default'
      window.passwords_files_view.style.display = 'none'
      window.passwords_source.options.selectedIndex = 0
      MNEMONIC_PASSWORD = state.password || ''
      window.derive.value = Math.log2(DERIVE_ADDRESSES)
      window.deriveView.innerText = DERIVE_ADDRESSES
      window.mnemonic_password.value = MNEMONIC_PASSWORD
      return
    }
    window.bipmask.value = localStorage.getItem('bipmask') || window.bipmask.value
    window.addrlist.value = localStorage.getItem('addrlist') || window.addrlist.value
    DERIVE_ADDRESSES = Number(localStorage.getItem('derive_addresses')) || 1
    PASSWORD_SOURCE = localStorage.getItem('password_source') || 'default'
    window.passwords_files_view.style.display = PASSWORD_SOURCE === 'file' ? 'block' : 'none'
    window.passwords_source.options.selectedIndex = PASSWORD_SOURCE === 'file' ? 1 : 0
    MNEMONIC_PASSWORD = localStorage.getItem('mnemonic_password') || ''
    window.derive.value = Math.log2(DERIVE_ADDRESSES)
    window.deriveView.innerText = DERIVE_ADDRESSES
    window.mnemonic_password.value = MNEMONIC_PASSWORD
    
    let progress = localStorage.getItem('progress')
    if (progress) {
      pausedBruteforce = true
      progress = JSON.parse(progress)
      showPausedBruteforce()
      const { permCount } = permutations(window.bipmask.value)
      if (permCount > 1) {
        log(`Bruteforce saved at ${(progress.seeds / permCount * 100 | 0)}%`)
      } else {
        log(`Bruteforce saved at ${progress.progress.toFixed(1)}% ${progress.file}`)
      }
    }
  }
  loadSavedState()
  checkInput()

  window.bipmask.onchange = () => { localStorage.setItem('bipmask', window.bipmask.value); checkInput() }
  window.bipmask.oninput = checkInput
  window.addrlist.onchange = () => { localStorage.setItem('addrlist', window.addrlist.value); checkInput() }
  window.addrlist.oninput = checkInput
})

async function brutePasswordGPU({ SAVED_PROGRESS, bip39mask, hashList, addrType }) {
    let paused = false
    window.pause_btn.onclick = () => paused = true
    
    const batchSize = 1024 * 32
    const ADDR_COUNT = DERIVE_ADDRESSES
    const WORKGROUP_SIZE = 64
    const {
      name: gpuName,
      clean,
      inference,
      setEccTable,
      prepareShaderPipeline,
    } = await webGPUinit({ BUF_SIZE: Math.max(batchSize*196, batchSize*64*ADDR_COUNT) })
    log(SAVED_PROGRESS ? `[${gpuName}]\nBruteforce resume...` : `[${gpuName}]\nBruteforce init...`, true)
    await setEccTable(addrType === 'solana' ? 'ed25519' : 'secp256k1')
    const PASSWORD_LISTS = PASSWORD_SOURCE === 'default' ? [
      { url: 'forced-browsing/all.txt', filePasswords: 43135 },
      { url: 'usernames.txt', filePasswords: 403335 },
      { url: '1000000-password-seclists.txt', filePasswords: 1000000 },
      { url: '2151220-passwords.txt', filePasswords: 2151220 },
      { url: '38650-password-sktorrent.txt', filePasswords: 38650 },
      { url: '38650-username-sktorrent.txt', filePasswords: 38650 },
      { url: 'uniqpass-v16-passwords.txt', filePasswords: 2151220 },
      { url: 'cain.txt', filePasswords: 306706 },
      { url: 'us-cities.txt', filePasswords: 20580 },
      { url: '7-more-passwords.txt', filePasswords: 528136 },
      { url: '8-more-passwords.txt', filePasswords: 61682 },
      { url: 'facebook-firstnames.txt', filePasswords: 4347667 },
    ] : PASSWORD_FILES
    await prepareShaderPipeline({
        progress: logCompilationProgress(),
        addrType,
        addrCount: ADDR_COUNT,
        MNEMONIC: bip39mask,
        WORKGROUP_SIZE,
        hashList,
    })
    let curList = 0, nextBatch = null, passwordsChecked = 0, curFile = '', rewind = !!SAVED_PROGRESS
    if (SAVED_PROGRESS) {
      curList = PASSWORD_LISTS.findIndex((f) => (f.url || f.name) === SAVED_PROGRESS.file)
    }
    while (!paused) {
        const inp = nextBatch && (await nextBatch(batchSize))
        if (!inp) {
          if (curList >= PASSWORD_LISTS.length) {
            log(`Password not found :(`, true)
            break
          }
          passwordsChecked = 0
          curFile = PASSWORD_LISTS[curList].url || PASSWORD_LISTS[curList].name
          nextBatch = await getPasswords(PASSWORD_LISTS[curList++])
          continue
        }
        passwordsChecked += batchSize
        if (rewind && passwordsChecked < SAVED_PROGRESS.passwords) {
          log(`[${gpuName}]\n${inp.name} (${curList}/${PASSWORD_LISTS.length}) ${inp.progress.toFixed(1).padStart(4, '')}% rewind...`, true)
          continue
        }
        rewind = false
        localStorage.setItem('progress', JSON.stringify({ passwords: passwordsChecked, progress: inp.progress, file: curFile }))
        const start = performance.now()
        out = await inference({ inp: new Uint32Array(inp.passwords), count: batchSize })
        const time = (performance.now() - start) / 1000
        const speed = batchSize / time | 0
        log(`[${gpuName}]\n${inp.name} (${curList}/${PASSWORD_LISTS.length}) ${inp.progress.toFixed(1).padStart(4, '')}% ${speed} passwords/s`, true)
        if (out[0] !== 0xffffffff) {
            const mnemoIndex = out[0] / ADDR_COUNT | 0
            const passBuf = new Uint8Array(inp.passwords)
            const passBufIndex = new Uint32Array(inp.passwords, 128)
            const index = passBufIndex[mnemoIndex]
            const index2 = passBufIndex[mnemoIndex + 1]
            log(`FOUND :)\nPassword: ${new TextDecoder().decode(passBuf.slice(index, index2 - 1))}`, true)
            break
        }
    }
    clean()
    return paused
}

async function bruteSeedGPU({ SAVED_PROGRESS, bip39mask, hashList, addrType }) {
  let paused = false
  window.pause_btn.onclick = () => paused = true

  const batchSize = 1024 * 32
  const ADDR_COUNT = DERIVE_ADDRESSES
  const WORKGROUP_SIZE = 64
  const {
    name,
    clean,
    setEccTable,
    inferenceMask,
    prepareShaderPipeline,
  } = await webGPUinit({ SAVED_PROGRESS, BUF_SIZE: Math.max(batchSize*196, batchSize*64*ADDR_COUNT) })
  log(SAVED_PROGRESS ? `[${name}]\nBruteforce resume...` : `[${name}]\nBruteforce init...`, true)
  await setEccTable(addrType === 'solana' ? 'ed25519' : 'secp256k1')
  await prepareShaderPipeline({
    progress: logCompilationProgress(),
    mode: 'mask',
    addrType,
    addrCount: ADDR_COUNT,
    MNEMONIC: bip39mask,
    MNEMONIC_PASSWORD,
    WORKGROUP_SIZE,
    hashList,
  })
  const { perm, permCount, seedsPerValid } = permutations(bip39mask)
  while (!paused) {
    const start = performance.now()
    const { ended, found, progress, seedsChecked } = await inferenceMask({
      derivePerSeed: ADDR_COUNT,
      count: batchSize,
      permCount,
      seedsPerValid,
    })
    localStorage.setItem('progress', JSON.stringify({ seeds: seedsChecked }))
    const time = (performance.now() - start) / 1000
    const speed = batchSize / time | 0
    log(`[${name}]\n${progress * 100 | 0}% ${speed} seeds/s`, true)
    if (ended) {
      if (found !== null) {
        log(`FOUND :)\nSeed: ${perm(found).map(x => biplist[x]).join(' ')}`, true)
      } else {
        log(`Seed not found :(`, true)
      }
      break
    }
  }
  
  clean()
  return paused
}

function logCompilationProgress() {
  let prevProgress = null
  return (shaderName) => {
    if (prevProgress) { window.output.innerHTML += ` [${((Date.now() - prevProgress)/1000).toFixed(1)}s]\n` }
    prevProgress = Date.now()
    if (shaderName) { window.output.innerHTML += `Compile shader: ${shaderName}...` }
  }
}

async function getPasswords(file) {
  let reader = null
  if (file.url) {
    const resp = await fetch(`https://duyet.github.io/bruteforce-database/${file.url}`)
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`)
    reader = resp.body.getReader()
  } else {
    reader = file.stream().getReader()
  }
  
  let partialBuf = new Uint8Array(0)
  let ended = false
  let processedPasswords = 0
  let processedBytes = 0

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
        let pwd = partialBuf.subarray(0, newlinePos + 1)
        if (pwd[pwd.length - 2] === 0x0D) { // \r\n
          pwd = partialBuf.subarray(0, newlinePos)
          pwd[pwd.length - 1] = 10
        }
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
      processedBytes += c.length
    }
    processedPasswords += count
    let progress = processedBytes / file.size * 100
    if (file.filePasswords) {
      progress = processedPasswords / file.filePasswords * 100
    }
    return { name: file.name || file.url, passwords: flat.buffer, progress };
  }

  return batch;
}

async function validateInput(showLog) {
  var output = ''
  const bip39mask = window.bipmask.value
  let result = true
  const words = bip39mask.trim().split(/[\s \t]+/)
  if (![12, 15, 18, 24].includes(words.length)) {
      output += `Expected 12/15/18/24 words, got ${words.length}\n`
      result = false
  }
  let asterisks = 0
  for (let word of words) {
    if (word === '*') { asterisks++; continue }
    for (let wordPart of word.split(',')) {
      if (wordPart.indexOf('?') === -1 && wordPart.indexOf('*') === -1 && !biplist.includes(wordPart)) {
        output += `${wordPart} is invalid bip39 word\n`
        result = false
      }
    }
  }
  const { permCount, error: maskError } = permutations(words.join(' '))
  if (maskError) {
    output += maskError + '\n'
    result = false
  }
  if (permCount > 2 ** 40) {
    output += `Can't brute more than 2^40 variants\n`
    result = false
  }
  const addrlist = window.addrlist.value.split('\n').map(x => x.trim()).filter(x => x)
  if (addrlist.length === 0) {
    output = `Enter at least 1 address\n`;
    result = false
  }
  const addrHash160list = []
  let addrTypes = new Set()
  for (let addr of addrlist) {
    const { hash160, type } = await addrToScriptHash(addr) || {}
    if (hash160) {
      addrTypes.add(type)
      addrHash160list.push(hash160)
    } else {
      output += `${addr} is invalid address\n`
      result = false
    }
  }
  addrTypes = Array.from(addrTypes)
  if (addrTypes.length > 1) {
    output += `WARNING! Multiple address types: ${addrTypes.join(', ')}\nOnly ${addrTypes[0]} will be used\n`;
  }
  const mode = permCount > 1 ? 'mask' : 'password'
  output += ('\n' + [
    `Mode:     ${mode}`,
    `Address:  ${addrTypes[0]}`,
    `Derived:  ${DERIVE_ADDRESSES}`, permCount > 1 &&
    `Variants: ${permCount < 10_000_000 ? `${permCount / 1000 | 0} thousands` : `${permCount / 1_000_000 | 0} million`}`, permCount > 1 && MNEMONIC_PASSWORD &&
    `Password: ${MNEMONIC_PASSWORD}`
  ].filter(x => x).join('\n'))
  if (showLog) { window.output.innerHTML = output }
  return result && { bip39mask: words.join(' '), permCount, addrHash160list, addrTypes }
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
    if (!checksumValid && isSolPubkey(decodedData)) {
      return { hash160: decodedData, type: 'solana' }
    }
    if (!checksumValid) return null
    const type = { '0': 'p2pkh', '5': 'p2sh', '65': 'tron' }[decodedData[0]]
    if (!type) return null
    return { hash160: decodedData.slice(1, 21), type }
}

function isSolPubkey(key) {
    const P = 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffedn;
    const D = 0x52036cee2b6ffe738cc740797779e89800700a4d4141d8ab75eb4dca135978a3n;
    const M = (a, b = P) => (b + a % b) % b;
    function modExp(base, exponent) {
        let result = 1n; base = M(base);
        while (exponent > 0n) {
            if (exponent % 2n === 1n) { result = M(result * base); }
            exponent = exponent >> 1n;
            base = M(base * base);
        }
        return result;
    }

    if (key.length !== 32) return false
    const y = BigInt('0x'+Array.from(key).map(x => x.toString(16).padStart(2, '0')).reverse().join('')) & ((1n << 255n) - 1n)
    const u = M(y * y - 1n);
    const v = M(D * y * y + 1n);
    let x = M(u * M(v ** 3n) * modExp(u * M(v ** 7n), (P - 5n) / 8n, P)); // (uv³)(uv⁷)^(p-5)/8
    return M(v * x * x) === u || M(v * x * x) === M(-u)
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
