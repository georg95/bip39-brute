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

fn store26x10(a: ptr<function, array<u32, 10>>, index: u32) {
    output[index+7] = a[0] | (a[1] << 26);
    output[index+6] = (a[1] >> 6) | (a[2] << 20);
    output[index+5] = (a[2] >> 12) | (a[3] << 14);
    output[index+4] = (a[3] >> 18) | (a[4] << 8);
    output[index+3] = (a[4] >> 24) | (a[5] << 2) | (a[6] << 28);
    output[index+2] = (a[6] >> 4) | (a[7] << 22);
    output[index+1] = (a[7] >> 10) | (a[8] << 16);
    output[index] = (a[8] >> 16) | (a[9] << 10);
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

fn mmul2(r: ptr<function, array<u32, 10>>, a: ptr<function, array<u32, 10>>, b: ptr<function, array<u32, 10>>) {
  copy(r, a);
  mmul(r, b);
}

fn mmul(a: ptr<function, array<u32, 10>>, b: ptr<function, array<u32, 10>>) {
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

  a[3] = t3;
  a[4] = t4;
  a[5] = t5;
  a[6] = t6;
  a[7] = t7;
  a[8] = c.lo & MASK;
  
  c = shr64_26(c); c = muladd64(c, u8, R1);
  c = add64(u64(0, t9), add64(c, mul64_c(d, R0)));

  a[9] = c.lo & (MASK >> 4);
  c = shr64_22(c); c = add64(c, mul64_c(d, R1 << 4));
  d = add64(mul64_c(c, R0 >> 4), u64(0, t0));

  a[0] = d.lo & MASK;
  d = shr64_26(d);
  
  d = add64(d, add64(mul64_c(c, R1 >> 4), u64(0, t1 )));
  
  a[1] = d.lo & MASK;
  d = shr64_26(d);
  d = add64(d, u64(0, t2));
  
  a[2] = d.lo;
}


fn msqr(r: ptr<function, array<u32, 10>>, a: ptr<function, array<u32, 10>>) {
  // TODO port faster version
  mmul2(r, a, a);
}
fn msqr2(r: ptr<function, array<u32, 10>>) {
  // TODO port faster version
  var a: array<u32, 10>;
  copy(&a, r);
  mmul2(r, &a, &a);
}

fn madd(r: ptr<function, array<u32, 10>>, a: ptr<function, array<u32, 10>>) {
  r[0] += a[0];
  r[1] += a[1];
  r[2] += a[2];
  r[3] += a[3];
  r[4] += a[4];
  r[5] += a[5];
  r[6] += a[6];
  r[7] += a[7];
  r[8] += a[8];
  r[9] += a[9];
}

fn mmulint(r: ptr<function, array<u32, 10>>, a: u32) {
  r[0] *= a;
  r[1] *= a;
  r[2] *= a;
  r[3] *= a;
  r[4] *= a;
  r[5] *= a;
  r[6] *= a;
  r[7] *= a;
  r[8] *= a;
  r[9] *= a;
}
fn mhalf(r: ptr<function, array<u32, 10>>) {
    var t0 = r[0];
    var t1 = r[1];
    var t2 = r[2];
    var t3 = r[3];
    var t4 = r[4];
    var t5 = r[5];
    var t6 = r[6];
    var t7 = r[7];
    var t8 = r[8];
    var t9 = r[9];
    var mask = (0-(t0 & 1)) >> 6;

    t0 += 0x3FFFC2F & mask;
    t1 += 0x3FFFFBF & mask;
    t2 += mask;
    t3 += mask;
    t4 += mask;
    t5 += mask;
    t6 += mask;
    t7 += mask;
    t8 += mask;
    t9 += mask >> 4;

    r[0] = (t0 >> 1) + ((t1 & 1) << 25);
    r[1] = (t1 >> 1) + ((t2 & 1) << 25);
    r[2] = (t2 >> 1) + ((t3 & 1) << 25);
    r[3] = (t3 >> 1) + ((t4 & 1) << 25);
    r[4] = (t4 >> 1) + ((t5 & 1) << 25);
    r[5] = (t5 >> 1) + ((t6 & 1) << 25);
    r[6] = (t6 >> 1) + ((t7 & 1) << 25);
    r[7] = (t7 >> 1) + ((t8 & 1) << 25);
    r[8] = (t8 >> 1) + ((t9 & 1) << 25);
    r[9] = (t9 >> 1);
}
fn mnegate(r: ptr<function, array<u32, 10>>, a: ptr<function, array<u32, 10>>, m: u32) {
  r[0] = 0x3FFFC2F * 2 * (m + 1) - a[0];
  r[1] = 0x3FFFFBF * 2 * (m + 1) - a[1];
  r[2] = 0x3FFFFFF * 2 * (m + 1) - a[2];
  r[3] = 0x3FFFFFF * 2 * (m + 1) - a[3];
  r[4] = 0x3FFFFFF * 2 * (m + 1) - a[4];
  r[5] = 0x3FFFFFF * 2 * (m + 1) - a[5];
  r[6] = 0x3FFFFFF * 2 * (m + 1) - a[6];
  r[7] = 0x3FFFFFF * 2 * (m + 1) - a[7];
  r[8] = 0x3FFFFFF * 2 * (m + 1) - a[8];
  r[9] = 0x03FFFFF * 2 * (m + 1) - a[9];
}
fn mnegate2(r: ptr<function, array<u32, 10>>, m: u32) {
  r[0] = 0x3FFFC2F * 2 * (m + 1) - r[0];
  r[1] = 0x3FFFFBF * 2 * (m + 1) - r[1];
  r[2] = 0x3FFFFFF * 2 * (m + 1) - r[2];
  r[3] = 0x3FFFFFF * 2 * (m + 1) - r[3];
  r[4] = 0x3FFFFFF * 2 * (m + 1) - r[4];
  r[5] = 0x3FFFFFF * 2 * (m + 1) - r[5];
  r[6] = 0x3FFFFFF * 2 * (m + 1) - r[6];
  r[7] = 0x3FFFFFF * 2 * (m + 1) - r[7];
  r[8] = 0x3FFFFFF * 2 * (m + 1) - r[8];
  r[9] = 0x03FFFFF * 2 * (m + 1) - r[9];
}

fn mnormtozero(r: ptr<function, array<u32, 10>>) -> bool {
  var t0 = r[0];
  var t1 = r[1];
  var t2 = r[2];
  var t3 = r[3];
  var t4 = r[4];
  var t5 = r[5];
  var t6 = r[6];
  var t7 = r[7];
  var t8 = r[8];
  var t9 = r[9];
  var z0: u32 = 0;
  var z1: u32 = 0;
  var x = t9 >> 22; t9 &= 0x03FFFFF;
  t0 += x * 0x3D1; t1 += (x << 6);
  t1 += (t0 >> 26); t0 &= 0x3FFFFFF; z0  = t0; z1  = t0 ^ 0x3D0;
  t2 += (t1 >> 26); t1 &= 0x3FFFFFF; z0 |= t1; z1 &= t1 ^ 0x40;
  t3 += (t2 >> 26); t2 &= 0x3FFFFFF; z0 |= t2; z1 &= t2;
  t4 += (t3 >> 26); t3 &= 0x3FFFFFF; z0 |= t3; z1 &= t3;
  t5 += (t4 >> 26); t4 &= 0x3FFFFFF; z0 |= t4; z1 &= t4;
  t6 += (t5 >> 26); t5 &= 0x3FFFFFF; z0 |= t5; z1 &= t5;
  t7 += (t6 >> 26); t6 &= 0x3FFFFFF; z0 |= t6; z1 &= t6;
  t8 += (t7 >> 26); t7 &= 0x3FFFFFF; z0 |= t7; z1 &= t7;
  t9 += (t8 >> 26); t8 &= 0x3FFFFFF; z0 |= t8; z1 &= t8;
                                     z0 |= t9; z1 &= t9 ^ 0x3C00000;
  return (z0 == 0) || (z1 == 0x3FFFFFF);
}

struct normalPoint {
  x: array<u32, 10>,
  y: array<u32, 10>,
  z: array<u32, 10>,
  infinity: bool
};
struct affinePoint {
  x: array<u32, 10>,
  y: array<u32, 10>,
};

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
fn set1(r: ptr<function, array<u32, 10>>) {
  r[0] = 1; r[1] = 0; r[2] = 0; r[3] = 0; r[4] = 0; r[5] = 0; r[6] = 0; r[7] = 0; r[8] = 0; r[9] = 0;
}
fn set0pt(p: ptr<function, normalPoint>) {
  set0(&p.x);
  set0(&p.y);
  set0(&p.z);
  p.infinity = true;
}
fn set0(r: ptr<function, array<u32, 10>>) {
  r[0] = 0; r[1] = 0; r[2] = 0; r[3] = 0; r[4] = 0; r[5] = 0; r[6] = 0; r[7] = 0; r[8] = 0; r[9] = 0;
}

fn secp256k1_add(r: ptr<function, normalPoint>, a: ptr<function, normalPoint>, b: ptr<function, affinePoint>) {
    var zz: array<u32, 10>;
    var u1: array<u32, 10>;
    var u2: array<u32, 10>;
    var s1: array<u32, 10>;
    var s2: array<u32, 10>;
    var t: array<u32, 10>;
    var tt: array<u32, 10>;
    var m: array<u32, 10>;
    var n: array<u32, 10>;
    var q: array<u32, 10>;
    var rr: array<u32, 10>;
    var m_alt: array<u32, 10>;
    var rr_alt: array<u32, 10>;
    var tmp: array<u32, 10>;
    var degenerate: bool;

    msqr(&zz, &a.z);
    copy(&u1, &a.x);
    mmul2(&u2, &b.x, &zz);
    copy(&s1, &a.y);
    mmul2(&s2, &b.y, &zz);
    copy(&tmp, &s2);
    mmul2(&s2, &tmp, &a.z);
    copy(&t, &u1); madd(&t, &u2);
    copy(&m, &s1); madd(&m, &s2);
    msqr(&rr, &t);
    mnegate(&m_alt, &u2, 1);
    mmul2(&tt, &u1, &m_alt);
    madd(&rr, &tt);
    degenerate = mnormtozero(&m);
    copy(&rr_alt, &s1);
    mmulint(&rr_alt, 2);
    madd(&m_alt, &u1);
    if (!degenerate) { copy(&rr_alt, &rr); }
    if (!degenerate) { copy(&m_alt, &m); }
    msqr(&n, &m_alt);
    mnegate(&q, &t, 5);
    copy(&tmp, &q);
    mmul2(&q, &tmp, &n);
    copy(&tmp, &n);
    msqr(&n, &tmp);
    if (degenerate) { copy(&n, &m); }
    msqr(&t, &rr_alt);
    mmul2(&r.z, &a.z, &m_alt);
    madd(&t, &q);
    copy(&r.x, &t);
    mmulint(&t, 2);
    madd(&t, &q);
    copy(&tmp, &t);
    mmul2(&t, &tmp, &rr_alt);
    madd(&t, &n);
    mnegate(&r.y, &t, 6);
    mhalf(&r.y);
    if (a.infinity) {
      copy(&r.x, &b.x);
      copy(&r.y, &b.y);
      set1(&r.z);
    }
    r.infinity = mnormtozero(&r.z);
}
fn minv(r: ptr<function, array<u32, 10>>) {
    var x2: array<u32, 10>;
    var x3: array<u32, 10>;
    var x6: array<u32, 10>;
    var x9: array<u32, 10>;
    var x11: array<u32, 10>;
    var x22: array<u32, 10>;
    var x44: array<u32, 10>;
    var x88: array<u32, 10>;
    var x176: array<u32, 10>;
    var x220: array<u32, 10>;
    var x223: array<u32, 10>;
    var t1: array<u32, 10>;

    msqr(&x2, r);
    mmul(&x2, r);
    msqr(&x3, &x2);
    mmul(&x3, r);

    copy(&x6, &x3);
    for (var j=0; j<3; j++) { msqr2(&x6); }
    mmul(&x6, &x3);
    copy(&x9, &x6);
    for (var j=0; j<3; j++) { msqr2(&x9); }
    mmul(&x9, &x3);
    copy(&x11, &x9);
    for (var j=0; j<2; j++) { msqr2(&x11); }
    mmul(&x11, &x2);
    copy(&x22, &x11);
    for (var j=0; j<11; j++) { msqr2(&x22); }
    mmul(&x22, &x11);
    copy(&x44, &x22);
    for (var j=0; j<22; j++) { msqr2(&x44); }
    mmul(&x44, &x22);
    copy(&x88, &x44);
    for (var j=0; j<44; j++) { msqr2(&x88); }
    mmul(&x88, &x44);
    copy(&x176, &x88);
    for (var j=0; j<88; j++) { msqr2(&x176); }
    mmul(&x176, &x88);
    copy(&x220, &x176);
    for (var j=0; j<44; j++) { msqr2(&x220); }
    mmul(&x220, &x44);
    copy(&x223, &x220);
    for (var j=0; j<3; j++) { msqr2(&x223); }
    mmul(&x223, &x3);
    copy(&t1, &x223);
    for (var j=0; j<23; j++) { msqr2(&t1); }
    mmul(&t1, &x22);
    for (var j=0; j<5; j++) { msqr2(&t1); }
    mmul(&t1, r);
    for (var j=0; j<3; j++) { msqr2(&t1); }
    mmul(&t1, &x2);
    for (var j=0; j<2; j++) { msqr2(&t1); }
    mmul(r, &t1);
}

fn loadCompPt(p: ptr<function, affinePoint>, index: u32) {
  var tmp: array<u32, 8>;
  for (var i = 0u; i < 8; i++) {
    tmp[i] = prec_table[index*16 + i];
  }
  load26x10(&tmp, &p.x);
  for (var i = 0u; i < 8; i++) {
    tmp[i] = prec_table[index*16 + 8 + i];
  }
  load26x10(&tmp, &p.y);
}

fn toAffine(r: ptr<function, affinePoint>, a: ptr<function, normalPoint>) {
    var z2: array<u32, 10>;
    var z3: array<u32, 10>;
    minv(&a.z);
    msqr(&z2, &a.z);
    mmul2(&z3, &a.z, &z2);
    mmul2(&r.x, &a.x, &z2);
    mmul2(&r.y, &a.y, &z3);
}

@group(0) @binding(0) var<storage, read> input: array<u32>;
@group(0) @binding(1) var<storage, read_write> output: array<u32>;
@group(0) @binding(2) var<storage, read> prec_table: array<u32>;
@compute @workgroup_size(1)
fn main() {
  var G256x: array<u32, 8> = array<u32, 8>(0xeb9a9787, 0x92f76cc4, 0x59599680, 0x89bdde81, 0xbbd3788d, 0x74669716, 0xef5ba060, 0xdd3625fa);         
  var G256y: array<u32, 8> = array<u32, 8>(0xc644a573, 0x37f68d00, 0x28833959, 0x94146198, 0x045731ca, 0x61da2501, 0x520e30d4, 0x7a188fa3);
  var G256x10: array<u32, 10>; var G256y10: array<u32, 10>;
  load26x10(&G256x, &G256x10); load26x10(&G256y, &G256y10);
  var G256 = affinePoint(G256x10, G256y10);

  var p: normalPoint;
  var ptTmp: normalPoint;
  var ptA: affinePoint;
  set0pt(&p);
  set0pt(&ptTmp);

  // TODO derive private keys
  var privKey: array<u32, 8>;
  for (var i = 0; i < 8; i++) { privKey[i] = input[7-i]; }
  let mask: u32 = 0xffu;
  var carry: u32 = 0u;
  for (var w = 0u; w < 32; w++) { // 4x8
    let index: u32 = w / 4u;
    let part = w%4u;
    var wbits: i32 = i32(((privKey[index] >> (part * 8u)) & mask) + carry);
    if (wbits > 128) { wbits -= 256; carry = 1u; }
    else { carry = 0; }
    let off = w * 128u;
    if (wbits != 0) {
      let offP: u32 = off + u32(abs(wbits)) - 1;
      loadCompPt(&ptA, offP);
      if (wbits < 0) { mnegate2(&ptA.y, 0); }
      secp256k1_add(&ptTmp, &p, &ptA);
      p = ptTmp;
    }
  }
  if (carry > 0) {
    secp256k1_add(&ptTmp, &p, &G256);
    p = ptTmp;
  }
  toAffine(&ptA, &p);

  for (var i: u32 = 0; i < 16; i++) { output[i] = input[i]; }
  store26x10(&ptA.x, 16);
  store26x10(&ptA.y, 24);
}
