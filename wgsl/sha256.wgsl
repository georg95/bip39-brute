const K: array<u32,64> = array<u32,64>(
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
fn r(x: u32, n: u32) -> u32 { return (x >> n) | shw(x, 32u - n); }
fn g0(x: u32) -> u32 { return r(x, 7u) ^ r(x, 18u) ^ (x >> 3u); }
fn g1(x: u32) -> u32 { return r(x, 17u) ^ r(x, 19u) ^ (x >> 10u); }
fn s0(x: u32) -> u32 { return r(x, 2u) ^ r(x, 13u) ^ r(x, 22u); }
fn s1(x: u32) -> u32 { return r(x, 6u) ^ r(x, 11u) ^ r(x, 25u); }
fn maj(a: u32, b: u32, c: u32) -> u32 { return (a & b) ^ (a & c) ^ (b & c); }
fn ch(e: u32, f: u32, g: u32) -> u32 { return (e & f) ^ ((~e) & g); }

@group(0) @binding(0) var<storage, read> input: array<u32>;
@group(0) @binding(1) var<storage, read_write> output: array<u32>;

@compute @workgroup_size(1)
fn sha256() {
    var w = array<u32,64>();
    for (var i = 0u; i < 16u; i++){
        w[i] = input[i]; // padded with 0x80 and 2 bytes of bit length block
    }
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
        let t1 = h + s1(e) + ch(e, f, g) + K[i] + w[i];
        h = g;
        g = f;
        f = e;
        e = d + t1;
        d = c;
        c = b;
        b = a;
        a = t1 + t2;
    }
    output[0] = a+0x6a09e667u;
    output[1] = b+0xbb67ae85u;
    output[2] = c+0x3c6ef372u;
    output[3] = d+0xa54ff53au;
    output[4] = e+0x510e527fu;
    output[5] = f+0x9b05688cu;
    output[6] = g+0x1f83d9abu;
    output[7] = h+0x5be0cd19u;
}