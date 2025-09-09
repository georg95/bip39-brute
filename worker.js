let allWords = []
let DERIVE_ADDRESSES = 1
onmessage = async function (message) {
  const { mnemonicPartial, addrHash160list, addrTypes } = message.data;
  if (message.data.allWords) {
    allWords = message.data.allWords
  }
  if (message.data.deriveCount != undefined) {
    DERIVE_ADDRESSES = Math.max(1, message.data.deriveCount)
  }
  const found = await bruteBtcAddr(mnemonicPartial, allWords, addrHash160list, addrTypes)
  postMessage(found)
}
const THREAD_NUM = Number(location.href.split('i=')[1])

async function getValidIndexes(allWords, parts) {
  const mnemoIndexes = mnemonicIndexes(parts[0] + 'pen' + parts[1], allWords)
  const wordIndex = parts[0].split(/\s+/).length - 1
  const validIndexes = []
  for (let i = 0; i < allWords.length; i++) {
    mnemoIndexes[wordIndex] = i
    if (await isValidMnemonic(mnemoIndexes)) { validIndexes.push(i) }
  }
  return validIndexes
}

async function bruteBtcAddr(mnemonicPartial, allWords, addrHash160list, addrTypes) {
  const keccak = await initKeccak
  const hash160 = await initRipemd160
  if (allWords.length === 0) throw new Error('allWords is empty')
  var parts = mnemonicPartial.split('*')
  if (parts.length !== 2) throw new Error('one * supported')
  var seeds = []
  if (THREAD_NUM === 0 || THREAD_NUM === 1) {
    const validIndexes = await getValidIndexes(allWords, parts)
    for (let index of validIndexes) {
        const mnemonic = parts[0] + allWords[index] + parts[1]
        seeds.push(await mnemonicToSeed(mnemonic))
    }
  } else {
    seeds = await mnemonicToSeeds(mnemonicPartial)
  }

  let found = ''

  for (addrType of addrTypes) {
    const [network, coinType] = ADDRTYPEMAP[addrType];
    let reedemScript = new Uint8Array(22)
    reedemScript[0] = 0x00
    reedemScript[1] = 0x14
    let i = 0
    for (let seed of seeds) {
      let privKeys = await derivePath(seed, network, coinType)
      for (let privKey of privKeys) {
        let hash = null
        if (addrType === 'eth' || addrType === 'tron') {
          const pubKey = getPublicKey(privKey, false) 
          hash = (await keccak(pubKey.slice(1))).slice(12)
        } else if (addrType === 'p2sh') {
          const pubKey = getPublicKey(privKey)
          reedemScript.set(await hash160(pubKey), 2)
          hash = await hash160(reedemScript)
        } else {
          const pubKey = getPublicKey(privKey)
          hash = await hash160(pubKey)
        }

        for (let addrHash of addrHash160list) {
          if (addrHash[0] == hash[0] && addrHash[1] == hash[1] && bytesToHex(hash) === bytesToHex(addrHash)) {
            found = parts[0] + allWords[(await getValidIndexes(allWords, parts))[i]] + parts[1];
            console.log(`[${THREAD_NUM}] FOUND! ${found}\n`)
          }
        }
      }
      i++
    }
  }
  return found
}

const wasmInstancePbkdf2 = WebAssembly.instantiateStreaming(fetch('./wasm.wasm'))

async function mnemonicToSeedBench(LOOPS) {
  const {instance: { exports }} = await wasmInstancePbkdf2;
  const { pbkdf2_bench } = exports;
  return pbkdf2_bench(LOOPS);
}

async function mnemonicToSeeds(mnemonicPartial) {
  const {instance: { exports }} = await wasmInstancePbkdf2;
  const { pbkdf2, getMnemoPtr, getSeedsPtr, memory: {buffer} } = exports;
  const mnemoPtr = getMnemoPtr();
  const seedsPtr = getSeedsPtr();
  const mnemoMemory = new Uint8Array(buffer, mnemoPtr, mnemonicPartial.length);
  mnemoMemory.set(new TextEncoder().encode(mnemonicPartial));
  const seedsCount = pbkdf2(mnemonicPartial.length, 2048);
  const seedsMemory = new Uint8Array(buffer, seedsPtr, seedsCount * 64);
  const seedBytes = 64;
  const seeds = Array(seedsCount).fill(0).map((_, i) => seedsMemory.slice(i * seedBytes, (i + 1) * seedBytes));
  return seeds;
}


function mnemonicIndexes(mnemonic, wordlist) {
  const words = mnemonic.trim().toLowerCase().split(/\s+/);
  if (![12, 15, 18, 24].includes(words.length)) throw new Error(`invalid mnemonic length ${words.length}`);
  const indexes = words.map(word => wordlist.indexOf(word));
  if (indexes.includes(-1)) throw new Error(`invalid word ${words.find(word => wordlist.indexOf(word) === -1)}`)
  return indexes;
}

async function isValidMnemonic(indexes) {
  const entropyBytes = new Uint8Array(33);
  let acc = 0;
  let accBits = 0;
  var j = 0;
  for (let w of indexes) {
    acc = (acc << 11) | w;
    accBits += 11;
    while (accBits >= 8) {
      accBits -= 8;
      entropyBytes[j++] = (acc >>> accBits) & 0xff;
    }
  }
  if (indexes.length === 12) {
    const hash = new Uint8Array(await crypto.subtle.digest('SHA-256', entropyBytes.slice(0, 16)))
    return (indexes[11] & 0x0f) === hash[0] >> 4;
  } else if (indexes.length === 24) {
      const hash = new Uint8Array(await crypto.subtle.digest('SHA-256', entropyBytes.slice(0, 32)))
      return hash[0] === entropyBytes[32];
  } else if (indexes.length === 18) {
      const hash = new Uint8Array(await crypto.subtle.digest('SHA-256', entropyBytes.slice(0, 24)))
      return (hash[0] >> 2) === (indexes[17] & 0x3f);
  } else if (indexes.length === 15) {
      const hash = new Uint8Array(await crypto.subtle.digest('SHA-256', entropyBytes.slice(0, 20)))
      return ((hash[0] >> 3) & 0x1f) === (indexes[14] & 0x1f);
  }
  return false
}

const encoder = new TextEncoder()
const saltBuffer = encoder.encode("mnemonic")
async function mnemonicToSeed(mnemonic) {
  const mnemonicBuffer = encoder.encode(mnemonic)
  const keyMaterial = await crypto.subtle.importKey(
    "raw",
    mnemonicBuffer,
    { name: "PBKDF2" },
    false,
    ["deriveBits"]
  );
  const derivedBits = await crypto.subtle.deriveBits(
    {
      name: "PBKDF2",
      salt: saltBuffer,
      iterations: 2048,
      hash: "SHA-512"
    },
    keyMaterial,
    512
  );

  return new Uint8Array(derivedBits);
}

const CURVE_N = BigInt("0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141");
const BITCOIN_SEED = new TextEncoder().encode('Bitcoin seed')
let mcryptoKey = null;
crypto.subtle.importKey("raw", BITCOIN_SEED, { name: "HMAC", hash: "SHA-512" }, false, ["sign"]).then(key => mcryptoKey = key);

const DATABUF = new Uint8Array(1 + 32 + 4);

const ADDRTYPEMAP = {
  'p2wphk': [84, 0],
  'p2pkh': [44, 0],
  'p2sh': [49, 0],
  'eth': [44, 60],
  'tron': [44, 195],
}
async function derivePath(seed, network, coinType) {
  const msignature = await crypto.subtle.sign("HMAC", mcryptoKey, seed)
  const master = new Uint8Array(msignature)
  let privKey = bytesToBigInt(master.slice(0, 32), 32); 
  let chainCode = master.slice(32)

  {
    DATABUF[0] = 0x00
    DATABUF.set(bigIntToBytes(privKey, 32), 1)
    DATABUF.set([128, 0, 0, network], 33)
    const cryptoKey = await crypto.subtle.importKey("raw", chainCode, { name: "HMAC", hash: "SHA-512" }, false, ["sign"]);
    const signature = await crypto.subtle.sign("HMAC", cryptoKey, DATABUF);
    const I = new Uint8Array(signature);
    privKey = (bytesToBigInt(I.slice(0, 32)) + privKey) % CURVE_N;
    chainCode = I.slice(32)
  }
  {
    DATABUF[0] = 0x00
    DATABUF.set(bigIntToBytes(privKey, 32), 1)
    DATABUF.set([128, 0, 0, coinType], 33)
    const cryptoKey = await crypto.subtle.importKey("raw", chainCode, { name: "HMAC", hash: "SHA-512" }, false, ["sign"]);
    const signature = await crypto.subtle.sign("HMAC", cryptoKey, DATABUF);
    const I = new Uint8Array(signature);
    privKey = (privKey + bytesToBigInt(I.slice(0, 32))) % CURVE_N;
    chainCode = I.slice(32)
  }
  {
    DATABUF[0] = 0x00
    DATABUF.set(bigIntToBytes(privKey, 32), 1)
    DATABUF.set([128, 0, 0, 0], 33)
    const cryptoKey = await crypto.subtle.importKey("raw", chainCode, { name: "HMAC", hash: "SHA-512" }, false, ["sign"]);
    const signature = await crypto.subtle.sign("HMAC", cryptoKey, DATABUF);
    const I = new Uint8Array(signature);
    privKey = (bytesToBigInt(I.slice(0, 32)) + privKey) % CURVE_N;
    chainCode = I.slice(32)
  }
  {
    DATABUF.set([0, 0, 0, 0], 33)
    DATABUF.set(getPublicKey(privKey), 0)
    DATABUF[36] = 0x00
    const cryptoKey = await crypto.subtle.importKey("raw", chainCode, { name: "HMAC", hash: "SHA-512" }, false, ["sign"]);
    const signature = await crypto.subtle.sign("HMAC", cryptoKey, DATABUF);
    const I = new Uint8Array(signature);
    privKey = (bytesToBigInt(I.slice(0, 32)) + privKey) % CURVE_N;
    chainCode = I.slice(32)
  }
  var privKeys = []
  DATABUF.set([0, 0, 0, 0], 33)
  DATABUF.set(getPublicKey(privKey), 0)
  const cryptoKey = await crypto.subtle.importKey("raw", chainCode, { name: "HMAC", hash: "SHA-512" }, false, ["sign"])
  for (let i = 0; i < DERIVE_ADDRESSES; i++) {
    DATABUF[36] = i
    const I = new Uint8Array(await crypto.subtle.sign("HMAC", cryptoKey, DATABUF))
    privKeys.push((bytesToBigInt(I.slice(0, 32)) + privKey) % CURVE_N)
  }

  return privKeys;
}  

function bytesToHex(bytes) {
  return Array.from(bytes).map(b => b.toString(16).padStart(2, '0')).join('');
}
function bytesToBigInt(bytes) {
  return BigInt('0x' + bytesToHex(bytes));
}
function bigIntToBytes(num, length) {
  let hex = num.toString(16).padStart(length * 2, '0');
  let bytes = new Uint8Array(length);
  for (let i = 0; i < length; i++) {
    bytes[i] = parseInt(hex.substr(i * 2, 2), 16);
  }
  return bytes;
}

function hexToUint8Array(hexString) {
    const bytes = [];
    for (let i = 0; i < hexString.length; i += 2) {
        bytes.push(parseInt(hexString.substr(i, 2), 16));
    }
    return new Uint8Array(bytes);
}

const KECCAK_WASM = hexToUint8Array(
"0061736d010000000105016000017f0302010005030100110619037f01418080c0000b7f0041c081c0000b7f00418082c0000b072204066d656d6f72" +
"790200096b656363616b323536000003494e500301034f555403020afa0901f70902027f2d7e2380808080004190026b2200248080808000024041c0" +
"00450d00200041086a41c081c0800041c000fc0a00000b41002101024041c801450d00200041c8006a410041c801fc0b000b02400340200141c00046" +
"0d01200041c8006a20016a200041086a20016a290000370300200141086a21010c000b0b20002903c801428080808080808080807f85210220002903" +
"8801420185210341c07e21012000290388022104200029038002210520002903f801210620002903f001210720002903e801210820002903e0012109" +
"20002903d801210a20002903d001210b20002903c001210c20002903b801210d20002903b001210e20002903a801210f20002903a001211020002903" +
"980121112000290390012112200029038001211320002903782114200029037021152000290368211620002903602117200029035821182000290350" +
"21192000290348211a037f024020010d0020002004370388022000200537038002200020063703f801200020073703f001200020083703e801200020" +
"093703e0012000200a3703d8012000200b3703d001200020023703c8012000200c3703c0012000200d3703b8012000200e3703b0012000200f3703a8" +
"01200020103703a001200020113703980120002012370390012000200337038801200020133703800120002014370378200020153703702000201637" +
"03682000201737036020002018370358200020193703502000201a370348410021010240034020014120460d012001418082c080006a200041c8006a" +
"20016a290300370000200141086a21010c000b0b20004190026a248080808000418082c080000f0b200c200885201185201585201a85221b200b2006" +
"85200f85201385201885221c42018985221d201485211e201b420189200a200585200e85200385201785221f85221b2004852120201c200920048520" +
"0d85201285201685222142018985221c200385423789222220022007852010852014852019852203201f42018985221f201885423e892223427f8583" +
"201d200785420289222485210420034201892021852218200c854229892221201b200d854227892225427f85832022852107201c2005854238892226" +
"201f200b85420f892227427f8583201d201085420a89222885210b202820182015854224892229427f8583201b201685421b89221685210c201f2013" +
"85420689222a201d201985420189222b427f85832018200885421289222c85210d201b200985420889222d201c200e85421989222e427f8583202a85" +
"2110201b201285421489221b201c201785421c892205427f8583201f200685423d89220685211220052006427f8583201d200285422d89221d852103" +
"2006201d427f858320182011854203892202852113201d2002427f8583201b8521142002201b427f858320058521152018201a85221d2020420e8922" +
"1b427f8583201c200a85421589221c852117201b201c427f8583201f200f85422b89221f852118201c201f427f8583201e422c89221c852119201f20" +
"1c427f8583200141c081c080006a29030085201d85211a200141086a210120232024427f8583202185210520242021427f8583202585210620252022" +
"427f8583202385210820292016427f8583202685210920162026427f8583202785210a20272028427f85832029852102202b202c427f8583202d8521" +
"0e202c202d427f8583202e85210f202e202a427f8583202b852111201c201d427f8583201b8521160c000b0b0bca010100418080c0000bc001010000" +
"000000000082800000000000008a8000000000008000800080000000808b800000000000000100008000000000818000800000008009800000000000" +
"808a00000000000000880000000000000009800080000000000a000080000000008b800080000000008b000000000000808980000000000080038000" +
"0000000080028000000000008080000000000000800a800000000000000a000080000000808180008000000080808000000000008001000080000000" +
"000880008000000080")

const initKeccak = (async function () {
  const {instance: { exports: { INP: { value: INP_PTR }, OUT: { value: OUT_PTR }, keccak256, memory: {buffer} } }} =
    await WebAssembly.instantiate(KECCAK_WASM)
  const inpMemory = new Uint8Array(buffer, INP_PTR, 64);
  const outMemory = new Uint8Array(buffer, OUT_PTR, 32);
  return function keccak(buf) {
    inpMemory.set(buf)
    keccak256()
    return outMemory
  }
})()

const RIPEMD160_WASM = hexToUint8Array("0061736d0100000001130360017f017f60027f7f0060047f7f7f7f017f03040300010205030100110619037f01418080c0000b7f0041c883c0000b7f" +
"00418884c0000b072004066d656d6f727902000768617368313630000003494e500301034f555403020aaa0903980302047f017e23808080800041e0" +
"006b2201248080808000024041e000450d002001418080c0800041e000fc0a00000b4100210202400340200241c0006a220320004b0d012001200241" +
"c883c080006a108180808000200321020c000b0b2001411c6a21030240200020026b2204450d00200320012d005c6a200241c883c080006a2004fc0a" +
"00000b200120012903002000ad7c2205370300200120012d005c20046a22023a005c024041c000200241ff017122026b2200450d00200320026a4100" +
"2000fc0b000b200320012d005c6a4180013a0000200120012d005c220241016a3a005c0240200241374d0d0020012003108180808000024041c00045" +
"0d002003410041c000fc0b000b200129030021050b20012005a74103743a00542005420588210541d500210202400340200241dc00460d0120012002" +
"6a20053c0000200241016a2102200542088821050c000b0b200120031081808080004100200128020836028884c080004100200129020c37028c84c0" +
"80004100200129021437029484c08000200141e0006a248080808000418884c080000bb40501177f2380808080004180016b22022480808080004100" +
"210302400340200341c000460d01200220036a200120036a280000360200200341046a21030c000b0b41002104200028021822052106200521072000" +
"280214220821092008210a2000280210220b210c200b210d200028020c220e210f200e2110200028020822112112201121130240034020044105460d" +
"01200241c0006a41086a20044104742203419081c080006a290000370300200241d0006a41086a200341e081c080006a290000370300200241e0006a" +
"41086a200341b082c080006a290000370300200241f0006a41086a2003418083c080006a29000037030020022003418881c080006a29000037034020" +
"02200341d881c080006a2900003703502002200341a882c080006a2900003703602002200341f882c080006a2900003703702004410274220341f480" +
"c080006a2802002114200341e080c080006a280200211541002103034020072101024020034110470d00410420046b21154100210302400340200621" +
"0720034110460d012015200f200c20091082808080002116200241d0006a20036a2117200241f0006a20036a2118200341016a210320092106200c41" +
"0a772109200f210c2016201220146a6a200220172d00004102746a2802006a20182d00007720076a210f200721120c000b0b200441016a2104200721" +
"06200121070c020b20042010200d200a1082808080002116200241c0006a20036a2117200241e0006a20036a2118200341016a2103200a2107200d41" +
"0a77210a2010210d2016201320156a6a200220172d00004102746a2802006a20182d00007720016a2110200121130c000b0b0b2000200c20116a2010" +
"6a3602182000200f20056a20136a3602142000200720086a20126a36021020002006200b6a200a6a36020c20002009200e6a200d6a36020820024180" +
"016a2480808080000b58000240024002400240024020000e0400010203040b20022001732003730f0b20032001417f73712002200171720f0b200120" +
"02417f73722003730f0b200320017120022003417f7371720f0b20022003417f73722001730b0bd2030100418080c0000bc803000000000000000001" +
"23456789abcdeffedcba9876543210f0e1d2c30000000000000000000000000000000000000000000000000000000000000000000000000000000000" +
"000000000000000000000000000000000000000000000000000000000000009979825aa1ebd96edcbc1b8f4efd53a9e68ba25024d14d5cf33e706de9" +
"766d7a00000000000102030405060708090a0b0c0d0e0f07040d010a060f030c000905020e0b08030a0e04090f0801020700060d0b050c01090b0a00" +
"080c040d03070f0e05060204000509070c020a0e0103080b060f0d050e070009020b040d060f08010a030c060b0307000d050a0e0f080c040901020f" +
"050103070e06090b080c020a00040d08060401030b0f00050c020d09070a0e0c0f0a040105080706020d0e0003090b0b0e0f0c050807090b0d0e0f06" +
"0709080706080d0b09070f070c0f090b070d0c0b0d06070e090d0f0e080d06050c07050b0c0e0f0e0f0908090e05060806050c090f050b06080d0c05" +
"0c0d0e0b0805060809090b0d0f0f050707080b0e0e0c06090d0f070c08090b07070c07060f0d0b09070f0b0806060e0c0d050e0d0d07050f05080b0e" +
"0e060e06090c090c050f0808050c090c050e06080d06050f0d0b0b");

const initRipemd160 = (async function () {
  const {instance: { exports: { INP: { value: INP_PTR }, OUT: { value: OUT_PTR }, hash160, memory: {buffer} } }} =
    await WebAssembly.instantiate(RIPEMD160_WASM)
  const inpMemory = new Uint8Array(buffer, INP_PTR, 64);
  const outMemory = new Uint8Array(buffer, OUT_PTR, 20);
  return async function ripemd160(buf) {
    const hash = new Uint8Array(await crypto.subtle.digest("SHA-256", buf))
    inpMemory.set(hash)
    hash160(hash.length)
    return outMemory
  }
})()

const P = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2fn;
const u8n = (len) => new Uint8Array(len);
const concatBytes = (...arrs) => {
    const r = u8n(arrs.reduce((sum, a) => sum + a.length, 0)); // create u8a of summed length
    let pad = 0; // walk through each array,
    arrs.forEach(a => { r.set(a, pad); pad += a.length; }); // ensure they have proper type
    return r;
};
const M = (a, b = P) => {
    const r = a % b;
    return r >= 0n ? r : b + r;
};

const invert = (num) => {
    let a = M(num, P), b = P, x = 0n, y = 1n, u = 1n, v = 0n;
    while (a !== 0n) {
        const q = b / a, r = b % a;
        const m = x - u * q, n = y - v * q;
        b = a, a = r, x = u, y = v, u = m, v = n;
    }
    return M(x, P);
};
const isEven = (y) => (y & 1n) === 0n;
const u8of = (n) => Uint8Array.of(n);
const getPrefix = (y) => u8of(isEven(y) ? 0x02 : 0x03);

class Point {
    X;
    Y;
    Z;
    constructor(X, Y, Z) {
        this.X = X;
        this.Y = Y;
        this.Z = Z;
    }
    add(other) {
        const { X: X1, Y: Y1, Z: Z1 } = this;
        const { X: X2, Y: Y2, Z: Z2 } = other;
        let X3 = 0n, Y3 = 0n, Z3 = 0n;
        let t0 = M(X1 * X2);
        let t1 = M(Y1 * Y2);
        let t2 = M(Z1 * Z2);
        let t3 = M(X1 + Y1);
        let t4 = M(X2 + Y2);
        let t5 = M(X2 + Z2); // step 1
        t3 = M(t3 * t4);
        t4 = M(t0 + t1);
        t3 = M(t3 - t4);
        t4 = M(X1 + Z1);
        t4 = M(t4 * t5);
        t5 = M(t0 + t2);
        t4 = M(t4 - t5);
        t5 = M(Y1 + Z1);
        X3 = M(Y2 + Z2); // step 15
        t5 = M(t5 * X3);
        X3 = M(t1 + t2);
        t5 = M(t5 - X3);
        t2 = M(21n * t2); // step 20
        X3 = M(t1 - t2);
        Z3 = M(t1 + t2);
        Y3 = M(X3 * Z3);
        t1 = M(t0 + t0); // step 25
        t1 = M(t1 + t0);
        t4 = M(21n * t4);
        t0 = M(t1 * t4);
        Y3 = M(Y3 + t0);
        t0 = M(t5 * t4); // step 35
        X3 = M(t3 * X3);
        X3 = M(X3 - t0);
        t0 = M(t3 * t1);
        Z3 = M(t5 * Z3);
        Z3 = M(Z3 + t0); // step 40
        return new Point(X3, Y3, Z3);
    }
    toAffine() {
        const { X: x, Y: y, Z: z } = this;
        if (z === 1n)
            return { x, y };
        const iz = invert(z, P);
        if (M(z * iz) !== 1n)
            err('inverse invalid');
        return { x: M(x * iz), y: M(y * iz) };
    }
    negate() {
        return new Point(this.X, M(-this.Y), this.Z);
    }
    print(name) {
        console.log(`=== ${name}\nx:`, '0x'+this.X.toString(16), '\ny:', '0x'+this.Y.toString(16), '\nz:', '0x'+this.Z.toString(16));
    }
}
const fromHexString = (hexString) => Uint8Array.from(hexString.match(/.{1,2}/g).map((byte) => parseInt(byte, 16)));
const G = new Point(0x79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798n, 0x483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8n, 1n);
const I = new Point(0n, 1n, 0n);
const getPublicKey = (privKey, isCompressed=true) => {
    const { X: x, Y: y, Z: z } = wNAF(privKey);
    const iz = invert(z);
    const x32b = fromHexString(M(x * iz).toString(16).padStart(64, '0'));
    if (isCompressed)        
        return concatBytes(getPrefix(M(y * iz)), x32b);
    const y32b = fromHexString(M(y * iz).toString(16).padStart(64, '0'))
    return concatBytes(u8of(0x04), x32b, y32b);
};
const W = 8; // W is window size
export const precompute = (W, onBatch) => {
    function toAff(pt) {
      const { x, y } = pt.toAffine()
      return new Point(x, y, 1n)
    }
    function batchAff(pointsBatch) {
      let acc = 1n
      const scratch = [1n].concat(pointsBatch.map(ni => acc = (acc * ni.Z) % P))
      let inv = invert(acc)
      const Zinv = new Array(pointsBatch.length);
      for (let i = pointsBatch.length - 1; i >= 0; i--) {
        Zinv[i] = (scratch[i] * inv) % P
        inv = (inv * pointsBatch[i].Z) % P
      }
      return Zinv.map((iz, i) => new Point(M(pointsBatch[i].X * iz), M(pointsBatch[i].Y * iz), 1n));
    }
    const points = [];
    let p = G;
    let b = p;
    for (let w = 0; w < Math.ceil(256 / W) + 1; w++) {
        b = p
        var pointsBatch = []
        pointsBatch.push(b);
        for (let i = 1; i < 2 ** (W - 1); i++) {
            b = b.add(p);
            pointsBatch.push(b);
        }
        if (onBatch) {
          onBatch(batchAff(pointsBatch), w)
        } else {
          points = points.concat(batchAff(pointsBatch))
        }
        p = toAff(b.add(b));
    }
    return points;
};
let Gpows; // precomputes for base point G

const wNAF = (n) => {
    if (!Gpows) { Gpows = precompute(W) }
    let p = I;
    const mask = BigInt(2 ** W - 1); // 255 for W=8 == mask 0b11111111
    const shiftBy = BigInt(W); // 8 for W=8
    const ONE = 1n;
    const WIN_SIZE = 2 ** (W - 1);
    const pwindows = Math.ceil(256 / W) + 1;
    for (let w = 0; w < pwindows; w++) {
        let wbits = Number(n & mask); // extract W bits.
        n >>= shiftBy; // shift number by W bits.
        if (wbits > WIN_SIZE) {
            wbits -= 256;
            n += ONE;
        }
        const off = w * WIN_SIZE;
        if (wbits !== 0) {
            const offP = off + Math.abs(wbits) - 1;
            p = p.add(wbits < 0 ? Gpows[offP].negate() : Gpows[offP]); // bits are 1: add to result point
        }
    }
    return p; // return both real and fake points for JIT
};