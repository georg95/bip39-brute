# WebGPU Bitcoin bip39 seed mnemonic recovery

## [GPU Benchmark](https://georg95.github.io/bip39-brute/benchmark.html)

## [App page (GPU)](https://georg95.github.io/bip39-brute/index.html)

Test data, mnemonic:
```
expose census trophy review common rebel ask depend build caught frame accident naive shiver inmate host assault fan tonight accident left useful tongue blood
```
Test data, address list (m/44'/0'/0'/0/0, m/44'/0'/0'/0/1):
```
1PKkTsFscAharNGTvpAz5JbyztmcDkSa3Y
1E8NiS2eqpAnfDxYk1Bjc4XMC5Ldyat6Hk
```
Password: gauffers (usernames.txt password list)

### Supported addresses:

- [x] Bitcoin legacy (p2pkh) m/44'/0'/0'/0/x
- [x] Bitcoin segwit (p2wphk) m/84'/0'/0'/0/x
- [x] Bitcoin script (p2sh) m/49'/0'/0'/0/x
- [x] Ethereum, BSC, Arbitrum, Poligon, Optimism m/44'/60'/0'/0/x
- [x] Tron m/44'/195'/0'/0/x
- [x] Solana m/44'/501'/0'/x'

### To support:

- [ ] Ripple
- [ ] Dogecoin
- [ ] Litecoin
- [ ] Cardano
- [ ] Bitcoin electrum
- [ ] Bitcoin core/multibit
- [ ] Solana 2 m/44'/501'/x'
- [ ] Solana legacy m/44'/501'/0'/0/x

### TODO:

- [x] Password bruteforce mode
- [x] Missing words bruteforce mode
- [x] Legacy/P2SH/Segwit bitcoin addresses
- [x] Ethereum/BSC/Tron wallets
- [x] Solana wallets
- [x] Multiple derivation addresses
- [x] 12/15/18/24 words support
- [x] More than 4 billion permutation support
- [x] Partial word masks
- [x] Read passwords from file
- [x] Passphrase for mask recovery mode
- [x] Shaders compilation progress
- [ ] Save current settings & progess
- [ ] Links for recovery state
- [ ] Readme docs and examples
- [ ] Better benchmarks
- [ ] Naming project
- [ ] Optimize performance
