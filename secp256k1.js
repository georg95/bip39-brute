const P = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2fn;
const u8n = (len) => new Uint8Array(len);
const concatBytes = (...arrs) => {
    const r = u8n(arrs.reduce((sum, a) => sum + a.length, 0)); // create u8a of summed length
    let pad = 0; // walk through each array,
    arrs.forEach(a => { r.set(a, pad); pad += a.length; }); // ensure they have proper type
    return r;
};
const M = (a, b = P) => {
    const r = a % b;
    return r >= 0n ? r : b + r;
};

const invert = (num) => {
    let a = M(num, P), b = P, x = 0n, y = 1n, u = 1n, v = 0n;
    while (a !== 0n) {
        const q = b / a, r = b % a;
        const m = x - u * q, n = y - v * q;
        b = a, a = r, x = u, y = v, u = m, v = n;
    }
    return M(x, P);
};
const isEven = (y) => (y & 1n) === 0n;
const u8of = (n) => Uint8Array.of(n);
const getPrefix = (y) => u8of(isEven(y) ? 0x02 : 0x03);

class Point {
    X;
    Y;
    Z;
    constructor(X, Y, Z) {
        this.X = X;
        this.Y = Y;
        this.Z = Z;
    }
    add(other) {
        const { X: X1, Y: Y1, Z: Z1 } = this;
        const { X: X2, Y: Y2, Z: Z2 } = other;
        let X3 = 0n, Y3 = 0n, Z3 = 0n;
        let t0 = M(X1 * X2);
        let t1 = M(Y1 * Y2);
        let t2 = M(Z1 * Z2);
        let t3 = M(X1 + Y1);
        let t4 = M(X2 + Y2);
        let t5 = M(X2 + Z2); // step 1
        t3 = M(t3 * t4);
        t4 = M(t0 + t1);
        t3 = M(t3 - t4);
        t4 = M(X1 + Z1);
        t4 = M(t4 * t5);
        t5 = M(t0 + t2);
        t4 = M(t4 - t5);
        t5 = M(Y1 + Z1);
        X3 = M(Y2 + Z2); // step 15
        t5 = M(t5 * X3);
        X3 = M(t1 + t2);
        t5 = M(t5 - X3);
        t2 = M(21n * t2); // step 20
        X3 = M(t1 - t2);
        Z3 = M(t1 + t2);
        Y3 = M(X3 * Z3);
        t1 = M(t0 + t0); // step 25
        t1 = M(t1 + t0);
        t4 = M(21n * t4);
        t0 = M(t1 * t4);
        Y3 = M(Y3 + t0);
        t0 = M(t5 * t4); // step 35
        X3 = M(t3 * X3);
        X3 = M(X3 - t0);
        t0 = M(t3 * t1);
        Z3 = M(t5 * Z3);
        Z3 = M(Z3 + t0); // step 40
        return new Point(X3, Y3, Z3);
    }
    toAffine() {
        const { X: x, Y: y, Z: z } = this;
        if (z === 1n)
            return { x, y };
        const iz = invert(z, P);
        if (M(z * iz) !== 1n)
            err('inverse invalid');
        return { x: M(x * iz), y: M(y * iz) };
    }
    negate() {
        return new Point(this.X, M(-this.Y), this.Z);
    }
    print(name) {
        console.log(`=== ${name}\nx:`, '0x'+this.X.toString(16), '\ny:', '0x'+this.Y.toString(16), '\nz:', '0x'+this.Z.toString(16));
    }
}
const fromHexString = (hexString) => Uint8Array.from(hexString.match(/.{1,2}/g).map((byte) => parseInt(byte, 16)));
const G = new Point(0x79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798n, 0x483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8n, 1n);
const I = new Point(0n, 1n, 0n);
const getPublicKey = (privKey, isCompressed=true) => {
    const { X: x, Y: y, Z: z } = wNAF(privKey);
    const iz = invert(z);
    const x32b = fromHexString(M(x * iz).toString(16).padStart(64, '0'));
    if (isCompressed)        
        return concatBytes(getPrefix(M(y * iz)), x32b);
    const y32b = fromHexString(M(y * iz).toString(16).padStart(64, '0'))
    return concatBytes(u8of(0x04), x32b, y32b);
};
const W = 8; // W is window size
const precompute = (W, onBatch) => {
    function toAff(pt) {
      const { x, y } = pt.toAffine()
      return new Point(x, y, 1n)
    }
    function batchAff(pointsBatch) {
      let acc = 1n
      const scratch = [1n].concat(pointsBatch.map(ni => acc = (acc * ni.Z) % P))
      let inv = invert(acc)
      const Zinv = new Array(pointsBatch.length);
      for (let i = pointsBatch.length - 1; i >= 0; i--) {
        Zinv[i] = (scratch[i] * inv) % P
        inv = (inv * pointsBatch[i].Z) % P
      }
      return Zinv.map((iz, i) => new Point(M(pointsBatch[i].X * iz), M(pointsBatch[i].Y * iz), 1n));
    }
    var points = [];
    let p = G;
    let b = p;
    for (let w = 0; w < Math.ceil(256 / W); w++) {
        b = p
        var pointsBatch = []
        pointsBatch.push(b);
        for (let i = 1; i < 2 ** (W - 1); i++) {
            b = b.add(p);
            pointsBatch.push(b);
        }
        if (onBatch) {
          onBatch(batchAff(pointsBatch), w)
        } else {
          points = points.concat(batchAff(pointsBatch))
        }
        p = toAff(b.add(b));
    }
    return points;
};
let Gpows; // precomputes for base point G

const G256 = new Point(100056811408208733275829432225571761443897154861420255832015183193056831248263n,
  55225563209553524050574769423916742683973132338171759239001668957831436739955n, 1n)
const wNAF = (n) => {
    if (!Gpows) { Gpows = precompute(W) }
    let p = I;
    const mask = BigInt(2 ** W - 1); // 255 for W=8 == mask 0b11111111
    const shiftBy = BigInt(W); // 8 for W=8
    const ONE = 1n;
    const WIN_SIZE = 2 ** (W - 1);
    const pwindows = Math.ceil(256 / W);
    for (let w = 0; w < pwindows; w++) {
        let wbits = Number(n & mask); // extract W bits.
        n >>= shiftBy; // shift number by W bits.
        if (wbits > WIN_SIZE) {
            wbits -= 256;
            n += ONE;
        }
        const off = w * WIN_SIZE;
        if (wbits !== 0) {
            const offP = off + Math.abs(wbits) - 1;
            p = p.add(wbits < 0 ? Gpows[offP].negate() : Gpows[offP]); // bits are 1: add to result point
        }
    }
    if (n === 1n) { p = p.add(G256) }
    return p; // return both real and fake points for JIT
};