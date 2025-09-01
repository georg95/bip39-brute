const K: array<u32,160> = array<u32,160>(
    0x428a2f98, 0xd728ae22, 0x71374491, 0x23ef65cd, 0xb5c0fbcf, 0xec4d3b2f, 0xe9b5dba5, 0x8189dbbc,
    0x3956c25b, 0xf348b538, 0x59f111f1, 0xb605d019, 0x923f82a4, 0xaf194f9b, 0xab1c5ed5, 0xda6d8118,
    0xd807aa98, 0xa3030242, 0x12835b01, 0x45706fbe, 0x243185be, 0x4ee4b28c, 0x550c7dc3, 0xd5ffb4e2,
    0x72be5d74, 0xf27b896f, 0x80deb1fe, 0x3b1696b1, 0x9bdc06a7, 0x25c71235, 0xc19bf174, 0xcf692694,
    0xe49b69c1, 0x9ef14ad2, 0xefbe4786, 0x384f25e3, 0xfc19dc6,  0x8b8cd5b5, 0x240ca1cc, 0x77ac9c65,
    0x2de92c6f, 0x592b0275, 0x4a7484aa, 0x6ea6e483, 0x5cb0a9dc, 0xbd41fbd4, 0x76f988da, 0x831153b5,
    0x983e5152, 0xee66dfab, 0xa831c66d, 0x2db43210, 0xb00327c8, 0x98fb213f, 0xbf597fc7, 0xbeef0ee4,
    0xc6e00bf3, 0x3da88fc2, 0xd5a79147, 0x930aa725, 0x6ca6351,  0xe003826f, 0x14292967, 0xa0e6e70,
    0x27b70a85, 0x46d22ffc, 0x2e1b2138, 0x5c26c926, 0x4d2c6dfc, 0x5ac42aed, 0x53380d13, 0x9d95b3df,
    0x650a7354, 0x8baf63de, 0x766a0abb, 0x3c77b2a8, 0x81c2c92e, 0x47edaee6, 0x92722c85, 0x1482353b,
    0xa2bfe8a1, 0x4cf10364, 0xa81a664b, 0xbc423001, 0xc24b8b70, 0xd0f89791, 0xc76c51a3, 0x654be30,
    0xd192e819, 0xd6ef5218, 0xd6990624, 0x5565a910, 0xf40e3585, 0x5771202a, 0x106aa070, 0x32bbd1b8,
    0x19a4c116, 0xb8d2d0c8, 0x1e376c08, 0x5141ab53, 0x2748774c, 0xdf8eeb99, 0x34b0bcb5, 0xe19b48a8,
    0x391c0cb3, 0xc5c95a63, 0x4ed8aa4a, 0xe3418acb, 0x5b9cca4f, 0x7763e373, 0x682e6ff3, 0xd6b2b8a3,
    0x748f82ee, 0x5defb2fc, 0x78a5636f, 0x43172f60, 0x84c87814, 0xa1f0ab72, 0x8cc70208, 0x1a6439ec,
    0x90befffa, 0x23631e28, 0xa4506ceb, 0xde82bde9, 0xbef9a3f7, 0xb2c67915, 0xc67178f2, 0xe372532b,
    0xca273ece, 0xea26619c, 0xd186b8c7, 0x21c0c207, 0xeada7dd6, 0xcde0eb1e, 0xf57d4f7f, 0xee6ed178,
    0x6f067aa,  0x72176fba, 0xa637dc5,  0xa2c898a6, 0x113f9804, 0xbef90dae, 0x1b710b35, 0x131c471b,
    0x28db77f5, 0x23047d84, 0x32caab7b, 0x40c72493, 0x3c9ebe0a, 0x15c9bebc, 0x431d67c4, 0x9c100d4c,
    0x4cc5d4be, 0xcb3e42b6, 0x597f299c, 0xfc657e2a, 0x5fcb6fab, 0x3ad6faec, 0x6c44198c, 0x4a475817);

// out - array<u32> ptr
fn sha512(inp: ptr<function, array<u32, 32>>, out: ptr<function, array<u32, 16>>, IV: ptr<function, array<u32, 16>>) {
  var W: array<u32, 160>;
  for (var i: u32 =  0u; i <  32u; i = i + 1u) { W[i] = inp[i]; }
  for (var i: u32 = 32u; i < 160u; i = i + 2u) {
      var xhi = W[i - 4];
      var xlo = W[i - 3];
      let t1_hi = ((xhi >> 19) | (xlo << 13)) ^ ((xlo >> 29) | (xhi << 3)) ^ (xhi >> 6);
      let t1_lo = ((xlo >> 19) | (xhi << 13)) ^ ((xhi >> 29) | (xlo << 3)) ^ ((xlo >> 6) | (xhi << 26));
      xhi = W[i - 30];
      xlo = W[i - 29];
      let t3_hi = ((xhi >> 1) | (xlo << 31)) ^ ((xhi >> 8) | (xlo << 24)) ^ (xhi >> 7);
      let t3_lo = ((xlo >> 1) | (xhi << 31)) ^ ((xlo >> 8) | (xhi << 24)) ^ ((xlo >> 7) | (xhi << 25));
      var acc_lo = W[i - 13] + W[i - 31];
      var acc_hi = W[i - 14] + W[i - 32] + select(0u, 1u, acc_lo < W[i - 13]);
      acc_lo = acc_lo + t1_lo;
      acc_hi = acc_hi + t1_hi + select(0u, 1u, acc_lo < t1_lo);
      acc_lo = acc_lo + t3_lo;
      acc_hi = acc_hi + t3_hi + select(0u, 1u, acc_lo < t3_lo);
      W[i] = acc_hi;
      W[i + 1] = acc_lo;
  }

  var ahi: u32 = IV[0];
  var alo: u32 = IV[1];
  var bhi: u32 = IV[2];
  var blo: u32 = IV[3];
  var chi: u32 = IV[4];
  var clo: u32 = IV[5];
  var dhi: u32 = IV[6];
  var dlo: u32 = IV[7];
  var ehi: u32 = IV[8];
  var elo: u32 = IV[9];
  var fhi: u32 = IV[10];
  var flo: u32 = IV[11];
  var ghi: u32 = IV[12];
  var glo: u32 = IV[13];
  var hhi: u32 = IV[14];
  var hlo: u32 = IV[15];

  for (var i: u32 = 0u; i < 160u; i = i + 2u) {
      var t1_lo = hlo + (((elo >> 14) | (ehi << 18)) ^ ((elo >> 18) | (ehi << 14)) ^ ((ehi >> 9) | (elo << 23)));
      var t1_hi = hhi + (((ehi >> 14) | (elo << 18)) ^ ((ehi >> 18) | (elo << 14)) ^ ((elo >> 9) | (ehi << 23))) + select(0u, 1u, t1_lo < hlo);
      var tmp = (elo & flo) ^ ((~elo) & glo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((ehi & fhi) ^ ((~ehi) & ghi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 1];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i] + select(0u, 1u, t1_lo < tmp);
      tmp = W[i + 1];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + W[i] + select(0u, 1u, t1_lo < tmp);
      tmp = ((alo >> 28) | (ahi << 4)) ^ ((ahi >> 2) | (alo << 30)) ^ ((ahi >> 7) | (alo << 25));
      let t2_lo = tmp + ((alo & blo) ^ (alo & clo) ^ (blo & clo));
      let t2_hi = (((ahi >> 28) | (alo << 4)) ^ ((alo >> 2) | (ahi << 30)) ^ ((alo >> 7) | (ahi << 25))) + ((ahi & bhi) ^ (ahi & chi) ^ (bhi & chi)) + select(0u, 1u, t2_lo < tmp);
      hhi = ghi;
      hlo = glo;
      ghi = fhi;
      glo = flo;
      fhi = ehi;
      flo = elo;
      elo = dlo + t1_lo;
      ehi = dhi + t1_hi + select(0u, 1u, elo < t1_lo);
      dhi = chi;
      dlo = clo;
      chi = bhi;
      clo = blo;
      bhi = ahi;
      blo = alo;
      alo = t1_lo + t2_lo;
      ahi = t1_hi + t2_hi + select(0u, 1u, alo < t1_lo);
  }

  alo += IV[1];
  ahi += IV[0] + select(0u, 1u, alo < IV[1]);
  blo += IV[3];
  bhi += IV[2] + select(0u, 1u, blo < IV[3]);
  clo += IV[5];
  chi += IV[4] + select(0u, 1u, clo < IV[5]);
  dlo += IV[7];
  dhi += IV[6] + select(0u, 1u, dlo < IV[7]);
  elo += IV[9];
  ehi += IV[8] + select(0u, 1u, elo < IV[9]);
  flo += IV[11];
  fhi += IV[10] + select(0u, 1u, flo < IV[11]);
  glo += IV[13];
  ghi += IV[12] + select(0u, 1u, glo < IV[13]);
  hlo += IV[15];
  hhi += IV[14] + select(0u, 1u, hlo < IV[15]);

  out[0] = ahi;
  out[1] = alo;
  out[2] = bhi;
  out[3] = blo;
  out[4] = chi;
  out[5] = clo;
  out[6] = dhi;
  out[7] = dlo;
  out[8] = ehi;
  out[9] = elo;
  out[10] = fhi;
  out[11] = flo;
  out[12] = ghi;
  out[13] = glo;
  out[14] = hhi;
  out[15] = hlo;
}

@group(0) @binding(0) var<storage, read> input: array<u32>;
@group(0) @binding(1) var<storage, read_write> output: array<u32>;

@compute @workgroup_size(1)
fn main() {
  var IV = array<u32,16>(
      0x6a09e667, 0xf3bcc908, 0xbb67ae85, 0x84caa73b,
      0x3c6ef372, 0xfe94f82b, 0xa54ff53a, 0x5f1d36f1,
      0x510e527f, 0xade682d1, 0x9b05688c, 0x2b3e6c1f,
      0x1f83d9ab, 0xfb41bd6b, 0x5be0cd19, 0x137e2179,
  );
  var tmp_buf: array<u32, 32>;
  var seed1: array<u32, 16>;
  var seed2: array<u32, 16>;
  for (var i: u32 = 0u; i < 32u; i += 1u) { tmp_buf[i] = input[i] ^ 0x36363636; }
  sha512(&tmp_buf, &seed1, &IV);
  for (var i: u32 = 0u; i < 32u; i += 1u) { tmp_buf[i] = input[i] ^ 0x5c5c5c5c; }
  sha512(&tmp_buf, &seed2, &IV);
  for (var i = 0; i < 32; i += 1) { tmp_buf[i] = 0; }
  tmp_buf[0] = 0x6d6e656d; // mnem
  tmp_buf[1] = 0x6f6e6963; // onic
  tmp_buf[2] = 1;
  tmp_buf[3] = 0x80000000;
  tmp_buf[31] = 140 * 8;
  var new_block: array<u32, 16>;
  sha512(&tmp_buf, &new_block, &seed1);

  for (var i = 0; i < 16; i += 1) { tmp_buf[i] = new_block[i]; }
  for (var i = 16; i < 32; i += 1) { tmp_buf[i] = 0; }
  tmp_buf[16] = 0x80000000;
  tmp_buf[31] = 192 * 8;
  var dk: array<u32, 16>;
  sha512(&tmp_buf, &dk, &seed2);
  for (var i = 0; i < 32; i += 1) { new_block[i] = dk[i]; }

  for (var i = 1; i < 2048; i += 1) {
      for (var i = 0; i < 16; i += 1) { tmp_buf[i] = new_block[i]; }
      sha512(&tmp_buf, &new_block, &seed1);
      for (var i = 0; i < 16; i += 1) { tmp_buf[i] = new_block[i]; }
      sha512(&tmp_buf, &new_block, &seed2);
      for (var i = 0; i < 16; i += 1) { dk[i] ^= new_block[i]; }
  }

  for (var i = 0; i < 16; i += 1) {
    output[i] = dk[i];
  }
}
