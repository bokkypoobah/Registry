const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { BigNumber } = require("ethers");

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const ZERO_HASH = "0x0000000000000000000000000000000000000000000000000000000000000000";

// const { BigNumber } = require("ethers");
// const util = require('util');
// const { expect, assert } = require("chai");


describe("Registry", function () {
  async function deployFixture() {
    const [owner, otherAccount] = await ethers.getSigners();
    const Registry = await ethers.getContractFactory("Registry");
    const registry = await Registry.deploy();
    const registryReceiver = await registry.registryReceiver();
    console.log("      deployFixture - owner.address: " + owner.address);
    console.log("      deployFixture - otherAccount.address: " + otherAccount.address);
    console.log("      deployFixture - registry.target: " + registry.target);
    console.log("      deployFixture - registryReceiver: " + registryReceiver);
    console.log();
    return { registry, registryReceiver, owner, otherAccount };
  }

  async function printTx(prefix, receipt) {
    const gasPrice = ethers.parseUnits("20.0", "gwei");
    const ethUsd = ethers.parseUnits("2000.0", 18);
    var fee = receipt.gasUsed * gasPrice;
    var feeUsd = fee * ethUsd / ethers.parseUnits("1", 18);
    console.log("      > " + prefix + " - gasUsed: " + receipt.gasUsed + " ~ ETH " + ethers.formatEther(fee) + " ~ USD " + ethers.formatEther(feeUsd) + " @ gasPrice " + ethers.formatUnits(gasPrice, "gwei") + " gwei, ETH/USD " + ethers.formatUnits(ethUsd, 18));
    // receipt.logs.forEach((log) => {
    //   console.log(log);
    // });
  }

  async function printState(prefix, registry) {
    const registryReceiver = await registry.registryReceiver();
    const data = await registry.getData(10, 0);
    for (const row of data) {
      const [hash, owner] = row;
      if (hash == ZERO_HASH) {
        break;
      }
      console.log("      printState - " + prefix + " - " + hash + " " + owner);
    }
    // const hashesLength = await registry.hashesLength();
    // for (let i = 0; i < hashesLength; i++) {
    //   const hash = await registry.hashes(i);
    //   const owner = await registry.ownerOf(hash);
    //   console.log("      printState - " + prefix + " - " + hash + " " + owner);
    // }
    console.log();
  }

  describe("Deployment", function () {
    it("Should deploy", async function () {
      const { registry, registryReceiver, owner, otherAccount } = await loadFixture(deployFixture);
      await printState("Empty", registry);


      const data0 = "0x1234";
      console.log("      data0.length: " + ((data0.length - 2)/2));
      const tx0 = await owner.sendTransaction({ to: registryReceiver, value: 0, data: data0 });
      await printTx("tx0", await tx0.wait());
      await expect(owner.sendTransaction({ to: registryReceiver, value: 0, data: data0 })).to.be.revertedWithCustomError(
        registry,
        "AlreadyRegistered"
      );
      await expect(registry.register(data0, owner.address)).to.be.revertedWithCustomError(
        registry,
        "OnlyRegistryReceiverCanRegister"
      );
      const tx0Regular = await owner.sendTransaction({ to: owner.address, value: 0, data: "0x1234" });
      await printTx("tx0Regular", await tx0Regular.wait());
      await printState("Single Entry", registry);

      const data1 = "0x3456";
      console.log("      data1.length: " + ((data1.length - 2)/2));
      const tx1 = await owner.sendTransaction({ to: registryReceiver, value: 0, data: data1 });
      await printTx("tx1", await tx1.wait());
      const tx1Regular = await owner.sendTransaction({ to: owner.address, value: 0, data: data1 });
      await printTx("tx1Regular", await tx1Regular.wait());
      await printState("2 Entries", registry);

      const data2 = "0x" + "12".repeat(1000);
      console.log("      data2.length: " + ((data2.length - 2)/2));
      const tx2 = await otherAccount.sendTransaction({ to: registryReceiver, value: 0, data: data2 });
      await printTx("tx2", await tx2.wait());
      const tx2Regular = await otherAccount.sendTransaction({ to: otherAccount.address, value: 0, data: data2 });
      await printTx("tx2Regular", await tx2Regular.wait());
      await printState("3 Entries, 2 Accounts", registry);

      const secondHash = await registry.hashes(1);
      console.log("      Transferring ownership of " + secondHash + " to " + otherAccount.address);
      const tx3 = await registry.transfer(otherAccount.address, secondHash);
      await printTx("tx3", await tx3.wait());
      await printState("3 Entries, 2 Accounts, Transferred", registry);

      const data4 = "0x" + "12".repeat(10000);
      console.log("      data4.length: " + ((data4.length - 2)/2));
      const tx4 = await otherAccount.sendTransaction({ to: registryReceiver, value: 0, data: data4 });
      await printTx("tx4", await tx4.wait());
      const tx4Regular = await otherAccount.sendTransaction({ to: otherAccount.address, value: 0, data: data4 });
      await printTx("tx4Regular", await tx4Regular.wait());
      await printState("4 Entries, 2 Accounts, large item", registry);

      const data5 = "0x" + "12".repeat(100000);
      console.log("      data5.length: " + ((data5.length - 2)/2));
      const tx5 = await otherAccount.sendTransaction({ to: registryReceiver, value: 0, data: data5 });
      await printTx("tx5", await tx5.wait());
      const tx5Regular = await otherAccount.sendTransaction({ to: otherAccount.address, value: 0, data: data5 });
      await printTx("tx5Regular", await tx5Regular.wait());
      await printState("5 Entries, 2 Accounts, large items", registry);
    });


    // it("Should set the right owner", async function () {
    //   const { lock, owner } = await loadFixture(deployOneYearLockFixture);
    //
    //   expect(await lock.owner()).to.equal(owner.address);
    // });
    //
    // it("Should receive and store the funds to lock", async function () {
    //   const { lock, lockedAmount } = await loadFixture(
    //     deployOneYearLockFixture
    //   );
    //
    //   expect(await ethers.provider.getBalance(lock.target)).to.equal(
    //     lockedAmount
    //   );
    // });

    // it("Should fail if the unlockTime is not in the future", async function () {
    //   // We don't use the fixture here because we want a different deployment
    //   const latestTime = await time.latest();
    //   const Lock = await ethers.getContractFactory("Lock");
    //   await expect(Lock.deploy(latestTime, { value: 1 })).to.be.revertedWith(
    //     "Unlock time should be in the future"
    //   );
    // });
  });

  // describe("Withdrawals", function () {
  //   describe("Validations", function () {
  //     it("Should revert with the right error if called too soon", async function () {
  //       const { lock } = await loadFixture(deployOneYearLockFixture);
  //
  //       await expect(lock.withdraw()).to.be.revertedWith(
  //         "You can't withdraw yet"
  //       );
  //     });
  //
  //     it("Should revert with the right error if called from another account", async function () {
  //       const { lock, unlockTime, otherAccount } = await loadFixture(
  //         deployOneYearLockFixture
  //       );
  //
  //       // We can increase the time in Hardhat Network
  //       await time.increaseTo(unlockTime);
  //
  //       // We use lock.connect() to send a transaction from another account
  //       await expect(lock.connect(otherAccount).withdraw()).to.be.revertedWith(
  //         "You aren't the owner"
  //       );
  //     });
  //
  //     it("Shouldn't fail if the unlockTime has arrived and the owner calls it", async function () {
  //       const { lock, unlockTime } = await loadFixture(
  //         deployOneYearLockFixture
  //       );
  //
  //       // Transactions are sent using the first signer by default
  //       await time.increaseTo(unlockTime);
  //
  //       await expect(lock.withdraw()).not.to.be.reverted;
  //     });
  //   });
  //
  //   describe("Events", function () {
  //     it("Should emit an event on withdrawals", async function () {
  //       const { lock, unlockTime, lockedAmount } = await loadFixture(
  //         deployOneYearLockFixture
  //       );
  //
  //       await time.increaseTo(unlockTime);
  //
  //       await expect(lock.withdraw())
  //         .to.emit(lock, "Withdrawal")
  //         .withArgs(lockedAmount, anyValue); // We accept any value as `when` arg
  //     });
  //   });
  //
  //   describe("Transfers", function () {
  //     it("Should transfer the funds to the owner", async function () {
  //       const { lock, unlockTime, lockedAmount, owner } = await loadFixture(
  //         deployOneYearLockFixture
  //       );
  //
  //       await time.increaseTo(unlockTime);
  //
  //       await expect(lock.withdraw()).to.changeEtherBalances(
  //         [owner, lock],
  //         [lockedAmount, -lockedAmount]
  //       );
  //     });
  //   });
  // });
});
