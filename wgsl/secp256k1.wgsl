fn load26x10(inp: ptr<function, array<u32, 8>>, out: ptr<function, array<u32, 10>>) {
    out[0] = inp[0] & 0x3FFFFFF;
    out[1] = (inp[0] >> 26) | ((inp[1] << 6) & 0x3FFFFFF);
    out[2] = (inp[1] >> 20) | ((inp[2] << 12) & 0x3FFFFFF);
    out[3] = (inp[2] >> 14) | ((inp[3] << 18) & 0x3FFFFFF);
    out[4] = (inp[3] >> 8) | ((inp[4] << 24) & 0x3FFFFFF);
    out[5] = (inp[4] >> 2) & 0x3FFFFFF;
    out[6] = (inp[4] >> 28) | ((inp[5] << 4) & 0x3FFFFFF);
    out[7] = (inp[5] >> 22) | ((inp[6] << 10) & 0x3FFFFFF);
    out[8] = (inp[6] >> 16) | ((inp[7] << 16) & 0x3FFFFFF);
    out[9] = inp[7] >> 10;
}

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
fn shr64_22(r: u64) -> u64 {
  return u64(r.hi >> 22, ((r.lo >> 22) | ((r.hi << 10) & 0xfffffc00)));
}

fn mmul(r: ptr<function, array<u32, 10>>, a: ptr<function, array<u32, 10>>, b: ptr<function, array<u32, 10>>) {
  let MASK = 0x3FFFFFFu;
  let R0 = 0x3D10u;
  let R1 = 0x400u;

  var d = mul64(a[0], b[9]);
  d = muladd64(d, a[1], b[8]);
  d = muladd64(d, a[2], b[7]);
  d = muladd64(d, a[3], b[6]);
  d = muladd64(d, a[4], b[5]);
  d = muladd64(d, a[5], b[4]);
  d = muladd64(d, a[6], b[3]);
  d = muladd64(d, a[7], b[2]);
  d = muladd64(d, a[8], b[1]);
  d = muladd64(d, a[9], b[0]);

  let t9 = d.lo & MASK; d = shr64_26(d);
  var c = mul64(a[0], b[0]);

  d = muladd64(d, a[1], b[9]);
  d = muladd64(d, a[2], b[8]);
  d = muladd64(d, a[3], b[7]);
  d = muladd64(d, a[4], b[6]);
  d = muladd64(d, a[5], b[5]);
  d = muladd64(d, a[6], b[4]);
  d = muladd64(d, a[7], b[3]);
  d = muladd64(d, a[8], b[2]);
  d = muladd64(d, a[9], b[1]);

  let u0 = d.lo & MASK; d = shr64_26(d); c = muladd64(c, u0, R0);
  let t0 = c.lo & MASK; c = shr64_26(c); c = muladd64(c, u0, R1);

  c = muladd64(c, a[0], b[1]);
  c = muladd64(c, a[1], b[0]);

  d = muladd64(d, a[2], b[9]);
  d = muladd64(d, a[3], b[8]);
  d = muladd64(d, a[4], b[7]);
  d = muladd64(d, a[5], b[6]);
  d = muladd64(d, a[6], b[5]);
  d = muladd64(d, a[7], b[4]);
  d = muladd64(d, a[8], b[3]);
  d = muladd64(d, a[9], b[2]);

  let u1 = d.lo & MASK; d = shr64_26(d); c = muladd64(c, u1, R0);
  let t1 = c.lo & MASK; c = shr64_26(c); c = muladd64(c, u1, R1);

  c = muladd64(c, a[0], b[2]);
  c = muladd64(c, a[1], b[1]);
  c = muladd64(c, a[2], b[0]);

  d = muladd64(d, a[3], b[9]);
  d = muladd64(d, a[4], b[8]);
  d = muladd64(d, a[5], b[7]);
  d = muladd64(d, a[6], b[6]);
  d = muladd64(d, a[7], b[5]);
  d = muladd64(d, a[8], b[4]);
  d = muladd64(d, a[9], b[3]);

  let u2 = d.lo & MASK; d = shr64_26(d); c = muladd64(c, u2, R0);
  let t2 = c.lo & MASK; c = shr64_26(c); c = muladd64(c, u2, R1);
  
  c = muladd64(c, a[0], b[3]);
  c = muladd64(c, a[1], b[2]);
  c = muladd64(c, a[2], b[1]);
  c = muladd64(c, a[3], b[0]);

  d = muladd64(d, a[4], b[9]);
  d = muladd64(d, a[5], b[8]);
  d = muladd64(d, a[6], b[7]);
  d = muladd64(d, a[7], b[6]);
  d = muladd64(d, a[8], b[5]);
  d = muladd64(d, a[9], b[4]);

  let u3 = d.lo & MASK; d = shr64_26(d); c = muladd64(c, u3, R0);
  let t3 = c.lo & MASK; c = shr64_26(c); c = muladd64(c, u3, R1);

  c = muladd64(c, a[0], b[4]);
  c = muladd64(c, a[1], b[3]);
  c = muladd64(c, a[2], b[2]);
  c = muladd64(c, a[3], b[1]);
  c = muladd64(c, a[4], b[0]);

  d = muladd64(d, a[5], b[9]);
  d = muladd64(d, a[6], b[8]);
  d = muladd64(d, a[7], b[7]);
  d = muladd64(d, a[8], b[6]);
  d = muladd64(d, a[9], b[5]);

  let u4 = d.lo & MASK; d = shr64_26(d); c = muladd64(c, u4, R0);
  let t4 = c.lo & MASK; c = shr64_26(c); c = muladd64(c, u4, R1);

  c = muladd64(c, a[0], b[5]);
  c = muladd64(c, a[1], b[4]);
  c = muladd64(c, a[2], b[3]);
  c = muladd64(c, a[3], b[2]);
  c = muladd64(c, a[4], b[1]);
  c = muladd64(c, a[5], b[0]);

  d = muladd64(d, a[6], b[9]);
  d = muladd64(d, a[7], b[8]);
  d = muladd64(d, a[8], b[7]);
  d = muladd64(d, a[9], b[6]);

  let u5 = d.lo & MASK; d = shr64_26(d); c = muladd64(c, u5, R0);
  let t5 = c.lo & MASK; c = shr64_26(c); c = muladd64(c, u5, R1);

  c = muladd64(c, a[0], b[6]);
  c = muladd64(c, a[1], b[5]);
  c = muladd64(c, a[2], b[4]);
  c = muladd64(c, a[3], b[3]);
  c = muladd64(c, a[4], b[2]);
  c = muladd64(c, a[5], b[1]);
  c = muladd64(c, a[6], b[0]);

  d = muladd64(d, a[7], b[9]);
  d = muladd64(d, a[8], b[8]);
  d = muladd64(d, a[9], b[7]);

  let u6 = d.lo & MASK; d = shr64_26(d); c = muladd64(c, u6, R0);
  let t6 = c.lo & MASK; c = shr64_26(c); c = muladd64(c, u6, R1);

  c = muladd64(c, a[0], b[7]);
  c = muladd64(c, a[1], b[6]);
  c = muladd64(c, a[2], b[5]);
  c = muladd64(c, a[3], b[4]);
  c = muladd64(c, a[4], b[3]);
  c = muladd64(c, a[5], b[2]);
  c = muladd64(c, a[6], b[1]);
  c = muladd64(c, a[7], b[0]);

  d = muladd64(d, a[8], b[9]);
  d = muladd64(d, a[9], b[8]);

  let u7 = d.lo & MASK; d = shr64_26(d); c = muladd64(c, u7, R0);
  let t7 = c.lo & MASK; c = shr64_26(c); c = muladd64(c, u7, R1);

  c = muladd64(c, a[0], b[8]);
  c = muladd64(c, a[1], b[7]);
  c = muladd64(c, a[2], b[6]);
  c = muladd64(c, a[3], b[5]);
  c = muladd64(c, a[4], b[4]);
  c = muladd64(c, a[5], b[3]);
  c = muladd64(c, a[6], b[2]);
  c = muladd64(c, a[7], b[1]);
  c = muladd64(c, a[8], b[0]);

  d = muladd64(d, a[9], b[9]);

  let u8 = d.lo & MASK; d = shr64_26(d); c = muladd64(c, u8, R0);

  r[3] = t3;
  r[4] = t4;
  r[5] = t5;
  r[6] = t6;
  r[7] = t7;
  r[8] = c.lo & MASK;
  
  c = shr64_26(c); c = muladd64(c, u8, R1);
  c = add64(u64(0, t9), add64(c, mul64_c(d, R0)));

  r[9] = c.lo & (MASK >> 4);
  c = shr64_22(c); c = add64(c, mul64_c(d, R1 << 4));
  d = add64(mul64_c(c, R0 >> 4), u64(0, t0));

  r[0] = d.lo & MASK;
  d = shr64_26(d);
  
  d = add64(d, add64(mul64_c(c, R1 >> 4), u64(0, t1 )));
  
  r[1] = d.lo & MASK;
  d = shr64_26(d);
  d = add64(d, u64(0, t2));
  
  r[2] = d.lo;
}

@group(0) @binding(0) var<storage, read> input: array<u32>;
@group(0) @binding(1) var<storage, read_write> output: array<u32>;
@compute @workgroup_size(1)
fn main() {
  var G256x: array<u32, 8> = array<u32, 8>(0xeb9a9787, 0x92f76cc4, 0x59599680, 0x89bdde81, 0xbbd3788d, 0x74669716, 0xef5ba060, 0xdd3625fa);
  var G256x10: array<u32, 10>;
  var G257x10: array<u32, 10>;
  load26x10(&G256x, &G256x10);
  mmul(&G257x10, &G256x10, &G256x10);

  for (var i: u32 = 0; i < 10; i++) {
    output[i] = G257x10[i];
  }
}
