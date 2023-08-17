# Registry

See https://bokkypoobah.github.io/Registry/

<br />

---

## Testing

* [ ] RegistryReceiver
  * [x] Cannot send ETH to RegistryReceiver
  * [x] Can send null data to RegistryReceiver
  * [x] Cannot send duplicate to RegistryReceiver
  * [ ] TODO LOW Confirm tokenId returned as `output`. Lower priority as we don't want smart contracts to call this contract
* [ ] Registry
  * [x] Confirm only RegistryReceiver can register
  * [ ] Confirm `ownerOf(tokenId)` works
  * [ ] Confirm `length()` works
  * [ ] Confirm `setApprovalForAll(...)` works
  * [ ] Confirm `isApprovedForAll(...)` works
  * [ ] Confirm that non-owner and non-approved cannot transfer tokens
* [ ] RegistryExchange
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

<br />

<br />

---

https://hardhat.org/hardhat-runner/docs/guides/project-setup

npm install --save-dev hardhat

https://www.npmjs.com/package/hardhat-gas-reporter

npm install hardhat-gas-reporter --save-dev
