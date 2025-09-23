
struct u64 { hi: u32, lo: u32 };

// not full formula, relying on a*d + b*c not overflowing
// which is true for 26x10 limbs specific calculations in secp256k1
// add select(0u, 0x10000u, adbc < a*d) to hi limb for corret results in general
fn mul64(x: u32, y: u32) -> u64 {
    let a = x >> 16;
    let b = (x & 0xFFFF);
    let c = y >> 16;
    let d = (y & 0xFFFF);
    let adbc = a*d + b*c;
    let adbcLo = adbc << 16;
    let lo = b*d + adbcLo;
    let hi = a*c + (adbc >> 16) + select(0u, 1u, lo < adbcLo);
    return u64(hi, lo);
}
fn add64(a: u64, b: u64) -> u64 {
  let lo = a.lo + b.lo;
  let carry = select(0u, 1u, lo < a.lo);
  let hi = a.hi + b.hi + carry;
  return u64(hi, lo);
}

fn muladd64(r: u64, x: u32, y: u32) -> u64 {
    let a = x >> 16;
    let b = (x & 0xFFFF);
    let c = y >> 16;
    let d = (y & 0xFFFF);
    let adbc = a*d + b*c;
    let lo1 = b*d + r.lo;
    let lo = (adbc << 16) + lo1;
    let hi = r.hi + a*c + (adbc >> 16) + select(0u, 1u, lo1 < r.lo) + select(0u, 1u, lo < lo1);
    return u64(hi, lo);
}

fn mul64_c(p: u64, cc: u32) -> u64 {
  var r = mul64(p.lo, cc);
  let b = (p.hi & 0xFFFF);
  let d = (cc & 0xFFFF);
  let adbcLo = ((p.hi >> 16) * d + b * (cc >> 16)) << 16;
  r.hi += b*d + adbcLo;
  return r;
}

fn shr64_26(r: u64) -> u64 {
  return u64(r.hi >> 26, ((r.lo >> 26) | ((r.hi << 6) & 0xffffffc0)));
}
fn shr64_25(r: u64) -> u64 {
  return u64(r.hi >> 25, ((r.lo >> 25) | ((r.hi << 7) & 0xffffff80)));
}

fn mmul(a: ptr<function, array<u32, 10>>, b: ptr<function, array<u32, 10>>) {
    var r: array<u32, 10>;
    var s: array<u32, 10>;
    for(var i: u32 = 0u; i < 10u; i++) {
        r[i] = b[i];
        s[i] = a[i];
    }
    var m: array<u64, 10>;
    m[1] = mul64(r[0], s[1]);
    m[1] = muladd64(m[1], r[1], s[0]);
    m[3] = mul64(r[0], s[3]);
    m[3] = muladd64(m[3], r[1], s[2]);
    m[3] = muladd64(m[3], r[2], s[1]);
    m[3] = muladd64(m[3], r[3], s[0]);
    m[5] = mul64(r[0], s[5]);
    m[5] = muladd64(m[5], r[1], s[4]);
    m[5] = muladd64(m[5], r[2], s[3]);
    m[5] = muladd64(m[5], r[3], s[2]);
    m[5] = muladd64(m[5], r[4], s[1]);
    m[5] = muladd64(m[5], r[5], s[0]);
    m[7] = mul64(r[0], s[7]);
    m[7] = muladd64(m[7], r[1], s[6]);
    m[7] = muladd64(m[7], r[2], s[5]);
    m[7] = muladd64(m[7], r[3], s[4]);
    m[7] = muladd64(m[7], r[4], s[3]);
    m[7] = muladd64(m[7], r[5], s[2]);
    m[7] = muladd64(m[7], r[6], s[1]);
    m[7] = muladd64(m[7], r[7], s[0]);
    m[9] = mul64(r[0], s[9]);
    m[9] = muladd64(m[9], r[1], s[8]);
    m[9] = muladd64(m[9], r[2], s[7]);
    m[9] = muladd64(m[9], r[3], s[6]);
    m[9] = muladd64(m[9], r[4], s[5]);
    m[9] = muladd64(m[9], r[5], s[4]);
    m[9] = muladd64(m[9], r[6], s[3]);
    m[9] = muladd64(m[9], r[7], s[2]);
    m[9] = muladd64(m[9], r[8], s[1]);
    m[9] = muladd64(m[9], r[9], s[0]);
    r[1] = r[1] * 2u;
    r[3] = r[3] * 2u;
    r[5] = r[5] * 2u;
    r[7] = r[7] * 2u;
    m[0] = mul64(r[0], s[0]);
    m[2] = mul64(r[0], s[2]);
    m[2] = muladd64(m[2], r[1], s[1]);
    m[2] = muladd64(m[2], r[2], s[0]);

    m[4] = mul64(r[0], s[4]);
    m[4] = muladd64(m[4], r[1], s[3]);
    m[4] = muladd64(m[4], r[2], s[2]);
    m[4] = muladd64(m[4], r[3], s[1]);
    m[4] = muladd64(m[4], r[4], s[0]);

    m[6] = mul64(r[0], s[6]);
    m[6] = muladd64(m[6], r[1], s[5]);
    m[6] = muladd64(m[6], r[2], s[4]);
    m[6] = muladd64(m[6], r[3], s[3]);
    m[6] = muladd64(m[6], r[4], s[2]);
    m[6] = muladd64(m[6], r[5], s[1]);
    m[6] = muladd64(m[6], r[6], s[0]);

    m[8] = mul64(r[0], s[8]);
    m[8] = muladd64(m[8], r[1], s[7]);
    m[8] = muladd64(m[8], r[2], s[6]);
    m[8] = muladd64(m[8], r[3], s[5]);
    m[8] = muladd64(m[8], r[4], s[4]);
    m[8] = muladd64(m[8], r[5], s[3]);
    m[8] = muladd64(m[8], r[6], s[2]);
    m[8] = muladd64(m[8], r[7], s[1]);
    m[8] = muladd64(m[8], r[8], s[0]);
    r[1] = r[1] * 19u;
    r[2] = r[2] * 19u;
    r[3] = (r[3] / 2u) * 19u;
    r[4] = r[4] * 19u;
    r[5] = (r[5] / 2u) * 19u;
    r[6] = r[6] * 19u;
    r[7] = (r[7] / 2u) * 19u;
    r[8] = r[8] * 19u;
    r[9] = r[9] * 19u;
    m[1] = add64(m[1], add64(mul64(r[9], s[2]), add64(mul64(r[8], s[3]), add64(mul64(r[7], s[4]), add64(mul64(r[6], s[5]), add64(mul64(r[5], s[6]), add64(mul64(r[4], s[7]), add64(mul64(r[3], s[8]), mul64(r[2], s[9])))))))));
    m[3] = add64(m[3], add64(mul64(r[9], s[4]), add64(mul64(r[8], s[5]), add64(mul64(r[7], s[6]), add64(mul64(r[6], s[7]), add64(mul64(r[5], s[8]), mul64(r[4], s[9])))))));
    m[5] = add64(m[5], add64(mul64(r[9], s[6]), add64(mul64(r[8], s[7]), add64(mul64(r[7], s[8]), mul64(r[6], s[9])))));
    m[7] = add64(m[7], add64(mul64(r[9], s[8]), mul64(r[8], s[9])));
    r[3] = r[3] * 2u;
    r[5] = r[5] * 2u;
    r[7] = r[7] * 2u;
    r[9] = r[9] * 2u;

    m[0] = add64(m[0], add64(mul64(r[9], s[1]), add64(mul64(r[8], s[2]), add64(mul64(r[7], s[3]), add64(mul64(r[6], s[4]), add64(mul64(r[5], s[5]), add64(mul64(r[4], s[6]), add64(mul64(r[3], s[7]), add64(mul64(r[2], s[8]), mul64(r[1], s[9]))))))))));
    m[2] = add64(m[2], add64(mul64(r[9], s[3]), add64(mul64(r[8], s[4]), add64(mul64(r[7], s[5]), add64(mul64(r[6], s[6]), add64(mul64(r[5], s[7]), add64(mul64(r[4], s[8]), mul64(r[3], s[9]))))))));
    m[4] = add64(m[4], add64(mul64(r[9], s[5]), add64(mul64(r[8], s[6]), add64(mul64(r[7], s[7]), add64(mul64(r[6], s[8]), mul64(r[5], s[9]))))));
    m[6] = add64(m[6], add64(mul64(r[9], s[7]), add64(mul64(r[8], s[8]), mul64(r[7], s[9]))));
    m[8] = add64(m[8], mul64(r[9], s[9]));
    var c: u64;
    var p: u32;

    var r_out: array<u32, 10>;

    r_out[0] = m[0].lo & 0x3ffffffu; c = shr64_26(m[0]);
    m[1] = add64(m[1], c); r_out[1] = m[1].lo & 0x1ffffffu; c = shr64_25(m[1]);
    m[2] = add64(m[2], c); r_out[2] = m[2].lo & 0x3ffffffu; c = shr64_26(m[2]);
    m[3] = add64(m[3], c); r_out[3] = m[3].lo & 0x1ffffffu; c = shr64_25(m[3]);
    m[4] = add64(m[4], c); r_out[4] = m[4].lo & 0x3ffffffu; c = shr64_26(m[4]);
    m[5] = add64(m[5], c); r_out[5] = m[5].lo & 0x1ffffffu; c = shr64_25(m[5]);
    m[6] = add64(m[6], c); r_out[6] = m[6].lo & 0x3ffffffu; c = shr64_26(m[6]);
    m[7] = add64(m[7], c); r_out[7] = m[7].lo & 0x1ffffffu; c = shr64_25(m[7]);
    m[8] = add64(m[8], c); r_out[8] = m[8].lo & 0x3ffffffu; c = shr64_26(m[8]);
    m[9] = add64(m[9], c);                        r_out[9] = m[9].lo & 0x1ffffffu; p = shr64_25(m[9]).lo;
    m[0] = add64(u64(0, r_out[0]), mul64(p, 19)); r_out[0] = m[0].lo & 0x3ffffffu; p = shr64_26(m[0]).lo;
    r_out[1] += p;

    for(var i: u32 = 0u; i < 10u; i++) {
        a[i] = r_out[i];
    }
}

fn copy(r: ptr<function, array<u32, 10>>, a: ptr<function, array<u32, 10>>) {
  r[0] = a[0];
  r[1] = a[1];
  r[2] = a[2];
  r[3] = a[3];
  r[4] = a[4];
  r[5] = a[5];
  r[6] = a[6];
  r[7] = a[7];
  r[8] = a[8];
  r[9] = a[9];
}


fn load26x10(inp: ptr<function, array<u32, 8>>, out: ptr<function, array<u32, 10>>) {
    out[0] = inp[0] & 0x3FFFFFFu;
    out[1] = (inp[0] >> 26) | ((inp[1] & 0x7FFFFu) << 6);
    out[2] = (inp[1] >> 19) | ((inp[2] & 0x1FFFu) << 13);
    out[3] = (inp[2] >> 13) | ((inp[3] & 0x3Fu) << 19);
    out[4] = (inp[3] >> 6) & 0x3FFFFFFu;
    out[5] = inp[4] & 0x1FFFFFFu;
    out[6] = (inp[4] >> 25) | ((inp[5] & 0x7FFFFu) << 7);
    out[7] = (inp[5] >> 19) | ((inp[6] & 0xFFFu) << 13);
    out[8] = (inp[6] >> 12) | ((inp[7] & 0x3Fu) << 20);
    out[9] = (inp[7] >> 6) & 0x1FFFFFFu;
}

fn store26x10(a: ptr<function, array<u32, 10>>, offset: u32) {
    output[offset + 7u] = (*a)[0] | ((*a)[1] << 26);
    output[offset + 6u] = ((*a)[1] >> 6) | ((*a)[2] << 19);
    output[offset + 5u] = ((*a)[2] >> 13) | ((*a)[3] << 13);
    output[offset + 4u] = ((*a)[3] >> 19) | ((*a)[4] << 6);
    output[offset + 3u] = (*a)[5] | ((*a)[6] << 25);
    output[offset + 2u] = ((*a)[6] >> 7) | ((*a)[7] << 19);
    output[offset + 1u] = ((*a)[7] >> 13) | ((*a)[8] << 12);
    output[offset + 0u] = ((*a)[8] >> 20) | ((*a)[9] << 6);
}

@group(0) @binding(0) var<storage, read> input: array<u32>;
@group(0) @binding(1) var<storage, read_write> output: array<u32>;
@group(0) @binding(2) var<storage, read> prec_table: array<u32>;

@compute @workgroup_size(WORKGROUP_SIZE)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
  var p: array<u32, 8>;
  for (var i = 0u; i < 8u; i++) {
    p[i] = input[gid.x*16 + 7-i];
  }
  var p2: array<u32, 8>;
  for (var i = 0u; i < 8u; i++) {
    p2[i] = input[gid.x*16+15-i];
  }
  var p10: array<u32, 10>;
  var p10_2: array<u32, 10>;
  load26x10(&p, &p10);
  load26x10(&p2, &p10_2);
  mmul(&p10, &p10_2);
  store26x10(&p10, gid.x*8);
}
