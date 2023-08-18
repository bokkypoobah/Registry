# Registry

See https://bokkypoobah.github.io/Registry/

<br />

---

### Testing

Testing script [test/Registry.js](test/Registry.js), executed using [10_testIt.sh](10_testIt.sh), with output in [testIt.out](testIt.out):

* [x] [contracts/RegistryReceiver](contracts/Registry.sol)
  * [x] Cannot send ETH to RegistryReceiver
  * [x] Can send null data to RegistryReceiver
  * [x] Cannot send duplicate to RegistryReceiver
* [x] [contracts/Registry](contracts/Registry.sol)
  * [x] Confirm only RegistryReceiver can register
  * [x] Confirm `ownerOf(tokenId)` works
  * [x] Confirm `length()` works
  * [x] Confirm owner can transfer own tokens
  * [x] Confirm non-owner cannot transfer tokens
  * [x] Confirm `setApprovalForAll(...)` works
  * [x] Confirm `isApprovedForAll(...)` works
* [ ] [contracts/RegistryExchange](contracts/RegistryExchange.sol)
  * [x] Owned
    * [x] Confirm `transferOwnership(...)` can only be executed by `owner`
    * [x] Confirm `acceptOwnership()` can only be executed by `newOwner`
    * [x] Confirm `withdraw(...)` can only be called by `owner`
  * [x] `bulkTransfer(...)`
    * [x] Confirm can only `bulkTransfer(...)` own items
  * [x] `updateFee(...)` and `withdraw(...)`
    * [x] Confirm `updateFee(...)` can only be called by owner
    * [x] Cannot set above `MAX_FEE`
    * [x] Confirm `updateFee(...)` changed amount takes effect for ETH trades
    * [x] Confirm `updateFee(...)` changed amount takes effect for WETH trades
    * [x] Confirm `withdraw(...)` for partial ERC-20 and ETH withdrawals
    * [x] Confirm `withdraw(...)` for full ERC-20 and ETH withdrawals
  * [ ] Confirm `offer(...)` and `buy(...)` works as expected
    * [ ] Confirm invalid orders cannot be executed
    * [ ] Confirm expired orders cannot be executed
    * [ ] Confirm order is removed after trade
  * [ ] Confirm `bid(...)` and `sell(...)` works as expected
    * [ ] Confirm invalid orders cannot be executed
    * [ ] Confirm expired orders cannot be executed
    * [ ] Confirm order is removed after trade
  * [ ] ReentrancyGuard
    * [ ] Confirm `reentrancyGuard()` works
* [ ] Happy Path
  * [ ] Register new items
  * [ ] Transfer new items
  * [ ] Confirm items exchanged
  * [ ] Confirm fees are correct
* [ ] Low Priority
  * [ ] Confirm RegistryReceiver tokenId returned as `output`. Lower priority as we don't want smart contracts to call this contract anyway
  * [ ] Check remaining Registry readonly functions. Lower priority as these are used otherwise

<br />

### Notes

* Reentrancy is mainly an issue in the `buy(...)` function when sending back any ETH refunds that could trigger a callback

<br />

### TODO

* Check event logs are sufficient for accounting

<br />

<br />

---

https://hardhat.org/hardhat-runner/docs/guides/project-setup

npm install --save-dev hardhat

https://www.npmjs.com/package/hardhat-gas-reporter

npm install hardhat-gas-reporter --save-dev
