# Registry

See https://bokkypoobah.github.io/Registry/

<br />

---

## Testing

* [ ] RegistryReceiver
  * [ ] Confirm unable to send ETH  
  * [ ] Confirm tokenId returned as `output`
* [ ] Registry
  * [ ] Confirm only RegistryReceiver can register
  * [ ] Confirm rejection for duplicate hashes
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
  * [ ] Confirm `bid(...)` and `sell(...)` works as expected
  * [ ] Confirm `bulkTransfer(...)` works as expected
  * [ ] Confirm `updateFee(...)` works as expected
    * [ ] Cannot set above `MAX_FEE`
    * [ ] Non-owner cannot set
    * [ ] Change amount takes effect

<br />

<br />

---

https://hardhat.org/hardhat-runner/docs/guides/project-setup

npm install --save-dev hardhat

https://www.npmjs.com/package/hardhat-gas-reporter

npm install hardhat-gas-reporter --save-dev
