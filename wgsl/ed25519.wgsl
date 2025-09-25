
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

fn mmul(r_out: ptr<function, array<u32, 10>>, a: ptr<function, array<u32, 10>>, b: ptr<function, array<u32, 10>>) {
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
}

struct normalPoint {
  X: array<u32, 10>,
  Y: array<u32, 10>,
  Z: array<u32, 10>,
  T: array<u32, 10>,
};
struct affinePoint {
  x: array<u32, 10>,
  y: array<u32, 10>,
  d2xy: array<u32, 10>,
};

fn ed25519_add(r: ptr<function, normalPoint>, p: ptr<function, normalPoint>, q: ptr<function, affinePoint>) {
  var A: array<u32, 10>;
  var B: array<u32, 10>;
  var C: array<u32, 10>;
  var D: array<u32, 10>;
  var E: array<u32, 10>;
  var F: array<u32, 10>;
  var G: array<u32, 10>;
  var H: array<u32, 10>;
  var tmp: array<u32, 10>;
  var tmp2: array<u32, 10>;

  msub(&tmp, &p.Y, &p.X);
  msub(&tmp2, &q.y, &q.x);
  mmul(&A, &tmp, &tmp2);
  madd(&tmp, &p.Y, &p.X);
  madd(&tmp2, &q.y, &q.x);
  mmul(&B, &tmp, &tmp2);
  mmul(&C, &p.T, &q.d2xy);
  madd(&D, &p.Z, &p.Z);
  msub(&E, &B, &A);
  msub(&F, &D, &C);
  madd(&G, &D, &C);
  madd(&H, &B, &A);
  mmul(&r.X, &E, &F);
  mmul(&r.Y, &G, &H);
  mmul(&r.T, &E, &H);
  mmul(&r.Z, &F, &G);
}

// void fe_invert(fe out, const fe z) {
//     fe t0;
//     fe t1;
//     fe t2;
//     fe t3;
//     int i;
//     fe_sq(t0, z);
//     for (i = 1; i < 1; ++i) { fe_sq(t0, t0); }
//     fe_sq(t1, t0);
//     for (i = 1; i < 2; ++i) { fe_sq(t1, t1); }
//     fe_mul(t1, z, t1);
//     fe_mul(t0, t0, t1);
//     fe_sq(t2, t0);
//     for (i = 1; i < 1; ++i) { fe_sq(t2, t2); }
//     fe_mul(t1, t1, t2);
//     fe_sq(t2, t1);
//     for (i = 1; i < 5; ++i) { fe_sq(t2, t2); }
//     fe_mul(t1, t2, t1);
//     fe_sq(t2, t1);
//     for (i = 1; i < 10; ++i) { fe_sq(t2, t2); }
//     fe_mul(t2, t2, t1);
//     fe_sq(t3, t2);
//     for (i = 1; i < 20; ++i) { fe_sq(t3, t3); }
//     fe_mul(t2, t3, t2);
//     fe_sq(t2, t2);
//     for (i = 1; i < 10; ++i) { fe_sq(t2, t2); }
//     fe_mul(t1, t2, t1);
//     fe_sq(t2, t1);
//     for (i = 1; i < 50; ++i) { fe_sq(t2, t2); }
//     fe_mul(t2, t2, t1);
//     fe_sq(t3, t2);
//     for (i = 1; i < 100; ++i) { fe_sq(t3, t3); }
//     fe_mul(t2, t3, t2);
//     fe_sq(t2, t2);
//     for (i = 1; i < 50; ++i) { fe_sq(t2, t2); }
//     fe_mul(t1, t2, t1);
//     fe_sq(t1, t1);
//     for (i = 1; i < 5; ++i) { fe_sq(t1, t1); }
//     fe_mul(out, t1, t0);
// }

const reduce_mask_25: u32 = (1 << 25) - 1;
const reduce_mask_26: u32 = (1 << 26) - 1;

fn madd(out: ptr<function, array<u32, 10>>, a: ptr<function, array<u32, 10>>, b: ptr<function, array<u32, 10>>) {
	var c: u32;
	out[0] = a[0] + b[0]    ; c = (out[0] >> 26); out[0] &= reduce_mask_26;
	out[1] = a[1] + b[1] + c; c = (out[1] >> 25); out[1] &= reduce_mask_25;
	out[2] = a[2] + b[2] + c; c = (out[2] >> 26); out[2] &= reduce_mask_26;
	out[3] = a[3] + b[3] + c; c = (out[3] >> 25); out[3] &= reduce_mask_25;
	out[4] = a[4] + b[4] + c; c = (out[4] >> 26); out[4] &= reduce_mask_26;
	out[5] = a[5] + b[5] + c; c = (out[5] >> 25); out[5] &= reduce_mask_25;
	out[6] = a[6] + b[6] + c; c = (out[6] >> 26); out[6] &= reduce_mask_26;
	out[7] = a[7] + b[7] + c; c = (out[7] >> 25); out[7] &= reduce_mask_25;
	out[8] = a[8] + b[8] + c; c = (out[8] >> 26); out[8] &= reduce_mask_26;
	out[9] = a[9] + b[9] + c; c = (out[9] >> 25); out[9] &= reduce_mask_25;
	out[0] += 19 * c;
}

fn msub(out: ptr<function, array<u32, 10>>, a: ptr<function, array<u32, 10>>, b: ptr<function, array<u32, 10>>) {
	var c: u32;
	out[0] = 0x0fffffb4 + a[0] - b[0]    ; c = (out[0] >> 26); out[0] &= reduce_mask_26;
	out[1] = 0x07fffffc + a[1] - b[1] + c; c = (out[1] >> 25); out[1] &= reduce_mask_25;
	out[2] = 0x0ffffffc + a[2] - b[2] + c; c = (out[2] >> 26); out[2] &= reduce_mask_26;
	out[3] = 0x07fffffc + a[3] - b[3] + c; c = (out[3] >> 25); out[3] &= reduce_mask_25;
	out[4] = 0x0ffffffc + a[4] - b[4] + c; c = (out[4] >> 26); out[4] &= reduce_mask_26;
	out[5] = 0x07fffffc + a[5] - b[5] + c; c = (out[5] >> 25); out[5] &= reduce_mask_25;
	out[6] = 0x0ffffffc + a[6] - b[6] + c; c = (out[6] >> 26); out[6] &= reduce_mask_26;
	out[7] = 0x07fffffc + a[7] - b[7] + c; c = (out[7] >> 25); out[7] &= reduce_mask_25;
	out[8] = 0x0ffffffc + a[8] - b[8] + c; c = (out[8] >> 26); out[8] &= reduce_mask_26;
	out[9] = 0x07fffffc + a[9] - b[9] + c; c = (out[9] >> 25); out[9] &= reduce_mask_25;
	out[0] += 19 * c;
}

fn madd_unsafe(out: ptr<function, array<u32, 10>>, a: ptr<function, array<u32, 10>>, b: ptr<function, array<u32, 10>>) {
	out[0] = a[0] + b[0];
	out[1] = a[1] + b[1];
	out[2] = a[2] + b[2];
	out[3] = a[3] + b[3];
	out[4] = a[4] + b[4];
	out[5] = a[5] + b[5];
	out[6] = a[6] + b[6];
	out[7] = a[7] + b[7];
	out[8] = a[8] + b[8];
	out[9] = a[9] + b[9];
}

fn msub_unsafe(out: ptr<function, array<u32, 10>>, a: ptr<function, array<u32, 10>>, b: ptr<function, array<u32, 10>>) {
	var c: u32;
	out[0] = 0x07ffffda + a[0] - b[0]    ; c = (out[0] >> 26); out[0] &= reduce_mask_26;
	out[1] = 0x03fffffe + a[1] - b[1] + c; c = (out[1] >> 25); out[1] &= reduce_mask_25;
	out[2] = 0x07fffffe + a[2] - b[2] + c; c = (out[2] >> 26); out[2] &= reduce_mask_26;
	out[3] = 0x03fffffe + a[3] - b[3] + c; c = (out[3] >> 25); out[3] &= reduce_mask_25;
	out[4] = 0x07fffffe + a[4] - b[4] + c;
	out[5] = 0x03fffffe + a[5] - b[5]    ;
	out[6] = 0x07fffffe + a[6] - b[6]    ;
	out[7] = 0x03fffffe + a[7] - b[7]    ;
	out[8] = 0x07fffffe + a[8] - b[8]    ;
	out[9] = 0x03fffffe + a[9] - b[9]    ;
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

fn loadCompPt(p: ptr<function, affinePoint>, index: u32) {
  var tmp: array<u32, 8>;
  for (var i = 0u; i < 8; i++) {
    tmp[i] = prec_table[index*24 + i];
  }
  load26x10(&tmp, &p.x);
  for (var i = 0u; i < 8; i++) {
    tmp[i] = prec_table[index*24 + 8 + i];
  }
  load26x10(&tmp, &p.y);
  for (var i = 0u; i < 8; i++) {
    tmp[i] = prec_table[index*24 + 16 + i];
  }
  load26x10(&tmp, &p.d2xy);
}

fn set0(r: ptr<function, array<u32, 10>>) {
  r[0] = 0; r[1] = 0; r[2] = 0; r[3] = 0; r[4] = 0; r[5] = 0; r[6] = 0; r[7] = 0; r[8] = 0; r[9] = 0;
}
fn set1(r: ptr<function, array<u32, 10>>) {
  r[0] = 1; r[1] = 0; r[2] = 0; r[3] = 0; r[4] = 0; r[5] = 0; r[6] = 0; r[7] = 0; r[8] = 0; r[9] = 0;
}
fn set0pt(p: ptr<function, normalPoint>) {
  set0(&p.X);
  set1(&p.Y);
  set1(&p.Z);
  set0(&p.T);
}

fn mnegate(r: ptr<function, array<u32, 10>>) {
	var c: u32;
	r[0] = 0x07ffffda - r[0]    ; c = (r[0] >> 26); r[0] &= reduce_mask_26;
	r[1] = 0x03fffffe - r[1] + c; c = (r[1] >> 25); r[1] &= reduce_mask_25;
	r[2] = 0x07fffffe - r[2] + c; c = (r[2] >> 26); r[2] &= reduce_mask_26;
	r[3] = 0x03fffffe - r[3] + c; c = (r[3] >> 25); r[3] &= reduce_mask_25;
	r[4] = 0x07fffffe - r[4] + c; c = (r[4] >> 26); r[4] &= reduce_mask_26;
	r[5] = 0x03fffffe - r[5] + c; c = (r[5] >> 25); r[5] &= reduce_mask_25;
	r[6] = 0x07fffffe - r[6] + c; c = (r[6] >> 26); r[6] &= reduce_mask_26;
	r[7] = 0x03fffffe - r[7] + c; c = (r[7] >> 25); r[7] &= reduce_mask_25;
	r[8] = 0x07fffffe - r[8] + c; c = (r[8] >> 26); r[8] &= reduce_mask_26;
	r[9] = 0x03fffffe - r[9] + c; c = (r[9] >> 25); r[9] &= reduce_mask_25;
	r[0] += 19 * c;
}

fn ed25519_mul(gidX: u32) -> normalPoint {
  var G256: affinePoint;
  var G256x: array<u32, 8> = array<u32, 8>(0x0cc2a556u, 0x20b8bcddu, 0xb561576du, 0xd4b578fbu, 0x26905449u, 0xe6e9cbc1u, 0x4e1decbfu, 0x5e7e07edu);  
  var G256y: array<u32, 8> = array<u32, 8>(0x566cf6c7u, 0x0e142031u, 0xc127d9a8u, 0x7d1b3d9au, 0x81d3260eu, 0x6bf5ebaau, 0x51f10279u, 0x0f55755cu);  
  var G256d2xy: array<u32, 8> = array<u32, 8>(0x2106e4c7u, 0x6c444417u, 0x928d7f69u, 0xfb53d680u, 0x694d3f26u, 0xb4739ea4u, 0x2e864bb0u, 0x10c69711u);
  load26x10(&G256x, &G256.x); load26x10(&G256y, &G256.y); load26x10(&G256d2xy, &G256.d2xy);

  var p: normalPoint;
  var ptTmp: normalPoint;
  var ptA: affinePoint;
  set0pt(&p);
  set0pt(&ptTmp);

  var privKey: array<u32, 8>;
  for (var i: u32 = 0; i < 8; i++) { privKey[i] = input[gidX * 16u + 7u - i]; }
  let mask: u32 = 0xffffu;
  var carry: u32 = 0u;
  for (var w = 0u; w < 16; w++) {
    let index: u32 = w / 2u;
    let part = w%2u;
    var wbits: i32 = i32(((privKey[index] >> (part * 16u)) & mask) + carry);
    if (wbits > 32768) { wbits -= 65536; carry = 1u; }
    else { carry = 0; }
    let off = w * 32768u;
    if (wbits != 0) {
      let offP: u32 = off + u32(abs(wbits)) - 1;
      loadCompPt(&ptA, offP);
      if (wbits < 0) { mnegate(&ptA.x); mnegate(&ptA.d2xy); }
      ed25519_add(&ptTmp, &p, &ptA);
      p = ptTmp;
    }
  }
  if (carry > 0) {
    ed25519_add(&ptTmp, &p, &G256);
    p = ptTmp;
  }

  return p;
}

@group(0) @binding(0) var<storage, read> input: array<u32>;
@group(0) @binding(1) var<storage, read_write> output: array<u32>;
@group(0) @binding(2) var<storage, read> prec_table: array<u32>;

@compute @workgroup_size(WORKGROUP_SIZE)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
  var p = ed25519_mul(gid.x);
  store26x10(&p.X, gid.x*32);
  store26x10(&p.Y, gid.x*32+8);
  store26x10(&p.Z, gid.x*32+16);
  store26x10(&p.T, gid.x*32+24);
}