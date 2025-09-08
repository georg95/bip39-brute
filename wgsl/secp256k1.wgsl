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

@group(0) @binding(0) var<storage, read> input: array<u32>;
@group(0) @binding(1) var<storage, read_write> output: array<u32>;
@compute @workgroup_size(1)
fn main() {
  let G256x: array<u32, 8> = array<u32, 8>(0xeb9a9787, 0x92f76cc4, 0x59599680, 0x89bdde81, 0xbbd3788d, 0x74669716, 0xef5ba060, 0xdd3625fa);
  var G256x10: array<u32, 10>;
  load26x10(&G256x, &G256x10);
  output[0] = 1u;

  for (var i: u32 = 0; i < 10; i++) {
    output[i] = G256x10[i];
  }
}
