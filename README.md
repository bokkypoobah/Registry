# Registry

See https://bokkypoobah.github.io/Registry/

<br />

---

## Testing

Testing script [test/Registry.js](test/Registry.js), executed using [10_testIt.sh](10_testIt.sh), with output in [testIt.out](testIt.out):

* [x] [contracts/RegistryReceiver](contracts/Registry.sol)
  * [x] Cannot send ETH to RegistryReceiver
  * [x] Can send null data to RegistryReceiver
  * [x] Cannot send duplicate to RegistryReceiver
* [ ] [contracts/Registry](contracts/Registry.sol)
  * [x] Confirm only RegistryReceiver can register
  * [x] Confirm `ownerOf(tokenId)` works
  * [x] Confirm `length()` works
  * [x] Confirm owner can transfer own tokens
  * [x] Confirm non-owner cannot transfer tokens
  * [x] Confirm `setApprovalForAll(...)` works
  * [x] Confirm `isApprovedForAll(...)` works
  * [ ] Check remaining readonly functions. Lower priority as these are used otherwise
* [ ] [contracts/RegistryExchange](contracts/RegistryExchange.sol)
  * [ ] Owned
    * [ ] Confirm `transferOwnership(...)` can only be executed by `owner`
    * [ ] Confirm `acceptOwnership()` can only be executed by `newOwner`
    * [ ] Confirm `withdraw(...)` for partial and full ERC-20 and ETH withdrawals
  * [ ] ReentrancyGuard
    * [ ] Confirm `reentrancyGuard()` works
  * [ ] Confirm `offer(...)` and `buy(...)` works as expected
    * [ ] Confirm invalid orders cannot be executed
    * [ ] Confirm expired orders cannot be executed
    * [ ] Confirm order is removed after trade
  * [ ] Confirm `bid(...)` and `sell(...)` works as expected
    * [ ] Confirm invalid orders cannot be executed
    * [ ] Confirm expired orders cannot be executed
    * [ ] Confirm order is removed after trade
  * [ ] Confirm `bulkTransfer(...)` works as expected
  * [ ] Confirm `updateFee(...)` works as expected
    * [ ] Cannot set above `MAX_FEE`
    * [ ] Non-owner cannot set
    * [ ] Change amount takes effect
* [ ] Happy Path
  * [ ] Register new items
  * [ ] Transfer new items
  * [ ] Confirm items exchanged
  * [ ] Confirm fees are correct
* [ ] Low Priority
  * [ ] Confirm RegistryReceiver tokenId returned as `output`. Lower priority as we don't want smart contracts to call this contract anyway

<br />

<br />

---

https://hardhat.org/hardhat-runner/docs/guides/project-setup

npm install --save-dev hardhat

https://www.npmjs.com/package/hardhat-gas-reporter

npm install hardhat-gas-reporter --save-dev
