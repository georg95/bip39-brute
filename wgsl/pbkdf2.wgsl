@group(0) @binding(0) var<storage, read> input: array<u32>;
@group(0) @binding(1) var<storage, read_write> output: array<u32>;

@compute @workgroup_size(WORKGROUP_SIZE)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
  
  INIT_BUF
  INIT_SEED1
  INIT_SEED2
  INIT_DK
  
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

  for (var k = 1; k < 2048; k++) {
      ahi = seed1[0];
      alo = seed1[1];
      bhi = seed1[2];
      blo = seed1[3];
      chi = seed1[4];
      clo = seed1[5];
      dhi = seed1[6];
      dlo = seed1[7];
      ehi = seed1[8];
      elo = seed1[9];
      fhi = seed1[10];
      flo = seed1[11];
      ghi = seed1[12];
      glo = seed1[13];
      hhi = seed1[14];
      hlo = seed1[15];

      INIT_ROUNDS
      MAIN_ROUNDS

      alo += seed1[1];
      ahi += seed1[0] + select(0u, 1u, alo < seed1[1]);
      blo += seed1[3];
      bhi += seed1[2] + select(0u, 1u, blo < seed1[3]);
      clo += seed1[5];
      chi += seed1[4] + select(0u, 1u, clo < seed1[5]);
      dlo += seed1[7];
      dhi += seed1[6] + select(0u, 1u, dlo < seed1[7]);
      elo += seed1[9];
      ehi += seed1[8] + select(0u, 1u, elo < seed1[9]);
      flo += seed1[11];
      fhi += seed1[10] + select(0u, 1u, flo < seed1[11]);
      glo += seed1[13];
      ghi += seed1[12] + select(0u, 1u, glo < seed1[13]);
      hlo += seed1[15];
      hhi += seed1[14] + select(0u, 1u, hlo < seed1[15]);

      W[0] = ahi;
      W[1] = alo;
      W[2] = bhi;
      W[3] = blo;
      W[4] = chi;
      W[5] = clo;
      W[6] = dhi;
      W[7] = dlo;
      W[8] = ehi;
      W[9] = elo;
      W[10] = fhi;
      W[11] = flo;
      W[12] = ghi;
      W[13] = glo;
      W[14] = hhi;
      W[15] = hlo;

      ahi = seed2[0];
      alo = seed2[1];
      bhi = seed2[2];
      blo = seed2[3];
      chi = seed2[4];
      clo = seed2[5];
      dhi = seed2[6];
      dlo = seed2[7];
      ehi = seed2[8];
      elo = seed2[9];
      fhi = seed2[10];
      flo = seed2[11];
      ghi = seed2[12];
      glo = seed2[13];
      hhi = seed2[14];
      hlo = seed2[15];

      INIT_ROUNDS
      MAIN_ROUNDS

      alo += seed2[1];
      ahi += seed2[0] + select(0u, 1u, alo < seed2[1]);
      blo += seed2[3];
      bhi += seed2[2] + select(0u, 1u, blo < seed2[3]);
      clo += seed2[5];
      chi += seed2[4] + select(0u, 1u, clo < seed2[5]);
      dlo += seed2[7];
      dhi += seed2[6] + select(0u, 1u, dlo < seed2[7]);
      elo += seed2[9];
      ehi += seed2[8] + select(0u, 1u, elo < seed2[9]);
      flo += seed2[11];
      fhi += seed2[10] + select(0u, 1u, flo < seed2[11]);
      glo += seed2[13];
      ghi += seed2[12] + select(0u, 1u, glo < seed2[13]);
      hlo += seed2[15];
      hhi += seed2[14] + select(0u, 1u, hlo < seed2[15]);

      W[0] = ahi;
      W[1] = alo;
      W[2] = bhi;
      W[3] = blo;
      W[4] = chi;
      W[5] = clo;
      W[6] = dhi;
      W[7] = dlo;
      W[8] = ehi;
      W[9] = elo;
      W[10] = fhi;
      W[11] = flo;
      W[12] = ghi;
      W[13] = glo;
      W[14] = hhi;
      W[15] = hlo;

      dk[0] ^= W[0]; dk[1] ^= W[1]; dk[2] ^= W[2]; dk[3] ^= W[3];
      dk[4] ^= W[4]; dk[5] ^= W[5]; dk[6] ^= W[6]; dk[7] ^= W[7];
      dk[8] ^= W[8]; dk[9] ^= W[9]; dk[10] ^= W[10]; dk[11] ^= W[11];
      dk[12] ^= W[12]; dk[13] ^= W[13]; dk[14] ^= W[14]; dk[15] ^= W[15];
  }
  output[gid.x * 16 + 0] = dk[0]; output[gid.x * 16 + 1] = dk[1];
  output[gid.x * 16 + 2] = dk[2]; output[gid.x * 16 + 3] = dk[3];
  output[gid.x * 16 + 4] = dk[4]; output[gid.x * 16 + 5] = dk[5];
  output[gid.x * 16 + 6] = dk[6]; output[gid.x * 16 + 7] = dk[7];
  output[gid.x * 16 + 8] = dk[8]; output[gid.x * 16 + 9] = dk[9];
  output[gid.x * 16 + 10] = dk[10]; output[gid.x * 16 + 11] = dk[11];
  output[gid.x * 16 + 12] = dk[12]; output[gid.x * 16 + 13] = dk[13];
  output[gid.x * 16 + 14] = dk[14]; output[gid.x * 16 + 15] = dk[15];
}

