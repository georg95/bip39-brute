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

@group(0) @binding(0) var<storage, read> input: array<u32>;
@group(0) @binding(1) var<storage, read_write> output: array<u32>;

fn sha256(out: ptr<function, array<u32, 8>>, offset: u32) {
    var w = array<u32, 64>();
    for (var i = 0u; i < 16u; i++) {w[i] = 0; }
    w[0] = (input[offset + 16u] >> 8) | (((input[offset + 31u] & 1) + 2) << 24);
    w[1] = (input[offset + 17u] >> 8) | (input[offset + 16u] << 24);
    w[2] = (input[offset + 18u] >> 8) | (input[offset + 17u] << 24);
    w[3] = (input[offset + 19u] >> 8) | (input[offset + 18u] << 24);
    w[4] = (input[offset + 20u] >> 8) | (input[offset + 19u] << 24);
    w[5] = (input[offset + 21u] >> 8) | (input[offset + 20u] << 24);
    w[6] = (input[offset + 22u] >> 8) | (input[offset + 21u] << 24);
    w[7] = (input[offset + 23u] >> 8) | (input[offset + 22u] << 24);
    w[8] = (input[offset + 23u] << 24) | 0x800000;
    w[15] = 33 * 8; // 33 bytes = 33 * 8 bits
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
fn rol(x: u32, n: u32) -> u32 {
    return (x << n) | (x >> (32u - n));
}

fn f(j: u32, x: u32, y: u32, z: u32) -> u32 {
    if (j < 16u) {
        return x ^ y ^ z;
    } else if (j < 32u) {
        return (x & y) | ((~x) & z);
    } else if (j < 48u) {
        return (x | (~y)) ^ z;
    } else if (j < 64u) {
        return (x & z) | (y & (~z));
    } else {
        return x ^ (y | (~z));
    }
}

const K: array<u32,5> = array<u32,5>(
    0u,
    0x5A827999u,
    0x6ED9EBA1u,
    0x8F1BBCDCu,
    0xA953FD4Eu
);

const KK: array<u32,5> = array<u32,5>(
    0x50A28BE6u,
    0x5C4DD124u,
    0x6D703EF3u,
    0x7A6D76E9u,
    0x00000000u 
);

const r: array<u32,80> = array<u32,80>(
    0u,1u,2u,3u,4u,5u,6u,7u,8u,9u,10u,11u,12u,13u,14u,15u,
    7u,4u,13u,1u,10u,6u,15u,3u,12u,0u,9u,5u,2u,14u,11u,8u,
    3u,10u,14u,4u,9u,15u,8u,1u,2u,7u,0u,6u,13u,11u,5u,12u,
    1u,9u,11u,10u,0u,8u,12u,4u,13u,3u,7u,15u,14u,5u,6u,2u,
    4u,0u,5u,9u,7u,12u,2u,10u,14u,1u,3u,8u,11u,6u,15u,13u
);

const rr: array<u32,80> = array<u32,80>(
    5u,14u,7u,0u,9u,2u,11u,4u,13u,6u,15u,8u,1u,10u,3u,12u,
    6u,11u,3u,7u,0u,13u,5u,10u,14u,15u,8u,12u,4u,9u,1u,2u,
    15u,5u,1u,3u,7u,14u,6u,9u,11u,8u,12u,2u,10u,0u,4u,13u,
    8u,6u,4u,1u,3u,11u,15u,0u,5u,12u,2u,13u,9u,7u,10u,14u,
    12u,15u,10u,4u,1u,5u,8u,7u,6u,2u,13u,14u,0u,3u,9u,11u
);

const s: array<u32,80> = array<u32,80>(
    11u,14u,15u,12u,5u,8u,7u,9u,11u,13u,14u,15u,6u,7u,9u,8u,
    7u,6u,8u,13u,11u,9u,7u,15u,7u,12u,15u,9u,11u,7u,13u,12u,
    11u,13u,6u,7u,14u,9u,13u,15u,14u,8u,13u,6u,5u,12u,7u,5u,
    11u,12u,14u,15u,14u,15u,9u,8u,9u,14u,5u,6u,8u,6u,5u,12u,
    9u,15u,5u,11u,6u,8u,13u,12u,5u,12u,13u,14u,11u,8u,5u,6u
);

const ss: array<u32,80> = array<u32,80>(
    8u,9u,9u,11u,13u,15u,15u,5u,7u,7u,8u,11u,14u,14u,12u,6u,
    9u,13u,15u,7u,12u,8u,9u,11u,7u,7u,12u,7u,6u,15u,13u,11u,
    9u,7u,15u,11u,8u,6u,6u,14u,12u,13u,5u,14u,13u,13u,7u,5u,
    15u,5u,8u,11u,14u,14u,6u,14u,6u,9u,12u,9u,12u,5u,15u,8u,
    8u,5u,12u,9u,12u,5u,14u,6u,8u,13u,6u,5u,15u,13u,11u,11u
);

fn ripemd160(inp: ptr<function, array<u32, 8>>) {
    var len: u32 = 32;
    var m: array<u32,16>;
    for (var i: u32 = 0u; i < 16u; i = i + 1u) { m[i] = 0u; }
    for (var i: u32 = 0u; i < 8u; i = i + 1u) {
      var a: u32 = inp[i] & 0xFF;
      var b: u32 = ((inp[i] >> 8) & 0xFF);
      var c: u32 = ((inp[i] >> 16) & 0xFF);
      var d: u32 = ((inp[i] >> 24) & 0xFF);
      m[i] = (a << 24) | (b << 16) | (c << 8) | d;
    }
    m[8] = 0x80;

    let bitlen: u32 = len * 8u;
    m[14] = bitlen;
    m[15] = 0u;

    var h0: u32 = 0x67452301u;
    var h1: u32 = 0xEFCDAB89u;
    var h2: u32 = 0x98BADCFEu;
    var h3: u32 = 0x10325476u;
    var h4: u32 = 0xC3D2E1F0u;

    var A1: u32 = h0;
    var B1: u32 = h1;
    var C1: u32 = h2;
    var D1: u32 = h3;
    var E1: u32 = h4;

    var A2: u32 = h0;
    var B2: u32 = h1;
    var C2: u32 = h2;
    var D2: u32 = h3;
    var E2: u32 = h4;

    for (var j: u32 = 0u; j < 80u; j = j + 1u) {
        let t1: u32 = rol(A1 + f(j, B1, C1, D1) + m[r[j]] + K[ (j / 16u) ], s[j]) + E1;
        A1 = E1; E1 = D1; D1 = rol(C1, 10u); C1 = B1; B1 = t1;
        let t2: u32 = rol(A2 + f(79u - j, B2, C2, D2) + m[rr[j]] + KK[ (j / 16u) ], ss[j]) + E2;
        A2 = E2; E2 = D2; D2 = rol(C2, 10u); C2 = B2; B2 = t2;
    }

    let T: u32 = h1 + C1 + D2;
    h1 = h2 + D1 + E2;
    h2 = h3 + E1 + A2;
    h3 = h4 + A1 + B2;
    h4 = h0 + B1 + C2;
    h0 = T;

    inp[0] = h0;
    inp[1] = h1;
    inp[2] = h2;
    inp[3] = h3;
    inp[4] = h4;
}

const CHECK = array<array<u32, 5>, CHECK_COUNT>(
    CHECK_HASHES
);

@compute @workgroup_size(WORKGROUP_SIZE)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
    if (gid.x == 0) {
        output[0] = 0xffffffffu;
    }
    var out: array<u32, 8>;
    sha256(&out, gid.x * 32u);
    ripemd160(&out);
    var found: u32 = 0;
    for (var i = 0; i < CHECK_COUNT; i++) {
        if (out[0] == CHECK[i][0] &&
            out[1] == CHECK[i][1] &&
            out[2] == CHECK[i][2] &&
            out[3] == CHECK[i][3] &&
            out[4] == CHECK[i][4]) {
            output[0] = gid.x;
        }
    }

    
}
