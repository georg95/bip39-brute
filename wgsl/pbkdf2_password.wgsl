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

@group(0) @binding(0) var<storage, read> input: array<u32>;
@group(0) @binding(1) var<storage, read_write> output: array<u32>;

const masks = array<u32, 4>(0x00ffffff, 0xff00ffff, 0xffff00ff, 0xffffff00);
fn setByteArr(arr: ptr<function, array<u32, 32>>, idx: u32, byte: u32) {
  let i = idx/4;
  let sh = idx%4;
  arr[i] = (arr[i] & masks[sh]) + (byte << (24 - sh * 8));
}

const MAX_PASSWORD_LEN: u32 = 128 - 9; // 0x00000001 (4 bytes) 0x80 (1 byte) %%seed bits%% (4 bytes)

fn initBuffer(tmp_buf: ptr<function, array<u32, 32>>, gidX: u32) {
  for (var i = 0; i < 32; i += 1) { tmp_buf[i] = 0; }
  tmp_buf[0] = 0x6d6e656d; // mnem
  tmp_buf[1] = 0x6f6e6963; // onic
  var passOffset: u32 = input[gidX + 32u];

  var passLen: u32 = 0;
  for (; passLen < MAX_PASSWORD_LEN; passLen++) {
    var offset = passOffset + passLen;
    var b = (input[offset / 4] >> ((offset % 4) * 8)) & 0xff;
    if (b == 0x0Au) { break; }
    setByteArr(tmp_buf, 8u + passLen, b);
  }
  setByteArr(tmp_buf, passLen + 8, 0x00);
  setByteArr(tmp_buf, passLen + 9, 0x00);
  setByteArr(tmp_buf, passLen + 10, 0x00);
  setByteArr(tmp_buf, passLen + 11, 0x01);
  setByteArr(tmp_buf, passLen + 12, 0x80);
  tmp_buf[31] = (passLen + 140) * 8;
}

fn mainLoop(buf: array<u32, 32>, globalIndex: u32) {
  var dk: array<u32, 16>;
  for (var i = 0; i < 16; i += 1) { dk[i] = buf[i]; }
  INIT_BUF

  var ahi: u32;
  var alo: u32;
  var bhi: u32;
  var blo: u32;
  var chi: u32;
  var clo: u32;
  var dhi: u32;
  var dlo: u32;
  var ehi: u32;
  var elo: u32;
  var fhi: u32;
  var flo: u32;
  var ghi: u32;
  var glo: u32;
  var hhi: u32;
  var hlo: u32;

  var t1_lo: u32;
  var t1_hi: u32;
  var t2_lo: u32;
  var t2_hi: u32;
  var acc_lo: u32;
  var acc_hi: u32;
  var tmp: u32;

  for (var i = 1; i < 2048; i += 1) {

    INIT_ROUNDS1
    MAIN_ROUNDS

    W[1] = alo + SEED1_1;
    W[0] = ahi + SEED1_0 + select(0u, 1u, W[1] < SEED1_1);
    W[3] = blo + SEED1_3;
    W[2] = bhi + SEED1_2 + select(0u, 1u, W[3] < SEED1_3);
    W[5] = clo + SEED1_5;
    W[4] = chi + SEED1_4 + select(0u, 1u, W[5] < SEED1_5);
    W[7] = dlo + SEED1_7;
    W[6] = dhi + SEED1_6 + select(0u, 1u, W[7] < SEED1_7);
    W[9] = elo + SEED1_9;
    W[8] = ehi + SEED1_8 + select(0u, 1u, W[9] < SEED1_9);
    W[11] = flo + SEED1_11;
    W[10] = fhi + SEED1_10 + select(0u, 1u, W[11] < SEED1_11);
    W[13] = glo + SEED1_13;
    W[12] = ghi + SEED1_12 + select(0u, 1u, W[13] < SEED1_13);
    W[15] = hlo + SEED1_15;
    W[14] = hhi + SEED1_14 + select(0u, 1u, W[15] < SEED1_15);

    INIT_ROUNDS2
    MAIN_ROUNDS

    W[1] = alo + SEED2_1;
    W[0] = ahi + SEED2_0 + select(0u, 1u, W[1] < SEED2_1);
    W[3] = blo + SEED2_3;
    W[2] = bhi + SEED2_2 + select(0u, 1u, W[3] < SEED2_3);
    W[5] = clo + SEED2_5;
    W[4] = chi + SEED2_4 + select(0u, 1u, W[5] < SEED2_5);
    W[7] = dlo + SEED2_7;
    W[6] = dhi + SEED2_6 + select(0u, 1u, W[7] < SEED2_7);
    W[9] = elo + SEED2_9;
    W[8] = ehi + SEED2_8 + select(0u, 1u, W[9] < SEED2_9);
    W[11] = flo + SEED2_11;
    W[10] = fhi + SEED2_10 + select(0u, 1u, W[11] < SEED2_11);
    W[13] = glo + SEED2_13;
    W[12] = ghi + SEED2_12 + select(0u, 1u, W[13] < SEED2_13);
    W[15] = hlo + SEED2_15;
    W[14] = hhi + SEED2_14 + select(0u, 1u, W[15] < SEED2_15);

    dk[0] ^= W[0]; dk[1] ^= W[1]; dk[2] ^= W[2]; dk[3] ^= W[3];
    dk[4] ^= W[4]; dk[5] ^= W[5]; dk[6] ^= W[6]; dk[7] ^= W[7];
    dk[8] ^= W[8]; dk[9] ^= W[9]; dk[10] ^= W[10]; dk[11] ^= W[11];
    dk[12] ^= W[12]; dk[13] ^= W[13]; dk[14] ^= W[14]; dk[15] ^= W[15];
  }

  for (var i: u32 = 0; i < 16; i += 1) {
    output[globalIndex * 16u + i] = dk[i];
  }
}

fn sha512(inp: ptr<function, array<u32, 32>>, IV: ptr<function, array<u32, 16>>) {
  var W: array<u32, 32>;
  for (var i: u32 =  0u; i <  32u; i = i + 1u) { W[i] = inp[i]; }

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

  for (var i: u32 = 0u; i < 32u; i = i + 2u) {
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

  for (var i: u32 = 32u; i < 160u; i = i + 2u) {
      var xhi = W[(i + 28) & 0x1f];
      var xlo = W[(i + 29) & 0x1f];
      let t4_hi = ((xhi >> 19) | (xlo << 13)) ^ ((xlo >> 29) | (xhi << 3)) ^ (xhi >> 6);
      let t4_lo = ((xlo >> 19) | (xhi << 13)) ^ ((xhi >> 29) | (xlo << 3)) ^ ((xlo >> 6) | (xhi << 26));
      xhi = W[(i + 2) & 0x1f];
      xlo = W[(i + 3) & 0x1f];
      let t3_hi = ((xhi >> 1) | (xlo << 31)) ^ ((xhi >> 8) | (xlo << 24)) ^ (xhi >> 7);
      let t3_lo = ((xlo >> 1) | (xhi << 31)) ^ ((xlo >> 8) | (xhi << 24)) ^ ((xlo >> 7) | (xhi << 25));
      var acc_lo = W[(i + 19) & 0x1f] + W[(i + 1) & 0x1f];
      var acc_hi = W[(i + 18) & 0x1f] + W[i & 0x1f] + select(0u, 1u, acc_lo < W[(i + 19) & 0x1f]);
      acc_lo = acc_lo + t4_lo;
      acc_hi = acc_hi + t4_hi + select(0u, 1u, acc_lo < t4_lo);
      acc_lo = acc_lo + t3_lo;
      acc_hi = acc_hi + t3_hi + select(0u, 1u, acc_lo < t3_lo);
      W[i & 0x1f] = acc_hi;
      W[(i + 1) & 0x1f] = acc_lo;

      var t1_lo = hlo + (((elo >> 14) | (ehi << 18)) ^ ((elo >> 18) | (ehi << 14)) ^ ((ehi >> 9) | (elo << 23)));
      var t1_hi = hhi + (((ehi >> 14) | (elo << 18)) ^ ((ehi >> 18) | (elo << 14)) ^ ((elo >> 9) | (ehi << 23))) + select(0u, 1u, t1_lo < hlo);
      var tmp = (elo & flo) ^ ((~elo) & glo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((ehi & fhi) ^ ((~ehi) & ghi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 1];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i] + select(0u, 1u, t1_lo < tmp);
      t1_lo = t1_lo + acc_lo;
      t1_hi = t1_hi + acc_hi + select(0u, 1u, t1_lo < acc_lo);
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

  inp[0] = ahi;
  inp[1] = alo;
  inp[2] = bhi;
  inp[3] = blo;
  inp[4] = chi;
  inp[5] = clo;
  inp[6] = dhi;
  inp[7] = dlo;
  inp[8] = ehi;
  inp[9] = elo;
  inp[10] = fhi;
  inp[11] = flo;
  inp[12] = ghi;
  inp[13] = glo;
  inp[14] = hhi;
  inp[15] = hlo;
}

@compute @workgroup_size(WORKGROUP_SIZE)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
  var tmp_buf: array<u32, 32>;
  initBuffer(&tmp_buf, gid.x);

  var seed1 = array<u32, 16>(SEED1_0, SEED1_1, SEED1_2, SEED1_3, SEED1_4, SEED1_5, SEED1_6, SEED1_7, SEED1_8, SEED1_9, SEED1_10, SEED1_11, SEED1_12, SEED1_13, SEED1_14, SEED1_15);
  sha512(&tmp_buf, &seed1);
  var seed2 = array<u32, 16>(SEED2_0, SEED2_1, SEED2_2, SEED2_3, SEED2_4, SEED2_5, SEED2_6, SEED2_7, SEED2_8, SEED2_9, SEED2_10, SEED2_11, SEED2_12, SEED2_13, SEED2_14, SEED2_15);
  for (var i = 16; i < 32; i += 1) { tmp_buf[i] = 0; }
  tmp_buf[16] = 0x80000000;
  tmp_buf[31] = 192 * 8;
  sha512(&tmp_buf, &seed2);
  mainLoop(tmp_buf, gid.x);
}
