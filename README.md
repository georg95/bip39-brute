# bip39 wallet recovery tool

This tool can recover partially lost seed phrase or password-protected seed phrase. <br>
You have to know wallet address. It supports `bitcoin, ethereum, tron, usdt, usdc, solana` addresses.<br>
It works in browser on GPU (WebGPU) - check bruteforce speed with [benchmark](https://georg95.github.io/bip39-brute/benchmark.html)<br>

## [App page](https://georg95.github.io/bip39-brute/index.html)

## partial mnemonic mode
Provide partially known seed phrase like this:<br>
`obscure prepare,prize source same render oven version practice s???? ??? ?????? *`<br>
Where<br>
`*` - any word<br>
`s*k` - word that start with `s` and ends with `k`<br>
`s????k` - word of 6 letters that start with `s` and ends with `k`<br>
`prepare,prize` - one of these words<br>
`s????k,p????k,prize` - you can mix not only words, bit word masks with `,`<br>
<br>
The reason for word masks instead of `*` everywhere - it greatly reduces time needed for recovery<br>
<br>
If you also used password with mnemonic, provide it in settings<br>

## password recovery mode
Provide seed phrase like this:<br>
`rhythm setup entire behave noble stairs fossil walk prize library mystery forget`<br>
And use either default password lists, or provide txt file with possible passwords.


<details>
<summary>It can work offline</summary>
Not for default list in password recovery mode - you should provide passwords dictionary file then
</details>

## Test examples:
[1. Recover password for known mnemonic](https://georg95.github.io/bip39-brute/index.html?state=eyJsaXN0IjoiMURIU2ZoaW00VFlndEFhM3RWM001S0ZkQVZmcG9GSmpxTCIsImJpcCI6ImZpbmUgcHJvZ3JhbSBwdW5jaCBkZWZlbnNlIGJldHRlciBpY29uIHNwb3QgcmFkYXIgbm9ibGUgcmVndWxhciB2aWV3IGNhdXNlIn0%3D)
<details>
Mnemonic:

<code>fine program punch defense better icon spot radar noble regular view cause</code>

Known bitcoin address, the only address in wallet (m/44'/0'/0'/0/0):

<code>1DHSfhim4TYgtAa3tV3M5KFdAVfpoFJjqL</code>
<details>
<summary>Password:</summary>gauffers
</details>
</details>

[2. Recover mnemonic with 2 missing words](https://georg95.github.io/bip39-brute/index.html?state=eyJsaXN0IjoiMHgxQjFmZDVlNTgyQTRhNTUwMzM5NDkxMjkyZkE0NUE3QjBkNzkxNDQwIiwiYmlwIjoiY3VyaW91cyBzdGFydCAqICogYmVzdCBodW50IHZldGVyYW4gcmVncmV0IGRpbGVtbWEgZ3JlZW4gdmFuIHF1ZXN0aW9uIn0%3D)
<details>
Mnemonic without 2 words:

<code>curious start * * best hunt veteran regret dilemma green van question</code>

Known ethereum address, the only address in wallet (m/44'/60'/0'/0/0):

<code>0x1B1fd5e582A4a550339491292fA45A7B0d791440</code>
<details>
<summary>Recovered mnemonic:</summary>curious start desk message best hunt veteran regret dilemma green van question
</details>
</details>

[3. Recover mnemonic, when derivation path not known](https://georg95.github.io/bip39-brute/index.html?state=eyJsaXN0IjoiYmMxcWc3NGpjaDA4dXlqcWh1bjRsbXgwMDVkY3g5eHhjMjYzcGZqa2YyXG5iYzFxZ3h4d2VheHhobWVtbnRybnd1anNmdzV5MGRsNndyczB3eGw3bmoiLCJiaXAiOiJpbnRvIGR1bWIgcHVsc2UgZHJvcCBtZWF0IHNsb3cgKiAqIGxpc3QgcmljZSB0aW1iZXIgY2FzaW5vIiwiZGVyaXZlIjoxNn0%3D)
<details>
Mnemonic without 2 words:

<code>into dumb pulse drop meat slow * * list rice timber casino</code>

Known bitcoin addresses, but not first used in wallet (11th anf 14th in this case):

<code>bc1qg74jch08uyjqhun4lmx005dcx9xxc263pfjkf2
bc1qgxxweaxxhmemntrnwujsfw5y0dl6wrs0wxl7nj</code>
<details>
<summary>Recovered mnemonic:</summary>into dumb pulse drop meat slow can inspire list rice timber casino
</details>
</details>


[4. Recover mnemonic, whith partially known words](https://georg95.github.io/bip39-brute/index.html?state=eyJsaXN0IjoiMHhEY0I1OUExMUVjNzliYzE3NTFlRjRENEQ0ZDcyNDNiODNjMkRjNzBFIiwiYmlwIjoic3Bvb24sc2NvdXQgZGVzZXJ0IGF1dGhvciBhc3NhdWx0IHBhbmljIGJ1c2luZXNzIGJsaW5kIGZpbHRlciBzaGVsbCBtaXggb2theSBqdW5pb3IgY2lyY2xlIGp1bmsgdGhhbmsgc3dpbmcgcmFjZSBiZXR3ZWVuIHJlcGVhdCBtYXJjaCBzPz8%2FPyA%2FPz8gPz8%2FPz8%2FID8%2FPz8%2FZCIsImRlcml2ZSI6MTZ9)
<details>
You forgot if 1st word is <code>spoon</code> or <code>scout</code>, and remember partially last 4 words - only that they were 5, 3, 6, 6 characters length, first start with s, last start with d:

<code>spoon,scout desert author assault panic business blind filter shell mix okay junior circle junk thank swing race between repeat march s???? ??? ?????? ?????d</code>

Known ethereum addresses:

<code>0xDcB59A11Ec79bc1751eF4D4D4d7243b83c2Dc70E</code>
<details>
<summary>Recovered mnemonic:</summary>scout desert author assault panic business blind filter shell mix okay junior circle junk thank swing race between repeat march spoon win symbol around
</details>
</details>

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
- [x] Save current settings & progress
- [x] Links for recovery state
- [x] Readme docs and examples
- [ ] Better benchmarks
- [ ] Naming project
- [ ] Optimize performance
