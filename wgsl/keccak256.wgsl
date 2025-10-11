fn rotl64(v: vec2<u32>, n: u32) -> vec2<u32> {
    if (n == 0u) { return v; }
    if (n < 32u) {
        let lo = (v.x << n) | (v.y >> (32u - n));
        let hi = (v.y << n) | (v.x >> (32u - n));
        return vec2<u32>(lo, hi);
    } else if (n == 32u) { return vec2<u32>(v.y, v.x); } else {
        let m = n - 32u;
        let lo = (v.y << m) | (v.x >> (32u - m));
        let hi = (v.x << m) | (v.y >> (32u - m));
        return vec2<u32>(lo, hi);
    }
}
const PI = array<u32, 24>(10, 7, 11, 17, 18, 3, 5, 16, 8, 21, 24, 4, 15, 23, 19, 13, 12, 2, 20, 14, 22, 9, 6, 1);
const RC = array<u32, 48>(
    1,          0,          32898,      0,          32906,      2147483648, 2147516416, 2147483648, 32907,      0,          2147483649,
    0,          2147516545, 2147483648, 32777,      2147483648, 138,        0,          136,        0,          2147516425, 0,
    2147483658, 0,          2147516555, 0,          139,        2147483648, 32905,      2147483648, 32771,      2147483648, 32770,
    2147483648, 128,        2147483648, 32778,      0,          2147483658, 2147483648, 2147516545, 2147483648, 32896,      2147483648,
    2147483649, 0,          2147516424, 2147483648,
);
fn Chi(a: vec2<u32>, b: vec2<u32>, c: vec2<u32>) -> vec2<u32> {
    return vec2<u32>(a.x ^ (~b.x & c.x), a.y ^ (~b.y & c.y));
}
fn Theta(a: vec2<u32>, b: vec2<u32>, c: vec2<u32>) -> vec2<u32> {
    let R = rotl64(c, 1);
    return vec2<u32>(a.x ^ b.x ^ R.x, a.y ^ b.y ^ R.y);
}
fn Xor(a: vec2<u32>, b: vec2<u32>) -> vec2<u32> {
    return vec2<u32>(a.x ^ b.x, a.y ^ b.y);
}

fn keccak_f(st: ptr<function, array<vec2<u32>,25>>) {
    var t: array<vec2<u32>,5>;
    for (var j: u32 = 0; j < 24; j++) {
        for (var i = 0; i < 5; i++) { t[i] = vec2<u32>(0, 0); }
        for (var i = 0; i < 25; i++) { t[i % 5] = Xor(t[i % 5], st[i]); }
        for (var i = 0; i < 25; i++) { st[i] = Theta(st[i], t[(i + 4) % 5], t[(i + 1) % 5]); }
        var last = st[1];
        var rotc: u32 = 0;
        for (var i = 0u; i < 24; i++) {
            let x = PI[i];
            let tmp = st[x];
            rotc = (rotc + i + 1u) % 64u;
            st[x] = rotl64(last, rotc);
            last = tmp;
        }
        for (var i = 0; i < 5; i++) {
            for (var f = 0; f < 5; f++) { t[f] = st[i * 5 + f]; }
            for (var q = 0; q < 5; q++) { st[i * 5 + q] = Chi(t[q], t[(q + 1) % 5], t[(q + 2) % 5]); }
        }
        st[0].x ^= RC[j * 2];
        st[0].y ^= RC[j * 2 + 1];
    }
}

fn swap_bytes_u32(value: u32) -> u32 {
    return ((value & 0x000000FFu) << 24u) |
           ((value & 0x0000FF00u) << 8u)  |
           ((value & 0x00FF0000u) >> 8u)  |
           ((value & 0xFF000000u) >> 24u);
}

const CHECK = array<array<u32, 5>, CHECK_COUNT>(
    CHECK_HASHES
);

@group(0) @binding(0) var<storage, read> input: array<u32>;
@group(0) @binding(1) var<storage, read_write> output: array<u32>;

@compute @workgroup_size(WORKGROUP_SIZE)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
    if (gid.x == 0) {
        output[0] = 0xffffffffu;
    }
    var state: array<vec2<u32>,25>;
    for (var i = 0u; i < 25; i++) { state[i] = vec2<u32>(0u, 0u); }
    for (var i = 0u; i < 8; i++) {
        state[i] = vec2<u32>(
            swap_bytes_u32(input[gid.x*16u + i*2u]),
            swap_bytes_u32(input[gid.x*16u + i*2u + 1u]));
    }
    state[8].x = 0x01;
    state[16].y = 0x80000000;
    keccak_f(&state);

    var found: u32 = 0;
    for (var i = 0; i < CHECK_COUNT; i++) {
        if (state[1].y == CHECK[i][0] &&
            state[2].x == CHECK[i][1] &&
            state[2].y == CHECK[i][2] &&
            state[3].x == CHECK[i][3] &&
            state[3].y == CHECK[i][4]) {
            output[0] = gid.x;
        }
    }
}