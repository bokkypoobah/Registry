# Registry

See https://bokkypoobah.github.io/Registry/

<br />

---

### Testing

Testing script [test/Registry.js](test/Registry.js), executed using [10_testIt.sh](10_testIt.sh), with output in [testIt.out](testIt.out):

* [ ] [contracts/Registry](contracts/Registry.sol)
  * [ ] RegistryReceiver
    * [ ] Only RegistryReceiver can register
    * [ ] `ownerOf(tokenId)` works
    * [ ] `length()` works
    * [ ] Owner can transfer own tokens
    * [ ] Non-owner cannot transfer tokens
    * [ ] `setApprovalForAll(...)` works
    * [ ] `isApprovedForAll(...)` works
  * [ ] Default Collection
    * [ ] Any user can create new items
    * [ ] Any user can remove their items
    * [ ] Cannot send ETH to RegistryReceiver
    * [ ] Can send null data to RegistryReceiver
    * [ ] Cannot send duplicate to RegistryReceiver
    * [ ] Can burn and resubmit same data
  * [ ] Named Collections
    * [ ] Can create new items
      * [ ] Check permissions
        * [ ] Owner only
        * [ ] TODO: Permissioned list
        * [ ] Any user
        * [ ] Locked
    * [ ] Any user can remove their items
      * [ ] TODO: ?Check permissions
    * [ ] Cannot send ETH to RegistryReceiver
    * [ ] Can send null data to RegistryReceiver
    * [ ] Cannot send duplicate to RegistryReceiver
    * [ ] Can burn and resubmit same data
    * [ ] Owner
      * [ ] TODO: Can update description
      * [ ] TODO: Can update permissions
      * [ ] TODO: Can remove items, as permissioned
      * [ ] TODO: Can update royalties, as permissioned
* [ ] [contracts/RegistryExchange](contracts/RegistryExchange.sol)
  * [ ] TODO
    * [ ] Check Action cannot be set out of range
  * [ ] Owned
    * [ ] `transferOwnership(...)` can only be executed by `owner`
    * [ ] `acceptOwnership()` can only be executed by `newOwner`
  * [ ] `bulkTransfer(...)`
    * [ ] Can only `bulkTransfer(...)` own items
  * [ ] `updateFee(...)` and `updateFeeAccount(...)`
    * [ ] `updateFee(...)` can only be called by owner
    * [ ] Cannot `updateFee(...)` above `MAX_FEE`
    * [ ] `updateFee(...)` updated amount takes effect for Buy and Sell trades
    * [ ] `updateFeeAccount(...)`
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
