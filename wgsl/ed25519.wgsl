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

struct u64 { hi: u32, lo: u32 };

@group(0) @binding(0) var<storage, read> input: array<u32>;
@group(0) @binding(1) var<storage, read_write> output: array<u32>;
@group(0) @binding(2) var<storage, read> prec_table: array<u32>;

@compute @workgroup_size(WORKGROUP_SIZE)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
  var p: array<u32, 8>;
  for (var i = 0u; i < 8u; i++) {
    p[i] = input[gid.x*8+i];
  }
  var p10: array<u32, 10>;

  load26x10(&p, &p10);
  store26x10(&p10, gid.x*8);
}
