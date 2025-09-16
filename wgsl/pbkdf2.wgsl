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

fn sha512(W: ptr<function, array<u32, 32>>, IV: ptr<function, array<u32, 16>>) {
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

  var xhi: u32;
  var xlo: u32;
  var t1_lo: u32;
  var t1_hi: u32;
  var t2_lo: u32;
  var t2_hi: u32;
  var tx1_hi: u32;
  var tx1_lo: u32;
  var tx3_hi: u32;
  var tx3_lo: u32;
  var acc_lo: u32;
  var acc_hi: u32;
  var tmp: u32;

  for (var i: u32 = 0u; i < 32u; i += 16u) {
      t1_lo = hlo + (((elo >> 14) | (ehi << 18)) ^ ((elo >> 18) | (ehi << 14)) ^ ((ehi >> 9) | (elo << 23)));
      t1_hi = hhi + (((ehi >> 14) | (elo << 18)) ^ ((ehi >> 18) | (elo << 14)) ^ ((elo >> 9) | (ehi << 23))) + select(0u, 1u, t1_lo < hlo);
      tmp = (elo & flo) ^ ((~elo) & glo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((ehi & fhi) ^ ((~ehi) & ghi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 1];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i + 0] + select(0u, 1u, t1_lo < tmp);
      tmp = W[i + 1];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + W[i + 0] + select(0u, 1u, t1_lo < tmp);
      tmp = ((alo >> 28) | (ahi << 4)) ^ ((ahi >> 2) | (alo << 30)) ^ ((ahi >> 7) | (alo << 25));
      t2_lo = tmp + ((alo & blo) ^ (alo & clo) ^ (blo & clo));
      t2_hi = (((ahi >> 28) | (alo << 4)) ^ ((alo >> 2) | (ahi << 30)) ^ ((alo >> 7) | (ahi << 25))) + ((ahi & bhi) ^ (ahi & chi) ^ (bhi & chi)) + select(0u, 1u, t2_lo < tmp);
      dlo += t1_lo;
      dhi += t1_hi + select(0u, 1u, dlo < t1_lo);
      hlo = t1_lo + t2_lo;
      hhi = t1_hi + t2_hi + select(0u, 1u, hlo < t1_lo);

      t1_lo = glo + (((dlo >> 14) | (dhi << 18)) ^ ((dlo >> 18) | (dhi << 14)) ^ ((dhi >> 9) | (dlo << 23)));
      t1_hi = ghi + (((dhi >> 14) | (dlo << 18)) ^ ((dhi >> 18) | (dlo << 14)) ^ ((dlo >> 9) | (dhi << 23))) + select(0u, 1u, t1_lo < glo);
      tmp = (dlo & elo) ^ ((~dlo) & flo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((dhi & ehi) ^ ((~dhi) & fhi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 3];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i + 2] + select(0u, 1u, t1_lo < tmp);
      tmp = W[i + 3];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + W[i + 2] + select(0u, 1u, t1_lo < tmp);
      tmp = ((hlo >> 28) | (hhi << 4)) ^ ((hhi >> 2) | (hlo << 30)) ^ ((hhi >> 7) | (hlo << 25));
      t2_lo = tmp + ((hlo & alo) ^ (hlo & blo) ^ (alo & blo));
      t2_hi = (((hhi >> 28) | (hlo << 4)) ^ ((hlo >> 2) | (hhi << 30)) ^ ((hlo >> 7) | (hhi << 25))) + ((hhi & ahi) ^ (hhi & bhi) ^ (ahi & bhi)) + select(0u, 1u, t2_lo < tmp);
      clo += t1_lo;
      chi += t1_hi + select(0u, 1u, clo < t1_lo);
      glo = t1_lo + t2_lo;
      ghi = t1_hi + t2_hi + select(0u, 1u, glo < t1_lo);

      t1_lo = flo + (((clo >> 14) | (chi << 18)) ^ ((clo >> 18) | (chi << 14)) ^ ((chi >> 9) | (clo << 23)));
      t1_hi = fhi + (((chi >> 14) | (clo << 18)) ^ ((chi >> 18) | (clo << 14)) ^ ((clo >> 9) | (chi << 23))) + select(0u, 1u, t1_lo < flo);
      tmp = (clo & dlo) ^ ((~clo) & elo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((chi & dhi) ^ ((~chi) & ehi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 5];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i + 4] + select(0u, 1u, t1_lo < tmp);
      tmp = W[i + 5];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + W[i + 4] + select(0u, 1u, t1_lo < tmp);
      tmp = ((glo >> 28) | (ghi << 4)) ^ ((ghi >> 2) | (glo << 30)) ^ ((ghi >> 7) | (glo << 25));
      t2_lo = tmp + ((glo & hlo) ^ (glo & alo) ^ (hlo & alo));
      t2_hi = (((ghi >> 28) | (glo << 4)) ^ ((glo >> 2) | (ghi << 30)) ^ ((glo >> 7) | (ghi << 25))) + ((ghi & hhi) ^ (ghi & ahi) ^ (hhi & ahi)) + select(0u, 1u, t2_lo < tmp);
      blo += t1_lo;
      bhi += t1_hi + select(0u, 1u, blo < t1_lo);
      flo = t1_lo + t2_lo;
      fhi = t1_hi + t2_hi + select(0u, 1u, flo < t1_lo);

      t1_lo = elo + (((blo >> 14) | (bhi << 18)) ^ ((blo >> 18) | (bhi << 14)) ^ ((bhi >> 9) | (blo << 23)));
      t1_hi = ehi + (((bhi >> 14) | (blo << 18)) ^ ((bhi >> 18) | (blo << 14)) ^ ((blo >> 9) | (bhi << 23))) + select(0u, 1u, t1_lo < elo);
      tmp = (blo & clo) ^ ((~blo) & dlo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((bhi & chi) ^ ((~bhi) & dhi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 7];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i + 6] + select(0u, 1u, t1_lo < tmp);
      tmp = W[i + 7];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + W[i + 6] + select(0u, 1u, t1_lo < tmp);
      tmp = ((flo >> 28) | (fhi << 4)) ^ ((fhi >> 2) | (flo << 30)) ^ ((fhi >> 7) | (flo << 25));
      t2_lo = tmp + ((flo & glo) ^ (flo & hlo) ^ (glo & hlo));
      t2_hi = (((fhi >> 28) | (flo << 4)) ^ ((flo >> 2) | (fhi << 30)) ^ ((flo >> 7) | (fhi << 25))) + ((fhi & ghi) ^ (fhi & hhi) ^ (ghi & hhi)) + select(0u, 1u, t2_lo < tmp);
      alo += t1_lo;
      ahi += t1_hi + select(0u, 1u, alo < t1_lo);
      elo = t1_lo + t2_lo;
      ehi = t1_hi + t2_hi + select(0u, 1u, elo < t1_lo);

      t1_lo = dlo + (((alo >> 14) | (ahi << 18)) ^ ((alo >> 18) | (ahi << 14)) ^ ((ahi >> 9) | (alo << 23)));
      t1_hi = dhi + (((ahi >> 14) | (alo << 18)) ^ ((ahi >> 18) | (alo << 14)) ^ ((alo >> 9) | (ahi << 23))) + select(0u, 1u, t1_lo < dlo);
      tmp = (alo & blo) ^ ((~alo) & clo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((ahi & bhi) ^ ((~ahi) & chi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 9];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i + 8] + select(0u, 1u, t1_lo < tmp);
      tmp = W[i + 9];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + W[i + 8] + select(0u, 1u, t1_lo < tmp);
      tmp = ((elo >> 28) | (ehi << 4)) ^ ((ehi >> 2) | (elo << 30)) ^ ((ehi >> 7) | (elo << 25));
      t2_lo = tmp + ((elo & flo) ^ (elo & glo) ^ (flo & glo));
      t2_hi = (((ehi >> 28) | (elo << 4)) ^ ((elo >> 2) | (ehi << 30)) ^ ((elo >> 7) | (ehi << 25))) + ((ehi & fhi) ^ (ehi & ghi) ^ (fhi & ghi)) + select(0u, 1u, t2_lo < tmp);
      hlo += t1_lo;
      hhi += t1_hi + select(0u, 1u, hlo < t1_lo);
      dlo = t1_lo + t2_lo;
      dhi = t1_hi + t2_hi + select(0u, 1u, dlo < t1_lo);

      t1_lo = clo + (((hlo >> 14) | (hhi << 18)) ^ ((hlo >> 18) | (hhi << 14)) ^ ((hhi >> 9) | (hlo << 23)));
      t1_hi = chi + (((hhi >> 14) | (hlo << 18)) ^ ((hhi >> 18) | (hlo << 14)) ^ ((hlo >> 9) | (hhi << 23))) + select(0u, 1u, t1_lo < clo);
      tmp = (hlo & alo) ^ ((~hlo) & blo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((hhi & ahi) ^ ((~hhi) & bhi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 11];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i + 10] + select(0u, 1u, t1_lo < tmp);
      tmp = W[i + 11];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + W[i + 10] + select(0u, 1u, t1_lo < tmp);
      tmp = ((dlo >> 28) | (dhi << 4)) ^ ((dhi >> 2) | (dlo << 30)) ^ ((dhi >> 7) | (dlo << 25));
      t2_lo = tmp + ((dlo & elo) ^ (dlo & flo) ^ (elo & flo));
      t2_hi = (((dhi >> 28) | (dlo << 4)) ^ ((dlo >> 2) | (dhi << 30)) ^ ((dlo >> 7) | (dhi << 25))) + ((dhi & ehi) ^ (dhi & fhi) ^ (ehi & fhi)) + select(0u, 1u, t2_lo < tmp);
      glo += t1_lo;
      ghi += t1_hi + select(0u, 1u, glo < t1_lo);
      clo = t1_lo + t2_lo;
      chi = t1_hi + t2_hi + select(0u, 1u, clo < t1_lo);

      t1_lo = blo + (((glo >> 14) | (ghi << 18)) ^ ((glo >> 18) | (ghi << 14)) ^ ((ghi >> 9) | (glo << 23)));
      t1_hi = bhi + (((ghi >> 14) | (glo << 18)) ^ ((ghi >> 18) | (glo << 14)) ^ ((glo >> 9) | (ghi << 23))) + select(0u, 1u, t1_lo < blo);
      tmp = (glo & hlo) ^ ((~glo) & alo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((ghi & hhi) ^ ((~ghi) & ahi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 13];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i + 12] + select(0u, 1u, t1_lo < tmp);
      tmp = W[i + 13];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + W[i + 12] + select(0u, 1u, t1_lo < tmp);
      tmp = ((clo >> 28) | (chi << 4)) ^ ((chi >> 2) | (clo << 30)) ^ ((chi >> 7) | (clo << 25));
      t2_lo = tmp + ((clo & dlo) ^ (clo & elo) ^ (dlo & elo));
      t2_hi = (((chi >> 28) | (clo << 4)) ^ ((clo >> 2) | (chi << 30)) ^ ((clo >> 7) | (chi << 25))) + ((chi & dhi) ^ (chi & ehi) ^ (dhi & ehi)) + select(0u, 1u, t2_lo < tmp);
      flo += t1_lo;
      fhi += t1_hi + select(0u, 1u, flo < t1_lo);
      blo = t1_lo + t2_lo;
      bhi = t1_hi + t2_hi + select(0u, 1u, blo < t1_lo);

      t1_lo = alo + (((flo >> 14) | (fhi << 18)) ^ ((flo >> 18) | (fhi << 14)) ^ ((fhi >> 9) | (flo << 23)));
      t1_hi = ahi + (((fhi >> 14) | (flo << 18)) ^ ((fhi >> 18) | (flo << 14)) ^ ((flo >> 9) | (fhi << 23))) + select(0u, 1u, t1_lo < alo);
      tmp = (flo & glo) ^ ((~flo) & hlo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((fhi & ghi) ^ ((~fhi) & hhi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 15];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i + 14] + select(0u, 1u, t1_lo < tmp);
      tmp = W[i + 15];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + W[i + 14] + select(0u, 1u, t1_lo < tmp);
      tmp = ((blo >> 28) | (bhi << 4)) ^ ((bhi >> 2) | (blo << 30)) ^ ((bhi >> 7) | (blo << 25));
      t2_lo = tmp + ((blo & clo) ^ (blo & dlo) ^ (clo & dlo));
      t2_hi = (((bhi >> 28) | (blo << 4)) ^ ((blo >> 2) | (bhi << 30)) ^ ((blo >> 7) | (bhi << 25))) + ((bhi & chi) ^ (bhi & dhi) ^ (chi & dhi)) + select(0u, 1u, t2_lo < tmp);
      elo += t1_lo;
      ehi += t1_hi + select(0u, 1u, elo < t1_lo);
      alo = t1_lo + t2_lo;
      ahi = t1_hi + t2_hi + select(0u, 1u, alo < t1_lo);
  }

  for (var i: u32 = 32u; i < 160u; i += 32u) {
      xhi = W[28];
      xlo = W[29];
      tx1_hi = ((xhi >> 19) | (xlo << 13)) ^ ((xlo >> 29) | (xhi << 3)) ^ (xhi >> 6);
      tx1_lo = ((xlo >> 19) | (xhi << 13)) ^ ((xhi >> 29) | (xlo << 3)) ^ ((xlo >> 6) | (xhi << 26));
      xhi = W[2];
      xlo = W[3];
      tx3_hi = ((xhi >> 1) | (xlo << 31)) ^ ((xhi >> 8) | (xlo << 24)) ^ (xhi >> 7);
      tx3_lo = ((xlo >> 1) | (xhi << 31)) ^ ((xlo >> 8) | (xhi << 24)) ^ ((xlo >> 7) | (xhi << 25));
      acc_lo = W[19] + W[1];
      acc_hi = W[18] + W[0] + select(0u, 1u, acc_lo < W[19]);
      acc_lo = acc_lo + tx1_lo;
      acc_hi = acc_hi + tx1_hi + select(0u, 1u, acc_lo < tx1_lo);
      acc_lo = acc_lo + tx3_lo;
      acc_hi = acc_hi + tx3_hi + select(0u, 1u, acc_lo < tx3_lo);
      W[0] = acc_hi;
      W[1] = acc_lo;

      t1_lo = hlo + (((elo >> 14) | (ehi << 18)) ^ ((elo >> 18) | (ehi << 14)) ^ ((ehi >> 9) | (elo << 23)));
      t1_hi = hhi + (((ehi >> 14) | (elo << 18)) ^ ((ehi >> 18) | (elo << 14)) ^ ((elo >> 9) | (ehi << 23))) + select(0u, 1u, t1_lo < hlo);
      tmp = (elo & flo) ^ ((~elo) & glo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((ehi & fhi) ^ ((~ehi) & ghi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 1];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i + 0] + select(0u, 1u, t1_lo < tmp);
      tmp = W[1];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + W[0] + select(0u, 1u, t1_lo < tmp);
      tmp = ((alo >> 28) | (ahi << 4)) ^ ((ahi >> 2) | (alo << 30)) ^ ((ahi >> 7) | (alo << 25));
      t2_lo = tmp + ((alo & blo) ^ (alo & clo) ^ (blo & clo));
      t2_hi = (((ahi >> 28) | (alo << 4)) ^ ((alo >> 2) | (ahi << 30)) ^ ((alo >> 7) | (ahi << 25))) + ((ahi & bhi) ^ (ahi & chi) ^ (bhi & chi)) + select(0u, 1u, t2_lo < tmp);
      dlo += t1_lo;
      dhi += t1_hi + select(0u, 1u, dlo < t1_lo);
      hlo = t1_lo + t2_lo;
      hhi = t1_hi + t2_hi + select(0u, 1u, hlo < t1_lo);

      xhi = W[30];
      xlo = W[31];
      tx1_hi = ((xhi >> 19) | (xlo << 13)) ^ ((xlo >> 29) | (xhi << 3)) ^ (xhi >> 6);
      tx1_lo = ((xlo >> 19) | (xhi << 13)) ^ ((xhi >> 29) | (xlo << 3)) ^ ((xlo >> 6) | (xhi << 26));
      xhi = W[4];
      xlo = W[5];
      tx3_hi = ((xhi >> 1) | (xlo << 31)) ^ ((xhi >> 8) | (xlo << 24)) ^ (xhi >> 7);
      tx3_lo = ((xlo >> 1) | (xhi << 31)) ^ ((xlo >> 8) | (xhi << 24)) ^ ((xlo >> 7) | (xhi << 25));
      acc_lo = W[21] + W[3];
      acc_hi = W[20] + W[2] + select(0u, 1u, acc_lo < W[21]);
      acc_lo = acc_lo + tx1_lo;
      acc_hi = acc_hi + tx1_hi + select(0u, 1u, acc_lo < tx1_lo);
      acc_lo = acc_lo + tx3_lo;
      acc_hi = acc_hi + tx3_hi + select(0u, 1u, acc_lo < tx3_lo);
      W[2] = acc_hi;
      W[3] = acc_lo;

      t1_lo = glo + (((dlo >> 14) | (dhi << 18)) ^ ((dlo >> 18) | (dhi << 14)) ^ ((dhi >> 9) | (dlo << 23)));
      t1_hi = ghi + (((dhi >> 14) | (dlo << 18)) ^ ((dhi >> 18) | (dlo << 14)) ^ ((dlo >> 9) | (dhi << 23))) + select(0u, 1u, t1_lo < glo);
      tmp = (dlo & elo) ^ ((~dlo) & flo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((dhi & ehi) ^ ((~dhi) & fhi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 3];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i + 2] + select(0u, 1u, t1_lo < tmp);
      tmp = W[3];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + W[2] + select(0u, 1u, t1_lo < tmp);
      tmp = ((hlo >> 28) | (hhi << 4)) ^ ((hhi >> 2) | (hlo << 30)) ^ ((hhi >> 7) | (hlo << 25));
      t2_lo = tmp + ((hlo & alo) ^ (hlo & blo) ^ (alo & blo));
      t2_hi = (((hhi >> 28) | (hlo << 4)) ^ ((hlo >> 2) | (hhi << 30)) ^ ((hlo >> 7) | (hhi << 25))) + ((hhi & ahi) ^ (hhi & bhi) ^ (ahi & bhi)) + select(0u, 1u, t2_lo < tmp);
      clo += t1_lo;
      chi += t1_hi + select(0u, 1u, clo < t1_lo);
      glo = t1_lo + t2_lo;
      ghi = t1_hi + t2_hi + select(0u, 1u, glo < t1_lo);

      xhi = W[0];
      xlo = W[1];
      tx1_hi = ((xhi >> 19) | (xlo << 13)) ^ ((xlo >> 29) | (xhi << 3)) ^ (xhi >> 6);
      tx1_lo = ((xlo >> 19) | (xhi << 13)) ^ ((xhi >> 29) | (xlo << 3)) ^ ((xlo >> 6) | (xhi << 26));
      xhi = W[6];
      xlo = W[7];
      tx3_hi = ((xhi >> 1) | (xlo << 31)) ^ ((xhi >> 8) | (xlo << 24)) ^ (xhi >> 7);
      tx3_lo = ((xlo >> 1) | (xhi << 31)) ^ ((xlo >> 8) | (xhi << 24)) ^ ((xlo >> 7) | (xhi << 25));
      acc_lo = W[23] + W[5];
      acc_hi = W[22] + W[4] + select(0u, 1u, acc_lo < W[23]);
      acc_lo = acc_lo + tx1_lo;
      acc_hi = acc_hi + tx1_hi + select(0u, 1u, acc_lo < tx1_lo);
      acc_lo = acc_lo + tx3_lo;
      acc_hi = acc_hi + tx3_hi + select(0u, 1u, acc_lo < tx3_lo);
      W[4] = acc_hi;
      W[5] = acc_lo;

      t1_lo = flo + (((clo >> 14) | (chi << 18)) ^ ((clo >> 18) | (chi << 14)) ^ ((chi >> 9) | (clo << 23)));
      t1_hi = fhi + (((chi >> 14) | (clo << 18)) ^ ((chi >> 18) | (clo << 14)) ^ ((clo >> 9) | (chi << 23))) + select(0u, 1u, t1_lo < flo);
      tmp = (clo & dlo) ^ ((~clo) & elo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((chi & dhi) ^ ((~chi) & ehi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 5];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i + 4] + select(0u, 1u, t1_lo < tmp);
      tmp = W[5];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + W[4] + select(0u, 1u, t1_lo < tmp);
      tmp = ((glo >> 28) | (ghi << 4)) ^ ((ghi >> 2) | (glo << 30)) ^ ((ghi >> 7) | (glo << 25));
      t2_lo = tmp + ((glo & hlo) ^ (glo & alo) ^ (hlo & alo));
      t2_hi = (((ghi >> 28) | (glo << 4)) ^ ((glo >> 2) | (ghi << 30)) ^ ((glo >> 7) | (ghi << 25))) + ((ghi & hhi) ^ (ghi & ahi) ^ (hhi & ahi)) + select(0u, 1u, t2_lo < tmp);
      blo += t1_lo;
      bhi += t1_hi + select(0u, 1u, blo < t1_lo);
      flo = t1_lo + t2_lo;
      fhi = t1_hi + t2_hi + select(0u, 1u, flo < t1_lo);

      xhi = W[2];
      xlo = W[3];
      tx1_hi = ((xhi >> 19) | (xlo << 13)) ^ ((xlo >> 29) | (xhi << 3)) ^ (xhi >> 6);
      tx1_lo = ((xlo >> 19) | (xhi << 13)) ^ ((xhi >> 29) | (xlo << 3)) ^ ((xlo >> 6) | (xhi << 26));
      xhi = W[8];
      xlo = W[9];
      tx3_hi = ((xhi >> 1) | (xlo << 31)) ^ ((xhi >> 8) | (xlo << 24)) ^ (xhi >> 7);
      tx3_lo = ((xlo >> 1) | (xhi << 31)) ^ ((xlo >> 8) | (xhi << 24)) ^ ((xlo >> 7) | (xhi << 25));
      acc_lo = W[25] + W[7];
      acc_hi = W[24] + W[6] + select(0u, 1u, acc_lo < W[25]);
      acc_lo = acc_lo + tx1_lo;
      acc_hi = acc_hi + tx1_hi + select(0u, 1u, acc_lo < tx1_lo);
      acc_lo = acc_lo + tx3_lo;
      acc_hi = acc_hi + tx3_hi + select(0u, 1u, acc_lo < tx3_lo);
      W[6] = acc_hi;
      W[7] = acc_lo;

      t1_lo = elo + (((blo >> 14) | (bhi << 18)) ^ ((blo >> 18) | (bhi << 14)) ^ ((bhi >> 9) | (blo << 23)));
      t1_hi = ehi + (((bhi >> 14) | (blo << 18)) ^ ((bhi >> 18) | (blo << 14)) ^ ((blo >> 9) | (bhi << 23))) + select(0u, 1u, t1_lo < elo);
      tmp = (blo & clo) ^ ((~blo) & dlo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((bhi & chi) ^ ((~bhi) & dhi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 7];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i + 6] + select(0u, 1u, t1_lo < tmp);
      tmp = W[7];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + W[6] + select(0u, 1u, t1_lo < tmp);
      tmp = ((flo >> 28) | (fhi << 4)) ^ ((fhi >> 2) | (flo << 30)) ^ ((fhi >> 7) | (flo << 25));
      t2_lo = tmp + ((flo & glo) ^ (flo & hlo) ^ (glo & hlo));
      t2_hi = (((fhi >> 28) | (flo << 4)) ^ ((flo >> 2) | (fhi << 30)) ^ ((flo >> 7) | (fhi << 25))) + ((fhi & ghi) ^ (fhi & hhi) ^ (ghi & hhi)) + select(0u, 1u, t2_lo < tmp);
      alo += t1_lo;
      ahi += t1_hi + select(0u, 1u, alo < t1_lo);
      elo = t1_lo + t2_lo;
      ehi = t1_hi + t2_hi + select(0u, 1u, elo < t1_lo);

      xhi = W[4];
      xlo = W[5];
      tx1_hi = ((xhi >> 19) | (xlo << 13)) ^ ((xlo >> 29) | (xhi << 3)) ^ (xhi >> 6);
      tx1_lo = ((xlo >> 19) | (xhi << 13)) ^ ((xhi >> 29) | (xlo << 3)) ^ ((xlo >> 6) | (xhi << 26));
      xhi = W[10];
      xlo = W[11];
      tx3_hi = ((xhi >> 1) | (xlo << 31)) ^ ((xhi >> 8) | (xlo << 24)) ^ (xhi >> 7);
      tx3_lo = ((xlo >> 1) | (xhi << 31)) ^ ((xlo >> 8) | (xhi << 24)) ^ ((xlo >> 7) | (xhi << 25));
      acc_lo = W[27] + W[9];
      acc_hi = W[26] + W[8] + select(0u, 1u, acc_lo < W[27]);
      acc_lo = acc_lo + tx1_lo;
      acc_hi = acc_hi + tx1_hi + select(0u, 1u, acc_lo < tx1_lo);
      acc_lo = acc_lo + tx3_lo;
      acc_hi = acc_hi + tx3_hi + select(0u, 1u, acc_lo < tx3_lo);
      W[8] = acc_hi;
      W[9] = acc_lo;

      t1_lo = dlo + (((alo >> 14) | (ahi << 18)) ^ ((alo >> 18) | (ahi << 14)) ^ ((ahi >> 9) | (alo << 23)));
      t1_hi = dhi + (((ahi >> 14) | (alo << 18)) ^ ((ahi >> 18) | (alo << 14)) ^ ((alo >> 9) | (ahi << 23))) + select(0u, 1u, t1_lo < dlo);
      tmp = (alo & blo) ^ ((~alo) & clo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((ahi & bhi) ^ ((~ahi) & chi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 9];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i + 8] + select(0u, 1u, t1_lo < tmp);
      tmp = W[9];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + W[8] + select(0u, 1u, t1_lo < tmp);
      tmp = ((elo >> 28) | (ehi << 4)) ^ ((ehi >> 2) | (elo << 30)) ^ ((ehi >> 7) | (elo << 25));
      t2_lo = tmp + ((elo & flo) ^ (elo & glo) ^ (flo & glo));
      t2_hi = (((ehi >> 28) | (elo << 4)) ^ ((elo >> 2) | (ehi << 30)) ^ ((elo >> 7) | (ehi << 25))) + ((ehi & fhi) ^ (ehi & ghi) ^ (fhi & ghi)) + select(0u, 1u, t2_lo < tmp);
      hlo += t1_lo;
      hhi += t1_hi + select(0u, 1u, hlo < t1_lo);
      dlo = t1_lo + t2_lo;
      dhi = t1_hi + t2_hi + select(0u, 1u, dlo < t1_lo);

      xhi = W[6];
      xlo = W[7];
      tx1_hi = ((xhi >> 19) | (xlo << 13)) ^ ((xlo >> 29) | (xhi << 3)) ^ (xhi >> 6);
      tx1_lo = ((xlo >> 19) | (xhi << 13)) ^ ((xhi >> 29) | (xlo << 3)) ^ ((xlo >> 6) | (xhi << 26));
      xhi = W[12];
      xlo = W[13];
      tx3_hi = ((xhi >> 1) | (xlo << 31)) ^ ((xhi >> 8) | (xlo << 24)) ^ (xhi >> 7);
      tx3_lo = ((xlo >> 1) | (xhi << 31)) ^ ((xlo >> 8) | (xhi << 24)) ^ ((xlo >> 7) | (xhi << 25));
      acc_lo = W[29] + W[11];
      acc_hi = W[28] + W[10] + select(0u, 1u, acc_lo < W[29]);
      acc_lo = acc_lo + tx1_lo;
      acc_hi = acc_hi + tx1_hi + select(0u, 1u, acc_lo < tx1_lo);
      acc_lo = acc_lo + tx3_lo;
      acc_hi = acc_hi + tx3_hi + select(0u, 1u, acc_lo < tx3_lo);
      W[10] = acc_hi;
      W[11] = acc_lo;

      t1_lo = clo + (((hlo >> 14) | (hhi << 18)) ^ ((hlo >> 18) | (hhi << 14)) ^ ((hhi >> 9) | (hlo << 23)));
      t1_hi = chi + (((hhi >> 14) | (hlo << 18)) ^ ((hhi >> 18) | (hlo << 14)) ^ ((hlo >> 9) | (hhi << 23))) + select(0u, 1u, t1_lo < clo);
      tmp = (hlo & alo) ^ ((~hlo) & blo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((hhi & ahi) ^ ((~hhi) & bhi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 11];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i + 10] + select(0u, 1u, t1_lo < tmp);
      tmp = W[11];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + W[10] + select(0u, 1u, t1_lo < tmp);
      tmp = ((dlo >> 28) | (dhi << 4)) ^ ((dhi >> 2) | (dlo << 30)) ^ ((dhi >> 7) | (dlo << 25));
      t2_lo = tmp + ((dlo & elo) ^ (dlo & flo) ^ (elo & flo));
      t2_hi = (((dhi >> 28) | (dlo << 4)) ^ ((dlo >> 2) | (dhi << 30)) ^ ((dlo >> 7) | (dhi << 25))) + ((dhi & ehi) ^ (dhi & fhi) ^ (ehi & fhi)) + select(0u, 1u, t2_lo < tmp);
      glo += t1_lo;
      ghi += t1_hi + select(0u, 1u, glo < t1_lo);
      clo = t1_lo + t2_lo;
      chi = t1_hi + t2_hi + select(0u, 1u, clo < t1_lo);

      xhi = W[8];
      xlo = W[9];
      tx1_hi = ((xhi >> 19) | (xlo << 13)) ^ ((xlo >> 29) | (xhi << 3)) ^ (xhi >> 6);
      tx1_lo = ((xlo >> 19) | (xhi << 13)) ^ ((xhi >> 29) | (xlo << 3)) ^ ((xlo >> 6) | (xhi << 26));
      xhi = W[14];
      xlo = W[15];
      tx3_hi = ((xhi >> 1) | (xlo << 31)) ^ ((xhi >> 8) | (xlo << 24)) ^ (xhi >> 7);
      tx3_lo = ((xlo >> 1) | (xhi << 31)) ^ ((xlo >> 8) | (xhi << 24)) ^ ((xlo >> 7) | (xhi << 25));
      acc_lo = W[31] + W[13];
      acc_hi = W[30] + W[12] + select(0u, 1u, acc_lo < W[31]);
      acc_lo = acc_lo + tx1_lo;
      acc_hi = acc_hi + tx1_hi + select(0u, 1u, acc_lo < tx1_lo);
      acc_lo = acc_lo + tx3_lo;
      acc_hi = acc_hi + tx3_hi + select(0u, 1u, acc_lo < tx3_lo);
      W[12] = acc_hi;
      W[13] = acc_lo;

      t1_lo = blo + (((glo >> 14) | (ghi << 18)) ^ ((glo >> 18) | (ghi << 14)) ^ ((ghi >> 9) | (glo << 23)));
      t1_hi = bhi + (((ghi >> 14) | (glo << 18)) ^ ((ghi >> 18) | (glo << 14)) ^ ((glo >> 9) | (ghi << 23))) + select(0u, 1u, t1_lo < blo);
      tmp = (glo & hlo) ^ ((~glo) & alo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((ghi & hhi) ^ ((~ghi) & ahi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 13];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i + 12] + select(0u, 1u, t1_lo < tmp);
      tmp = W[13];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + W[12] + select(0u, 1u, t1_lo < tmp);
      tmp = ((clo >> 28) | (chi << 4)) ^ ((chi >> 2) | (clo << 30)) ^ ((chi >> 7) | (clo << 25));
      t2_lo = tmp + ((clo & dlo) ^ (clo & elo) ^ (dlo & elo));
      t2_hi = (((chi >> 28) | (clo << 4)) ^ ((clo >> 2) | (chi << 30)) ^ ((clo >> 7) | (chi << 25))) + ((chi & dhi) ^ (chi & ehi) ^ (dhi & ehi)) + select(0u, 1u, t2_lo < tmp);
      flo += t1_lo;
      fhi += t1_hi + select(0u, 1u, flo < t1_lo);
      blo = t1_lo + t2_lo;
      bhi = t1_hi + t2_hi + select(0u, 1u, blo < t1_lo);

      xhi = W[10];
      xlo = W[11];
      tx1_hi = ((xhi >> 19) | (xlo << 13)) ^ ((xlo >> 29) | (xhi << 3)) ^ (xhi >> 6);
      tx1_lo = ((xlo >> 19) | (xhi << 13)) ^ ((xhi >> 29) | (xlo << 3)) ^ ((xlo >> 6) | (xhi << 26));
      xhi = W[16];
      xlo = W[17];
      tx3_hi = ((xhi >> 1) | (xlo << 31)) ^ ((xhi >> 8) | (xlo << 24)) ^ (xhi >> 7);
      tx3_lo = ((xlo >> 1) | (xhi << 31)) ^ ((xlo >> 8) | (xhi << 24)) ^ ((xlo >> 7) | (xhi << 25));
      acc_lo = W[1] + W[15];
      acc_hi = W[0] + W[14] + select(0u, 1u, acc_lo < W[1]);
      acc_lo = acc_lo + tx1_lo;
      acc_hi = acc_hi + tx1_hi + select(0u, 1u, acc_lo < tx1_lo);
      acc_lo = acc_lo + tx3_lo;
      acc_hi = acc_hi + tx3_hi + select(0u, 1u, acc_lo < tx3_lo);
      W[14] = acc_hi;
      W[15] = acc_lo;

      t1_lo = alo + (((flo >> 14) | (fhi << 18)) ^ ((flo >> 18) | (fhi << 14)) ^ ((fhi >> 9) | (flo << 23)));
      t1_hi = ahi + (((fhi >> 14) | (flo << 18)) ^ ((fhi >> 18) | (flo << 14)) ^ ((flo >> 9) | (fhi << 23))) + select(0u, 1u, t1_lo < alo);
      tmp = (flo & glo) ^ ((~flo) & hlo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((fhi & ghi) ^ ((~fhi) & hhi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 15];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i + 14] + select(0u, 1u, t1_lo < tmp);
      tmp = W[15];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + W[14] + select(0u, 1u, t1_lo < tmp);
      tmp = ((blo >> 28) | (bhi << 4)) ^ ((bhi >> 2) | (blo << 30)) ^ ((bhi >> 7) | (blo << 25));
      t2_lo = tmp + ((blo & clo) ^ (blo & dlo) ^ (clo & dlo));
      t2_hi = (((bhi >> 28) | (blo << 4)) ^ ((blo >> 2) | (bhi << 30)) ^ ((blo >> 7) | (bhi << 25))) + ((bhi & chi) ^ (bhi & dhi) ^ (chi & dhi)) + select(0u, 1u, t2_lo < tmp);
      elo += t1_lo;
      ehi += t1_hi + select(0u, 1u, elo < t1_lo);
      alo = t1_lo + t2_lo;
      ahi = t1_hi + t2_hi + select(0u, 1u, alo < t1_lo);

      xhi = W[12];
      xlo = W[13];
      tx1_hi = ((xhi >> 19) | (xlo << 13)) ^ ((xlo >> 29) | (xhi << 3)) ^ (xhi >> 6);
      tx1_lo = ((xlo >> 19) | (xhi << 13)) ^ ((xhi >> 29) | (xlo << 3)) ^ ((xlo >> 6) | (xhi << 26));
      xhi = W[18];
      xlo = W[19];
      tx3_hi = ((xhi >> 1) | (xlo << 31)) ^ ((xhi >> 8) | (xlo << 24)) ^ (xhi >> 7);
      tx3_lo = ((xlo >> 1) | (xhi << 31)) ^ ((xlo >> 8) | (xhi << 24)) ^ ((xlo >> 7) | (xhi << 25));
      acc_lo = W[3] + W[17];
      acc_hi = W[2] + W[16] + select(0u, 1u, acc_lo < W[3]);
      acc_lo = acc_lo + tx1_lo;
      acc_hi = acc_hi + tx1_hi + select(0u, 1u, acc_lo < tx1_lo);
      acc_lo = acc_lo + tx3_lo;
      acc_hi = acc_hi + tx3_hi + select(0u, 1u, acc_lo < tx3_lo);
      W[16] = acc_hi;
      W[17] = acc_lo;

      t1_lo = hlo + (((elo >> 14) | (ehi << 18)) ^ ((elo >> 18) | (ehi << 14)) ^ ((ehi >> 9) | (elo << 23)));
      t1_hi = hhi + (((ehi >> 14) | (elo << 18)) ^ ((ehi >> 18) | (elo << 14)) ^ ((elo >> 9) | (ehi << 23))) + select(0u, 1u, t1_lo < hlo);
      tmp = (elo & flo) ^ ((~elo) & glo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((ehi & fhi) ^ ((~ehi) & ghi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 17];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i + 16] + select(0u, 1u, t1_lo < tmp);
      tmp = W[17];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + W[16] + select(0u, 1u, t1_lo < tmp);
      tmp = ((alo >> 28) | (ahi << 4)) ^ ((ahi >> 2) | (alo << 30)) ^ ((ahi >> 7) | (alo << 25));
      t2_lo = tmp + ((alo & blo) ^ (alo & clo) ^ (blo & clo));
      t2_hi = (((ahi >> 28) | (alo << 4)) ^ ((alo >> 2) | (ahi << 30)) ^ ((alo >> 7) | (ahi << 25))) + ((ahi & bhi) ^ (ahi & chi) ^ (bhi & chi)) + select(0u, 1u, t2_lo < tmp);
      dlo += t1_lo;
      dhi += t1_hi + select(0u, 1u, dlo < t1_lo);
      hlo = t1_lo + t2_lo;
      hhi = t1_hi + t2_hi + select(0u, 1u, hlo < t1_lo);

      xhi = W[14];
      xlo = W[15];
      tx1_hi = ((xhi >> 19) | (xlo << 13)) ^ ((xlo >> 29) | (xhi << 3)) ^ (xhi >> 6);
      tx1_lo = ((xlo >> 19) | (xhi << 13)) ^ ((xhi >> 29) | (xlo << 3)) ^ ((xlo >> 6) | (xhi << 26));
      xhi = W[20];
      xlo = W[21];
      tx3_hi = ((xhi >> 1) | (xlo << 31)) ^ ((xhi >> 8) | (xlo << 24)) ^ (xhi >> 7);
      tx3_lo = ((xlo >> 1) | (xhi << 31)) ^ ((xlo >> 8) | (xhi << 24)) ^ ((xlo >> 7) | (xhi << 25));
      acc_lo = W[5] + W[19];
      acc_hi = W[4] + W[18] + select(0u, 1u, acc_lo < W[5]);
      acc_lo = acc_lo + tx1_lo;
      acc_hi = acc_hi + tx1_hi + select(0u, 1u, acc_lo < tx1_lo);
      acc_lo = acc_lo + tx3_lo;
      acc_hi = acc_hi + tx3_hi + select(0u, 1u, acc_lo < tx3_lo);
      W[18] = acc_hi;
      W[19] = acc_lo;

      t1_lo = glo + (((dlo >> 14) | (dhi << 18)) ^ ((dlo >> 18) | (dhi << 14)) ^ ((dhi >> 9) | (dlo << 23)));
      t1_hi = ghi + (((dhi >> 14) | (dlo << 18)) ^ ((dhi >> 18) | (dlo << 14)) ^ ((dlo >> 9) | (dhi << 23))) + select(0u, 1u, t1_lo < glo);
      tmp = (dlo & elo) ^ ((~dlo) & flo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((dhi & ehi) ^ ((~dhi) & fhi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 19];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i + 18] + select(0u, 1u, t1_lo < tmp);
      tmp = W[19];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + W[18] + select(0u, 1u, t1_lo < tmp);
      tmp = ((hlo >> 28) | (hhi << 4)) ^ ((hhi >> 2) | (hlo << 30)) ^ ((hhi >> 7) | (hlo << 25));
      t2_lo = tmp + ((hlo & alo) ^ (hlo & blo) ^ (alo & blo));
      t2_hi = (((hhi >> 28) | (hlo << 4)) ^ ((hlo >> 2) | (hhi << 30)) ^ ((hlo >> 7) | (hhi << 25))) + ((hhi & ahi) ^ (hhi & bhi) ^ (ahi & bhi)) + select(0u, 1u, t2_lo < tmp);
      clo += t1_lo;
      chi += t1_hi + select(0u, 1u, clo < t1_lo);
      glo = t1_lo + t2_lo;
      ghi = t1_hi + t2_hi + select(0u, 1u, glo < t1_lo);

      xhi = W[16];
      xlo = W[17];
      tx1_hi = ((xhi >> 19) | (xlo << 13)) ^ ((xlo >> 29) | (xhi << 3)) ^ (xhi >> 6);
      tx1_lo = ((xlo >> 19) | (xhi << 13)) ^ ((xhi >> 29) | (xlo << 3)) ^ ((xlo >> 6) | (xhi << 26));
      xhi = W[22];
      xlo = W[23];
      tx3_hi = ((xhi >> 1) | (xlo << 31)) ^ ((xhi >> 8) | (xlo << 24)) ^ (xhi >> 7);
      tx3_lo = ((xlo >> 1) | (xhi << 31)) ^ ((xlo >> 8) | (xhi << 24)) ^ ((xlo >> 7) | (xhi << 25));
      acc_lo = W[7] + W[21];
      acc_hi = W[6] + W[20] + select(0u, 1u, acc_lo < W[7]);
      acc_lo = acc_lo + tx1_lo;
      acc_hi = acc_hi + tx1_hi + select(0u, 1u, acc_lo < tx1_lo);
      acc_lo = acc_lo + tx3_lo;
      acc_hi = acc_hi + tx3_hi + select(0u, 1u, acc_lo < tx3_lo);
      W[20] = acc_hi;
      W[21] = acc_lo;

      t1_lo = flo + (((clo >> 14) | (chi << 18)) ^ ((clo >> 18) | (chi << 14)) ^ ((chi >> 9) | (clo << 23)));
      t1_hi = fhi + (((chi >> 14) | (clo << 18)) ^ ((chi >> 18) | (clo << 14)) ^ ((clo >> 9) | (chi << 23))) + select(0u, 1u, t1_lo < flo);
      tmp = (clo & dlo) ^ ((~clo) & elo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((chi & dhi) ^ ((~chi) & ehi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 21];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i + 20] + select(0u, 1u, t1_lo < tmp);
      tmp = W[21];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + W[20] + select(0u, 1u, t1_lo < tmp);
      tmp = ((glo >> 28) | (ghi << 4)) ^ ((ghi >> 2) | (glo << 30)) ^ ((ghi >> 7) | (glo << 25));
      t2_lo = tmp + ((glo & hlo) ^ (glo & alo) ^ (hlo & alo));
      t2_hi = (((ghi >> 28) | (glo << 4)) ^ ((glo >> 2) | (ghi << 30)) ^ ((glo >> 7) | (ghi << 25))) + ((ghi & hhi) ^ (ghi & ahi) ^ (hhi & ahi)) + select(0u, 1u, t2_lo < tmp);
      blo += t1_lo;
      bhi += t1_hi + select(0u, 1u, blo < t1_lo);
      flo = t1_lo + t2_lo;
      fhi = t1_hi + t2_hi + select(0u, 1u, flo < t1_lo);

      xhi = W[18];
      xlo = W[19];
      tx1_hi = ((xhi >> 19) | (xlo << 13)) ^ ((xlo >> 29) | (xhi << 3)) ^ (xhi >> 6);
      tx1_lo = ((xlo >> 19) | (xhi << 13)) ^ ((xhi >> 29) | (xlo << 3)) ^ ((xlo >> 6) | (xhi << 26));
      xhi = W[24];
      xlo = W[25];
      tx3_hi = ((xhi >> 1) | (xlo << 31)) ^ ((xhi >> 8) | (xlo << 24)) ^ (xhi >> 7);
      tx3_lo = ((xlo >> 1) | (xhi << 31)) ^ ((xlo >> 8) | (xhi << 24)) ^ ((xlo >> 7) | (xhi << 25));
      acc_lo = W[9] + W[23];
      acc_hi = W[8] + W[22] + select(0u, 1u, acc_lo < W[9]);
      acc_lo = acc_lo + tx1_lo;
      acc_hi = acc_hi + tx1_hi + select(0u, 1u, acc_lo < tx1_lo);
      acc_lo = acc_lo + tx3_lo;
      acc_hi = acc_hi + tx3_hi + select(0u, 1u, acc_lo < tx3_lo);
      W[22] = acc_hi;
      W[23] = acc_lo;

      t1_lo = elo + (((blo >> 14) | (bhi << 18)) ^ ((blo >> 18) | (bhi << 14)) ^ ((bhi >> 9) | (blo << 23)));
      t1_hi = ehi + (((bhi >> 14) | (blo << 18)) ^ ((bhi >> 18) | (blo << 14)) ^ ((blo >> 9) | (bhi << 23))) + select(0u, 1u, t1_lo < elo);
      tmp = (blo & clo) ^ ((~blo) & dlo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((bhi & chi) ^ ((~bhi) & dhi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 23];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i + 22] + select(0u, 1u, t1_lo < tmp);
      tmp = W[23];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + W[22] + select(0u, 1u, t1_lo < tmp);
      tmp = ((flo >> 28) | (fhi << 4)) ^ ((fhi >> 2) | (flo << 30)) ^ ((fhi >> 7) | (flo << 25));
      t2_lo = tmp + ((flo & glo) ^ (flo & hlo) ^ (glo & hlo));
      t2_hi = (((fhi >> 28) | (flo << 4)) ^ ((flo >> 2) | (fhi << 30)) ^ ((flo >> 7) | (fhi << 25))) + ((fhi & ghi) ^ (fhi & hhi) ^ (ghi & hhi)) + select(0u, 1u, t2_lo < tmp);
      alo += t1_lo;
      ahi += t1_hi + select(0u, 1u, alo < t1_lo);
      elo = t1_lo + t2_lo;
      ehi = t1_hi + t2_hi + select(0u, 1u, elo < t1_lo);

      xhi = W[20];
      xlo = W[21];
      tx1_hi = ((xhi >> 19) | (xlo << 13)) ^ ((xlo >> 29) | (xhi << 3)) ^ (xhi >> 6);
      tx1_lo = ((xlo >> 19) | (xhi << 13)) ^ ((xhi >> 29) | (xlo << 3)) ^ ((xlo >> 6) | (xhi << 26));
      xhi = W[26];
      xlo = W[27];
      tx3_hi = ((xhi >> 1) | (xlo << 31)) ^ ((xhi >> 8) | (xlo << 24)) ^ (xhi >> 7);
      tx3_lo = ((xlo >> 1) | (xhi << 31)) ^ ((xlo >> 8) | (xhi << 24)) ^ ((xlo >> 7) | (xhi << 25));
      acc_lo = W[11] + W[25];
      acc_hi = W[10] + W[24] + select(0u, 1u, acc_lo < W[11]);
      acc_lo = acc_lo + tx1_lo;
      acc_hi = acc_hi + tx1_hi + select(0u, 1u, acc_lo < tx1_lo);
      acc_lo = acc_lo + tx3_lo;
      acc_hi = acc_hi + tx3_hi + select(0u, 1u, acc_lo < tx3_lo);
      W[24] = acc_hi;
      W[25] = acc_lo;

      t1_lo = dlo + (((alo >> 14) | (ahi << 18)) ^ ((alo >> 18) | (ahi << 14)) ^ ((ahi >> 9) | (alo << 23)));
      t1_hi = dhi + (((ahi >> 14) | (alo << 18)) ^ ((ahi >> 18) | (alo << 14)) ^ ((alo >> 9) | (ahi << 23))) + select(0u, 1u, t1_lo < dlo);
      tmp = (alo & blo) ^ ((~alo) & clo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((ahi & bhi) ^ ((~ahi) & chi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 25];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i + 24] + select(0u, 1u, t1_lo < tmp);
      tmp = W[25];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + W[24] + select(0u, 1u, t1_lo < tmp);
      tmp = ((elo >> 28) | (ehi << 4)) ^ ((ehi >> 2) | (elo << 30)) ^ ((ehi >> 7) | (elo << 25));
      t2_lo = tmp + ((elo & flo) ^ (elo & glo) ^ (flo & glo));
      t2_hi = (((ehi >> 28) | (elo << 4)) ^ ((elo >> 2) | (ehi << 30)) ^ ((elo >> 7) | (ehi << 25))) + ((ehi & fhi) ^ (ehi & ghi) ^ (fhi & ghi)) + select(0u, 1u, t2_lo < tmp);
      hlo += t1_lo;
      hhi += t1_hi + select(0u, 1u, hlo < t1_lo);
      dlo = t1_lo + t2_lo;
      dhi = t1_hi + t2_hi + select(0u, 1u, dlo < t1_lo);

      xhi = W[22];
      xlo = W[23];
      tx1_hi = ((xhi >> 19) | (xlo << 13)) ^ ((xlo >> 29) | (xhi << 3)) ^ (xhi >> 6);
      tx1_lo = ((xlo >> 19) | (xhi << 13)) ^ ((xhi >> 29) | (xlo << 3)) ^ ((xlo >> 6) | (xhi << 26));
      xhi = W[28];
      xlo = W[29];
      tx3_hi = ((xhi >> 1) | (xlo << 31)) ^ ((xhi >> 8) | (xlo << 24)) ^ (xhi >> 7);
      tx3_lo = ((xlo >> 1) | (xhi << 31)) ^ ((xlo >> 8) | (xhi << 24)) ^ ((xlo >> 7) | (xhi << 25));
      acc_lo = W[13] + W[27];
      acc_hi = W[12] + W[26] + select(0u, 1u, acc_lo < W[13]);
      acc_lo = acc_lo + tx1_lo;
      acc_hi = acc_hi + tx1_hi + select(0u, 1u, acc_lo < tx1_lo);
      acc_lo = acc_lo + tx3_lo;
      acc_hi = acc_hi + tx3_hi + select(0u, 1u, acc_lo < tx3_lo);
      W[26] = acc_hi;
      W[27] = acc_lo;

      t1_lo = clo + (((hlo >> 14) | (hhi << 18)) ^ ((hlo >> 18) | (hhi << 14)) ^ ((hhi >> 9) | (hlo << 23)));
      t1_hi = chi + (((hhi >> 14) | (hlo << 18)) ^ ((hhi >> 18) | (hlo << 14)) ^ ((hlo >> 9) | (hhi << 23))) + select(0u, 1u, t1_lo < clo);
      tmp = (hlo & alo) ^ ((~hlo) & blo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((hhi & ahi) ^ ((~hhi) & bhi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 27];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i + 26] + select(0u, 1u, t1_lo < tmp);
      tmp = W[27];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + W[26] + select(0u, 1u, t1_lo < tmp);
      tmp = ((dlo >> 28) | (dhi << 4)) ^ ((dhi >> 2) | (dlo << 30)) ^ ((dhi >> 7) | (dlo << 25));
      t2_lo = tmp + ((dlo & elo) ^ (dlo & flo) ^ (elo & flo));
      t2_hi = (((dhi >> 28) | (dlo << 4)) ^ ((dlo >> 2) | (dhi << 30)) ^ ((dlo >> 7) | (dhi << 25))) + ((dhi & ehi) ^ (dhi & fhi) ^ (ehi & fhi)) + select(0u, 1u, t2_lo < tmp);
      glo += t1_lo;
      ghi += t1_hi + select(0u, 1u, glo < t1_lo);
      clo = t1_lo + t2_lo;
      chi = t1_hi + t2_hi + select(0u, 1u, clo < t1_lo);

      xhi = W[24];
      xlo = W[25];
      tx1_hi = ((xhi >> 19) | (xlo << 13)) ^ ((xlo >> 29) | (xhi << 3)) ^ (xhi >> 6);
      tx1_lo = ((xlo >> 19) | (xhi << 13)) ^ ((xhi >> 29) | (xlo << 3)) ^ ((xlo >> 6) | (xhi << 26));
      xhi = W[30];
      xlo = W[31];
      tx3_hi = ((xhi >> 1) | (xlo << 31)) ^ ((xhi >> 8) | (xlo << 24)) ^ (xhi >> 7);
      tx3_lo = ((xlo >> 1) | (xhi << 31)) ^ ((xlo >> 8) | (xhi << 24)) ^ ((xlo >> 7) | (xhi << 25));
      acc_lo = W[15] + W[29];
      acc_hi = W[14] + W[28] + select(0u, 1u, acc_lo < W[15]);
      acc_lo = acc_lo + tx1_lo;
      acc_hi = acc_hi + tx1_hi + select(0u, 1u, acc_lo < tx1_lo);
      acc_lo = acc_lo + tx3_lo;
      acc_hi = acc_hi + tx3_hi + select(0u, 1u, acc_lo < tx3_lo);
      W[28] = acc_hi;
      W[29] = acc_lo;

      t1_lo = blo + (((glo >> 14) | (ghi << 18)) ^ ((glo >> 18) | (ghi << 14)) ^ ((ghi >> 9) | (glo << 23)));
      t1_hi = bhi + (((ghi >> 14) | (glo << 18)) ^ ((ghi >> 18) | (glo << 14)) ^ ((glo >> 9) | (ghi << 23))) + select(0u, 1u, t1_lo < blo);
      tmp = (glo & hlo) ^ ((~glo) & alo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((ghi & hhi) ^ ((~ghi) & ahi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 29];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i + 28] + select(0u, 1u, t1_lo < tmp);
      tmp = W[29];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + W[28] + select(0u, 1u, t1_lo < tmp);
      tmp = ((clo >> 28) | (chi << 4)) ^ ((chi >> 2) | (clo << 30)) ^ ((chi >> 7) | (clo << 25));
      t2_lo = tmp + ((clo & dlo) ^ (clo & elo) ^ (dlo & elo));
      t2_hi = (((chi >> 28) | (clo << 4)) ^ ((clo >> 2) | (chi << 30)) ^ ((clo >> 7) | (chi << 25))) + ((chi & dhi) ^ (chi & ehi) ^ (dhi & ehi)) + select(0u, 1u, t2_lo < tmp);
      flo += t1_lo;
      fhi += t1_hi + select(0u, 1u, flo < t1_lo);
      blo = t1_lo + t2_lo;
      bhi = t1_hi + t2_hi + select(0u, 1u, blo < t1_lo);

      xhi = W[26];
      xlo = W[27];
      tx1_hi = ((xhi >> 19) | (xlo << 13)) ^ ((xlo >> 29) | (xhi << 3)) ^ (xhi >> 6);
      tx1_lo = ((xlo >> 19) | (xhi << 13)) ^ ((xhi >> 29) | (xlo << 3)) ^ ((xlo >> 6) | (xhi << 26));
      xhi = W[0];
      xlo = W[1];
      tx3_hi = ((xhi >> 1) | (xlo << 31)) ^ ((xhi >> 8) | (xlo << 24)) ^ (xhi >> 7);
      tx3_lo = ((xlo >> 1) | (xhi << 31)) ^ ((xlo >> 8) | (xhi << 24)) ^ ((xlo >> 7) | (xhi << 25));
      acc_lo = W[17] + W[31];
      acc_hi = W[16] + W[30] + select(0u, 1u, acc_lo < W[17]);
      acc_lo = acc_lo + tx1_lo;
      acc_hi = acc_hi + tx1_hi + select(0u, 1u, acc_lo < tx1_lo);
      acc_lo = acc_lo + tx3_lo;
      acc_hi = acc_hi + tx3_hi + select(0u, 1u, acc_lo < tx3_lo);
      W[30] = acc_hi;
      W[31] = acc_lo;

      t1_lo = alo + (((flo >> 14) | (fhi << 18)) ^ ((flo >> 18) | (fhi << 14)) ^ ((fhi >> 9) | (flo << 23)));
      t1_hi = ahi + (((fhi >> 14) | (flo << 18)) ^ ((fhi >> 18) | (flo << 14)) ^ ((flo >> 9) | (fhi << 23))) + select(0u, 1u, t1_lo < alo);
      tmp = (flo & glo) ^ ((~flo) & hlo);
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + ((fhi & ghi) ^ ((~fhi) & hhi)) + select(0u, 1u, t1_lo < tmp);
      tmp = K[i + 31];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + K[i + 30] + select(0u, 1u, t1_lo < tmp);
      tmp = W[31];
      t1_lo = t1_lo + tmp;
      t1_hi = t1_hi + W[30] + select(0u, 1u, t1_lo < tmp);
      tmp = ((blo >> 28) | (bhi << 4)) ^ ((bhi >> 2) | (blo << 30)) ^ ((bhi >> 7) | (blo << 25));
      t2_lo = tmp + ((blo & clo) ^ (blo & dlo) ^ (clo & dlo));
      t2_hi = (((bhi >> 28) | (blo << 4)) ^ ((blo >> 2) | (bhi << 30)) ^ ((blo >> 7) | (bhi << 25))) + ((bhi & chi) ^ (bhi & dhi) ^ (chi & dhi)) + select(0u, 1u, t2_lo < tmp);
      elo += t1_lo;
      ehi += t1_hi + select(0u, 1u, elo < t1_lo);
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
}

@group(0) @binding(0) var<storage, read> input: array<u32>;
@group(0) @binding(1) var<storage, read_write> output: array<u32>;

const masks = array<u32, 4>(0x00ffffff, 0xff00ffff, 0xffff00ff, 0xffffff00);
fn setByteArr(arr: ptr<function, array<u32, 32>>, idx: u32, byte: u32) {
  let i = idx/4;
  let sh = idx%4;
  arr[i] = (arr[i] & masks[sh]) + (byte << (24 - sh * 8));
}

const MAX_PASSWORD_LEN: u32 = 128 - 9; // 0x00000001 (4 bytes) 0x80 (1 byte) %%seed bits%% (4 bytes)


fn initSeeds(tmp_buf: ptr<function, array<u32, 32>>, seed1: ptr<function, array<u32, 16>>, seed2: ptr<function, array<u32, 16>>) {
  var IV = array<u32,16>(
      0x6a09e667, 0xf3bcc908, 0xbb67ae85, 0x84caa73b,
      0x3c6ef372, 0xfe94f82b, 0xa54ff53a, 0x5f1d36f1,
      0x510e527f, 0xade682d1, 0x9b05688c, 0x2b3e6c1f,
      0x1f83d9ab, 0xfb41bd6b, 0x5be0cd19, 0x137e2179,
  );
  for (var i: u32 = 0u; i < 32u; i += 1u) { tmp_buf[i] = input[i] ^ 0x36363636; }
  sha512(tmp_buf, &IV);
  for (var i: u32 = 0u; i < 16u; i += 1u) { seed1[i] = tmp_buf[i]; }
  for (var i: u32 = 0u; i < 32u; i += 1u) { tmp_buf[i] = input[i] ^ 0x5c5c5c5c; }
  sha512(tmp_buf, &IV);
  for (var i: u32 = 0u; i < 16u; i += 1u) { seed2[i] = tmp_buf[i]; }
}

fn initBuffer(tmp_buf: ptr<function, array<u32, 32>>, seed1: ptr<function, array<u32, 16>>, seed2: ptr<function, array<u32, 16>>, gidX: u32) {
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
  sha512(tmp_buf, seed1);

  for (var i = 16; i < 32; i += 1) { tmp_buf[i] = 0; }
  tmp_buf[16] = 0x80000000;
  tmp_buf[31] = 192 * 8;
  sha512(tmp_buf, seed2);
}

@compute @workgroup_size(WORKGROUP_SIZE)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
  var tmp_buf: array<u32, 32>;
  var seed1: array<u32, 16>;
  var seed2: array<u32, 16>;
  var dk: array<u32, 16>;
  initSeeds(&tmp_buf, &seed1, &seed2);
  initBuffer(&tmp_buf, &seed1, &seed2, gid.x);

  for (var i = 0; i < 16; i += 1) { dk[i] = tmp_buf[i]; }

  for (var i = 1; i < 2048; i += 1) {

      tmp_buf[16] = 0x80000000;
      for (var i = 17; i < 31; i += 1) { tmp_buf[i] = 0; }
      tmp_buf[31] = 192 * 8;
      sha512(&tmp_buf, &seed1);

      tmp_buf[16] = 0x80000000;
      for (var i = 17; i < 31; i += 1) { tmp_buf[i] = 0; }
      tmp_buf[31] = 192 * 8;
      sha512(&tmp_buf, &seed2);

      for (var i = 0; i < 16; i += 1) { dk[i] ^= tmp_buf[i]; }
  }

  for (var i: u32 = 0; i < 16; i += 1) {
    output[gid.x * 16u + i] = dk[i];
  }
}
