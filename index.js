function threadPool(THREADS) {
  window.output.innerHTML += `spawning ${THREADS} threads\n`;
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
  return { waitFree, waitAll }
}

const biplist = fetch('bip39.txt').then(r => r.text()).then(t => t.split('\n').map(x => x.trim()).filter(x => x))

document.addEventListener('DOMContentLoaded', () => {
  window.brute.onclick = startBrute
  async function checkInput() {
    window.brute.style.visibility = await validateInput() ? 'visible' : 'hidden'
  }
  window.bipmask.onchange = checkInput
  window.bipmask.oninput = checkInput
  window.addrlist.onchange = checkInput
  window.addrlist.oninput = checkInput
  checkInput()
})

async function validateInput() {
  window.output.innerHTML = ''
  const allWords = await biplist
  const bip39mask = window.bipmask.value
  let result = true
  const words = bip39mask.trim().split(/[\s \t]+/)
  if (words.length !== 12) {
      window.output.innerHTML += `Expected 12 words, got ${words.length}\n`
      result = false
  }
  let asterisks = 0
  for (let word of words) {
    if (word === '*') { asterisks++; continue }
    if (!allWords.includes(word)) {
      window.output.innerHTML += `${word} is invalid bip39 word\n`
      result = false
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
  for (let addr of addrlist) {
    if (!await isValidBitcoinAddress(addr)) {
      window.output.innerHTML += `${addr} is invalid address\n`
      result = false
    } else {
      addrHash160list.push(base58Decode(addr).slice(1, 21))
    }
  }
  return result && { bip39mask: words.join(' '), addrHash160list }
}

async function startBrute() {
  const { bip39mask, addrHash160list } = await validateInput()
  const allWords = await biplist

  const start = performance.now()
  if (bip39mask.split('*').length <= 2) {
    const worker = new Worker(`worker.js?i=0`)
    worker.postMessage({ allWords, mnemonicPartial: bip39mask, addrHash160list })
    const res = await new Promise(res => { worker.onmessage = res })
    if (res.data) {
      window.output.innerHTML = `FOUND! ${res.data}\n`;
    }
    const time = (performance.now() - start) / 1000
    const totalOps = 2048 / 16
    window.output.innerHTML += `\nChecked all in ${time | 0} seconds (${totalOps / time | 0} mnemonic/s)\n`;
    worker.terminate()
    return
  }
  const THREADS = navigator.hardwareConcurrency || 4
  const { waitFree, waitAll } = threadPool(THREADS)
  let i = 0
  for (let word of allWords) {
    const { res, postMessage, isNew } = await waitFree()
    const message = { mnemonicPartial: bip39mask.replace('*', word), addrHash160list }
    if (isNew) {
      message.allWords = allWords
    }
    postMessage(message)
    if (i >= THREADS) {
      const time = (performance.now() - start) / 1000
      const ops = 2048 * (i - THREADS) / 16
      window.output.innerHTML = `${(100 * (i - THREADS) / allWords.length).toFixed(1)}%, ${ops / time | 0} mnemonic/s\n`
    } else {
      window.output.innerHTML = `Starting...\n`
    }
    if (res.data) {
      window.output.innerHTML = `FOUND! ${res.data}\n`;
      break
    }
    i++
  }
  if (i === allWords.length) {
    window.output.innerHTML = `Finishing...\n`
    const arr = await waitAll()
    arr.forEach(r => {
      if (r[0].data) {
        window.output.innerHTML = `FOUND! ${r[0].data}\n`;
      }
    })
  }
  const time = (performance.now() - start) / 1000
  const totalOps = 2048 * i / 16
  window.output.innerHTML += `\nChecked all in ${time | 0} seconds (${totalOps / time | 0} mnemonic/s)\n`;

}

function base58Decode(str) {
  const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  const bytes = [0];
  for (let i = 0; i < str.length; i++) {
    const char = str[i];
    const value = alphabet.indexOf(char);
    if (value === -1) throw new Error("Invalid Base58 character");
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


async function isValidBitcoinAddress(address) {
    const sha256HashSync = async (data) => {
      return new Uint8Array(await crypto.subtle.digest('SHA-256', new Uint8Array(data)))
    }
    try {
        let decodedData = await base58Decode(address)
        const versionByte = decodedData.slice(0, 1)
        const payload = decodedData.slice(1, -4)
        const checksumProvided = decodedData.slice(-4)
        const doubleSha256 = await sha256HashSync(await sha256HashSync([...versionByte, ...payload]))
        const checksumCalculated = doubleSha256.slice(0, 4)
        return (versionByte[0] === 0 &&
            Array.from(checksumCalculated).every((byte, i) => byte === checksumProvided[i]))
    } catch (err) {
        console.error(err)
        return false
    }
}