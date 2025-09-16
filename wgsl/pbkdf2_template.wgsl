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

fn mainLoop(buf: array<u32, 32>, dk: ptr<function, array<u32, 16>>) {
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

  for (var i = 0; i < 2048; i += 1) {

    ahi = SEED1_0; alo = SEED1_1;
    bhi = SEED1_2; blo = SEED1_3;
    chi = SEED1_4; clo = SEED1_5;
    dhi = SEED1_6; dlo = SEED1_7;
    ehi = SEED1_8; elo = SEED1_9;
    fhi = SEED1_10; flo = SEED1_11;
    ghi = SEED1_12; glo = SEED1_13;
    hhi = SEED1_14; hlo = SEED1_15;

    INIT_ROUNDS
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
    W[16] = 0x80000000;
    W[17] = 0; W[18] = 0; W[19] = 0; W[20] = 0; W[21] = 0; W[22] = 0; W[23] = 0;
    W[24] = 0; W[25] = 0; W[26] = 0; W[27] = 0; W[28] = 0; W[29] = 0; W[30] = 0;
    W[31] = 192 * 8;


    ahi = SEED2_0; alo = SEED2_1;
    bhi = SEED2_2; blo = SEED2_3;
    chi = SEED2_4; clo = SEED2_5;
    dhi = SEED2_6; dlo = SEED2_7;
    ehi = SEED2_8; elo = SEED2_9;
    fhi = SEED2_10; flo = SEED2_11;
    ghi = SEED2_12; glo = SEED2_13;
    hhi = SEED2_14; hlo = SEED2_15;

    INIT_ROUNDS
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
    W[16] = 0x80000000;
    W[17] = 0; W[18] = 0; W[19] = 0; W[20] = 0; W[21] = 0; W[22] = 0; W[23] = 0;
    W[24] = 0; W[25] = 0; W[26] = 0; W[27] = 0; W[28] = 0; W[29] = 0; W[30] = 0;
    W[31] = 192 * 8;

    dk[0] ^= W[0]; dk[1] ^= W[1]; dk[2] ^= W[2]; dk[3] ^= W[3];
    dk[4] ^= W[4]; dk[5] ^= W[5]; dk[6] ^= W[6]; dk[7] ^= W[7];
    dk[8] ^= W[8]; dk[9] ^= W[9]; dk[10] ^= W[10]; dk[11] ^= W[11];
    dk[12] ^= W[12]; dk[13] ^= W[13]; dk[14] ^= W[14]; dk[15] ^= W[15];
  }
}

@compute @workgroup_size(WORKGROUP_SIZE)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
  var tmp_buf: array<u32, 32>;
  var dk: array<u32, 16>;
  initBuffer(&tmp_buf, gid.x);

  for (var i = 0; i < 16; i += 1) { dk[i] = 0; }
  mainLoop(tmp_buf, &dk);
  for (var i: u32 = 0; i < 16; i += 1) {
    output[gid.x * 16u + i] = dk[i];
  }
}
