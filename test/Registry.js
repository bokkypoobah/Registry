const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

describe("Registry", function () {
  async function deployFixture() {
    const [owner, otherAccount] = await ethers.getSigners();
    const Registry = await ethers.getContractFactory("Registry");
    const registry = await Registry.deploy();
    const registryReceiver = await registry.registryReceiver();

    console.log("      deployFixture - owner.address: " + owner.address);
    console.log("      deployFixture - otherAccount.address: " + otherAccount.address);

    return { registry, registryReceiver, owner, otherAccount };
  }

  async function printState(registry) {
    const registryReceiver = await registry.registryReceiver();
    console.log("      printState - registry.target: " + registry.target);
    console.log("      printState - registryReceiver: " + registryReceiver);
    // console.log("      printState - registry.target: " + registryReceiver);
    const hashesLength = await registry.hashesLength();
    console.log("      printState - hashesLength: " + hashesLength);

    for (let i = 0; i < hashesLength; i++) {
      const hash = await registry.hashes(i);
      console.log("      printState - hashes[" + i + "]: " + hash);
    }
  }

  describe("Deployment", function () {
    it("Should deploy", async function () {
      const { registry, registryReceiver, owner, otherAccount } = await loadFixture(deployFixture);
      // console.log("      registry: " + JSON.stringify(registry));
      // console.log("      registryReceiver: " + registryReceiver);
      // expect(await lock.unlockTime()).to.equal(unlockTime);

      await printState(registry);


      const tx0 = await owner.sendTransaction({ to: registryReceiver, value: 0, data: "0x1234" });
      const tx1 = await owner.sendTransaction({ to: registryReceiver, value: 0, data: "0x1234" });

      await printState(registry);

      const tx2 = await owner.sendTransaction({ to: registryReceiver, value: 0, data: "0x123456" });

      await printState(registry);
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
