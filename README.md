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
  * [x] Can burn and resubmit same data
* [x] [contracts/Registry](contracts/Registry.sol)
  * [x] Only RegistryReceiver can register
  * [x] `ownerOf(tokenId)` works
  * [x] `length()` works
  * [x] Owner can transfer own tokens
  * [x] Non-owner cannot transfer tokens
  * [x] `setApprovalForAll(...)` works
  * [x] `isApprovedForAll(...)` works
* [ ] [contracts/RegistryExchange](contracts/RegistryExchange.sol)
  * [x] Owned
    * [x] `transferOwnership(...)` can only be executed by `owner`
    * [x] `acceptOwnership()` can only be executed by `newOwner`
    * [x] `withdraw(...)` can only be called by `owner`
    * [ ] `updateFeeAccount(...)`
  * [x] `bulkTransfer(...)`
    * [x] Can only `bulkTransfer(...)` own items
  * [x] `updateFee(...)` and `withdraw(...)`
    * [x] `updateFee(...)` can only be called by owner
    * [x] Cannot `updateFee(...)` above `MAX_FEE`
    * [x] `updateFee(...)` updated amount takes effect for ETH trades
    * [x] `updateFee(...)` updated amount takes effect for WETH trades
    * [x] `withdraw(...)` for partial ERC-20 and ETH withdrawals
    * [x] `withdraw(...)` for full ERC-20 and ETH withdrawals
  * [ ] `offer(...)` and `buy(...)`
    * [ ] Confirm valid order on tokens not owned cannot be executed
    * [ ] Confirm invalid orders cannot be executed
    * [ ] Confirm expired orders cannot be executed
    * [ ] Confirm order is removed after trade
    * [ ] Confirm fees are correct for uiFeeAccount = null or not
  * [ ] `bid(...)` and `sell(...)`
    * [ ] Confirm valid order on tokens not owned cannot be executed
    * [ ] Confirm invalid orders cannot be executed
    * [ ] Confirm expired orders cannot be executed
    * [ ] Confirm order is removed after trade
    * [ ] Confirm fees are correct for uiFeeAccount = null or not
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
