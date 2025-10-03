const K_SHA: array<u32,64> = array<u32,64>(
    0x428a2f98u, 0x71374491u, 0xb5c0fbcfu, 0xe9b5dba5u, 0x3956c25bu, 0x59f111f1u, 0x923f82a4u, 0xab1c5ed5u,
    0xd807aa98u, 0x12835b01u, 0x243185beu, 0x550c7dc3u, 0x72be5d74u, 0x80deb1feu, 0x9bdc06a7u, 0xc19bf174u,
    0xe49b69c1u, 0xefbe4786u, 0x0fc19dc6u, 0x240ca1ccu, 0x2de92c6fu, 0x4a7484aau, 0x5cb0a9dcu, 0x76f988dau,
    0x983e5152u, 0xa831c66du, 0xb00327c8u, 0xbf597fc7u, 0xc6e00bf3u, 0xd5a79147u, 0x06ca6351u, 0x14292967u,
    0x27b70a85u, 0x2e1b2138u, 0x4d2c6dfcu, 0x53380d13u, 0x650a7354u, 0x766a0abbu, 0x81c2c92eu, 0x92722c85u,
    0xa2bfe8a1u, 0xa81a664bu, 0xc24b8b70u, 0xc76c51a3u, 0xd192e819u, 0xd6990624u, 0xf40e3585u, 0x106aa070u,
    0x19a4c116u, 0x1e376c08u, 0x2748774cu, 0x34b0bcb5u, 0x391c0cb3u, 0x4ed8aa4au, 0x5b9cca4fu, 0x682e6ff3u,
    0x748f82eeu, 0x78a5636fu, 0x84c87814u, 0x8cc70208u, 0x90befffau, 0xa4506cebu, 0xbef9a3f7u, 0xc67178f2u
);

fn shw(x: u32, n: u32) -> u32 { return (x << (n & 31u)) & 0xffffffffu; }
fn rrol(x: u32, n: u32) -> u32 { return (x >> n) | shw(x, 32u - n); }
fn g0(x: u32) -> u32 { return rrol(x, 7u) ^ rrol(x, 18u) ^ (x >> 3u); }
fn g1(x: u32) -> u32 { return rrol(x, 17u) ^ rrol(x, 19u) ^ (x >> 10u); }
fn s0(x: u32) -> u32 { return rrol(x, 2u) ^ rrol(x, 13u) ^ rrol(x, 22u); }
fn s1(x: u32) -> u32 { return rrol(x, 6u) ^ rrol(x, 11u) ^ rrol(x, 25u); }
fn maj(a: u32, b: u32, c: u32) -> u32 { return (a & b) ^ (a & c) ^ (b & c); }
fn ch(e: u32, f: u32, g: u32) -> u32 { return (e & f) ^ ((~e) & g); }

fn sha256(w: ptr<function, array<u32, 64>>, out: ptr<function, array<u32, 8>>) {
    for (var i = 16u; i < 64u; i++){
        w[i] = w[i - 16u] + g0(w[i - 15u]) + w[i - 7u] + g1(w[i - 2u]);
    }
    var a = 0x6a09e667u;
    var b = 0xbb67ae85u;
    var c = 0x3c6ef372u;
    var d = 0xa54ff53au;
    var e = 0x510e527fu;
    var f = 0x9b05688cu;
    var g = 0x1f83d9abu;
    var h = 0x5be0cd19u;
    for (var i = 0u; i < 64u; i++){
        let t2 = s0(a) + maj(a, b, c);
        let t1 = h + s1(e) + ch(e, f, g) + K_SHA[i] + w[i];
        h = g;
        g = f;
        f = e;
        e = d + t1;
        d = c;
        c = b;
        b = a;
        a = t1 + t2;
    }
    out[0] = a+0x6a09e667u;
    out[1] = b+0xbb67ae85u;
    out[2] = c+0x3c6ef372u;
    out[3] = d+0xa54ff53au;
    out[4] = e+0x510e527fu;
    out[5] = f+0x9b05688cu;
    out[6] = g+0x1f83d9abu;
    out[7] = h+0x5be0cd19u;
}

fn swap_bytes_u32(value: u32) -> u32 {
    return ((value & 0x000000FFu) << 24u) |
           ((value & 0x0000FF00u) << 8u)  |
           ((value & 0x00FF0000u) >> 8u)  |
           ((value & 0xFF000000u) >> 24u);
}

const masks = array<u32, 4>(0x00ffffff, 0xff00ffff, 0xffff00ff, 0xffffff00);
fn setByteArr(arr: ptr<function, array<u32, 64>>, idx: u32, byte: u32) {
  let i = idx/4;
  let sh = idx%4;
  arr[i] = (arr[i] & masks[sh]) + (byte << (24 - sh * 8));
}

fn setMnemoIndexes(w: ptr<function, array<u32, 64>>, indexes: array<u32, WORD_COUNT>) {
    for (var i = 0; i < 16; i++) {
        w[i] = 0;
    }
    var acc = 0u;
    var accBits = 0u;
    var j = 0u;
    for (var i = 0; i < WORD_COUNT; i++) {
        acc = (acc << 11u) | indexes[i];
        accBits += 3; setByteArr(w, j, (acc >> accBits) & 0xff); j++;
        if (accBits >= 8) {
            accBits -= 8; setByteArr(w, j, (acc >> accBits) & 0xff); j++;
        }
    }
}

const MASK = MASK__;
const MASKLEN = MASKLEN__;

fn permutation(N: u32) -> array<u32, WORD_COUNT> {
    var perm: array<u32, WORD_COUNT>;
    var curOff = 0u;
    var n = N;
    for (var i = 0; i < WORD_COUNT; i++) {
        if (MASKLEN[i] == 2048) {
            perm[WORD_COUNT - 1 - i] = n % 2048;
        } else {
            perm[WORD_COUNT - 1 - i] = MASK[curOff + n % MASKLEN[i]];
            curOff += MASKLEN[i];
        }
        n = n / MASKLEN[i];
    }
    return perm;
}

struct SeedIndexes {
    counter: atomic<u32>,
    offset: u32,
    indices: array<u32>,
};

@group(0) @binding(0) var<storage, read_write> output: SeedIndexes;

@compute @workgroup_size(WORKGROUP_SIZE)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
    var out: array<u32, 8>;
    var w: array<u32, 64>;
    var buf: array<u32, BUF_SIZE>;
    var curItem = 0u;
    for (var i = 0u; i < MNEMONICS_PER_THREAD; i++) {
        let index = output.offset + gid.x*MNEMONICS_PER_THREAD + i;
        let perm = permutation(index);
        setMnemoIndexes(&w, perm);
        let byte32 = w[8] >> 24;
        // sha256 padding
        var permIndex = 0;
        if (WORD_COUNT == 12) { setByteArr(&w, 16, 0x80); w[15] = 16 * 8; permIndex = 11; }
        if (WORD_COUNT == 15) { setByteArr(&w, 20, 0x80); w[15] = 20 * 8; permIndex = 14; }
        if (WORD_COUNT == 18) { setByteArr(&w, 24, 0x80); w[15] = 24 * 8; permIndex = 17; }
        if (WORD_COUNT == 24) { setByteArr(&w, 32, 0x80); w[15] = 32 * 8; }
        sha256(&w, &out);
        var isMnemonicValid: bool = false;
        if (WORD_COUNT == 12) { isMnemonicValid = (out[0] >> 28) == (perm[permIndex] & 0x0f); }
        if (WORD_COUNT == 15) { isMnemonicValid = (out[0] >> 27) == (perm[permIndex] & 0x1f); }
        if (WORD_COUNT == 18) { isMnemonicValid = (out[0] >> 26) == (perm[permIndex] & 0x3f); }
        if (WORD_COUNT == 24) { isMnemonicValid = (out[0] >> 24) == byte32; }
        if (isMnemonicValid) {
            buf[curItem] = index;
            curItem++;
        }
        if (curItem >= BUF_SIZE) {
            let pos = atomicAdd(&output.counter, BUF_SIZE);
            for (var j = 0u; j < BUF_SIZE; j++) {
                output.indices[pos + j] = buf[j];
            }
            curItem = 0u;
        }
    }
    let pos = atomicAdd(&output.counter, curItem);
    for (var j = 0u; j < curItem; j++) {
        output.indices[pos + j] = buf[j];
    }

}

