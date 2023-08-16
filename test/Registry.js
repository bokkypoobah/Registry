const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { BigNumber } = require("ethers");

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const ZERO_HASH = "0x0000000000000000000000000000000000000000000000000000000000000000";
const DUMMY_HASH = "0x0000000000000000000000000000000000000000000000000000000000000001";

// const { BigNumber } = require("ethers");
// const util = require('util');
// const { expect, assert } = require("chai");


describe("Registry", function () {
  async function deployFixture() {
    const [deployer, user0, user1, user2] = await ethers.getSigners();
    const Registry = await ethers.getContractFactory("Registry");
    const registry = await Registry.deploy();
    const RegistryExchange = await ethers.getContractFactory("RegistryExchange");
    const registryExchange = await RegistryExchange.deploy(registry.target);
    const registryReceiver = await registry.registryReceiver();
    console.log("      deployFixture - deployer: " + deployer.address);
    console.log("      deployFixture - user0: " + user0.address);
    console.log("      deployFixture - user1: " + user1.address);
    console.log("      deployFixture - user2: " + user2.address);
    console.log("      deployFixture - registry: " + registry.target);
    console.log("      deployFixture - registryReceiver: " + registryReceiver);
    console.log("      deployFixture - registryExchange: " + registryExchange.target);
    console.log();
    const accounts = [deployer.address, user0.address, user1.address, user2.address, registry.target, registryReceiver, registryExchange.target];
    const accountNames = {};
    accountNames[deployer.address.toLowerCase()] = "deployer";
    accountNames[user0.address.toLowerCase()] = "user0";
    accountNames[user1.address.toLowerCase()] = "user1";
    accountNames[user2.address.toLowerCase()] = "user2";
    accountNames[registry.target.toLowerCase()] = "registry";
    accountNames[registryReceiver.toLowerCase()] = "registryReceiver";
    accountNames[registryExchange.target.toLowerCase()] = "registryExchange";
    return { registry, registryReceiver, registryExchange, deployer, user0, user1, user2, accounts, accountNames, hashes: {} };
  }

  function padLeft(s, n) {
    var o = s.toString();
    while (o.length < n) {
      o = " " + o;
    }
    return o;
  }
  function padRight(s, n) {
    var o = s;
    while (o.length < n) {
      o = o + " ";
    }
    return o;
  }
  function getAccountName(data, address) {
    if (address != null) {
      var a = address.toLowerCase();
      var n = data.accountNames[a];
      if (n !== undefined) {
        return n + ":" + address.substring(0, 6);
      }
    }
    return address.substring(0, 20);
  }
  function addHash(data, string) {
    const hash = ethers.keccak256(ethers.toUtf8Bytes(string));
    if (!(hash in data.hashes)) {
      data.hashes[hash] = string;
    }
  }
  function getHashData(data, hash, length = 20) {
    if (hash != null) {
      if (hash in data.hashes) {
        return padRight('"' + data.hashes[hash].substring(0, length - 9) + '":' + hash.substring(0, 6), 20);
      } else {
        return hash.substring(0, length);
      }
    }
    return null;
  }

  async function printTx(data, prefix, receipt) {
    const gasPrice = ethers.parseUnits("20.0", "gwei");
    const ethUsd = ethers.parseUnits("2000.0", 18);
    var fee = receipt.gasUsed * gasPrice;
    var feeUsd = fee * ethUsd / ethers.parseUnits("1", 18);
    console.log("      > " + prefix + " - gasUsed: " + receipt.gasUsed + " ~ ETH " + ethers.formatEther(fee) + " ~ USD " + ethers.formatEther(feeUsd) + " @ gasPrice " + ethers.formatUnits(gasPrice, "gwei") + " gwei, ETH/USD " + ethers.formatUnits(ethUsd, 18));
    receipt.logs.forEach((log) => {
      let logData = null;
      if (log.address == data.registry.target) {
        logData = data.registry.interface.parseLog(log);
      } else if (log.address == data.registryExchange.target) {
        logData = data.registryExchange.interface.parseLog(log);
      }
      // console.log("log: " + JSON.stringify(log));
      // console.log("data: " + JSON.stringify(data, (_, v) => typeof v === 'bigint' ? v.toString() : v));
      var result = logData.name + "(";
      let separator = "";
      logData.fragment.inputs.forEach((a) => {
        result = result + separator + a.name + ": ";
        if (a.type == 'address') {
          result = result + getAccountName(data, logData.args[a.name].toString());
        } else if (a.type == 'uint256' || a.type == 'uint128' || a.type == 'uint64') {
          result = result + logData.args[a.name].toString();
        } else if (a.type == 'bytes32') {
          result = result + logData.args[a.name].substring(0, 10);
        } else {
          result = result + logData.args[a.name].toString();
        }
        separator = ", ";
      });
      result = result + ")";
      console.log("        + " + getAccountName(data, log.address) + " -> " + log.blockNumber + "." + log.index + " " + result);
    });
  }

  async function printState(data, prefix) {
    const registryReceiver = await data.registry.registryReceiver();
    const items = await data.registry.getData(10, 0);
    let i = 0;
    console.log();
    console.log("       # String:Hash          Owner                          Registered");
    console.log("      -- -------------------- ------------------------------ -----------------------------");
    for (const item of items) {
      const [hash, owner, created] = item;
      if (hash == ZERO_HASH) {
        break;
      }
      console.log("      " + padLeft(i, 2) + " " + getHashData(data, hash) + " " + padRight(getAccountName(data, owner), 30) + " " + new Date(parseInt(created) * 1000).toUTCString());
      i++;
    }
    // const hashesLength = await registry.hashesLength();
    // for (let i = 0; i < hashesLength; i++) {
    //   const hash = await registry.hashes(i);
    //   const owner = await registry.ownerOf(i);
    //   console.log("      printState using ownerOf(i) - " + prefix + " - " + hash + " " + owner);
    // }
    console.log();
  }

  describe("Registry", function () {
    it("Testing #1", async function () {
      const data = await loadFixture(deployFixture);
      await printState(data, "Empty");

      // TODO: Send tx with non-0 value

      const string0 = "abcdef";
      addHash(data, string0);
      console.log("      string0.length: " + ((string0.length - 2)/2));
      const tx0 = await data.user0.sendTransaction({ to: data.registryReceiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes(string0)) });
      await printTx(data, "tx0", await tx0.wait());
      await expect(data.user0.sendTransaction({ to: data.registryReceiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes(string0)) })).to.be.revertedWithCustomError(
        data.registry,
        "AlreadyRegistered"
      ).withArgs(anyValue, data.user0.address, 0, anyValue);
      await expect(data.registry.register(DUMMY_HASH, data.user0.address)).to.be.revertedWithCustomError(
        data.registry,
        "OnlyRegistryReceiverCanRegister"
      );
      const tx0Regular = await data.user0.sendTransaction({ to: data.user0.address, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes(string0)) });
      await printTx(data, "tx0Regular", await tx0Regular.wait());
      await printState(data, "Single Entry");

      const string1 = "abcdefgh";
      addHash(data, string1);
      console.log("      string1.length: " + ((string1.length - 2)/2));
      const tx1 = await data.user0.sendTransaction({ to: data.registryReceiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes(string1)) });
      await printTx(data, "tx1", await tx1.wait());
      const tx1Regular = await data.user0.sendTransaction({ to: data.user0.address, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes(string1)) });
      await printTx(data, "tx1Regular", await tx1Regular.wait());
      await printState(data, "2 Entries");

      const string2 = "1".repeat(1000);
      addHash(data, string2);
      console.log("      string2.length: " + ((string2.length - 2)/2));
      const tx2 = await data.user1.sendTransaction({ to: data.registryReceiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes(string2)) });
      await printTx(data, "tx2", await tx2.wait());
      const tx2Regular = await data.user1.sendTransaction({ to: data.user1.address, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes(string2)) });
      await printTx(data, "tx2Regular", await tx2Regular.wait());
      await printState(data, "3 Entries, 2 Accounts");

      await expect(
        data.registry.connect(data.user0).transfer(data.user1.address, 2)).to.be.revertedWithCustomError(
        data.registry,
        "NotOwnerNorApproved"
      );
      console.log("      Transferring ownership of #1 to " + getAccountName(data, data.user1.address));
      const tx3 = await data.registry.connect(data.user0).transfer(data.user1.address, 1);
      await printTx(data, "tx3", await tx3.wait());
      await printState(data, "3 Entries, 2 Accounts, Transferred");

      const string4 = "22".repeat(10000);
      addHash(data, string4);
      console.log("      string4.length: " + ((string4.length - 2)/2));
      const tx4 = await data.user1.sendTransaction({ to: data.registryReceiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes(string4)) });
      await printTx(data, "tx4", await tx4.wait());
      const tx4Regular = await data.user1.sendTransaction({ to: data.user1.address, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes(string4)) });
      await printTx(data, "tx4Regular", await tx4Regular.wait());
      await printState(data, "4 Entries, 2 Accounts, large item");

      const string5 = "3".repeat(100000);
      addHash(data, string5);
      console.log("      string5.length: " + ((string5.length - 2)/2));
      const tx5 = await data.user1.sendTransaction({ to: data.registryReceiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes(string5)) });
      await printTx(data, "tx5", await tx5.wait());
      const tx5Regular = await data.user1.sendTransaction({ to: data.user1.address, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes(string5)) });
      await printTx(data, "tx5Regular", await tx5Regular.wait());
      await printState(data, "5 Entries, 2 Accounts, large items");

      await expect(
        data.registryExchange.connect(data.user1).bulkTransfer(data.user0.address, [0])).to.be.revertedWithCustomError(
        data.registryExchange,
        "OnlyTokenOwnerCanTransfer"
      );
      await expect(
        data.registryExchange.connect(data.user1).bulkTransfer(data.user0.address, [1, 2])).to.be.revertedWithCustomError(
        data.registry,
        "NotOwnerNorApproved"
      );

      console.log("      user1.setApprovalForAll(registryExchange, true)");
      const tx6 = await data.registry.connect(data.user1).setApprovalForAll(data.registryExchange.target, true);
      await printTx(data, "tx6", await tx6.wait());

      console.log("      Transferring ownership of #1 & #3 to " + getAccountName(data, data.user0.address));
      const tx7 = await data.registryExchange.connect(data.user1).bulkTransfer(data.user0.address, [1, 3]);
      await printTx(data, "tx7", await tx7.wait());
      await printState(data, "5 Entries, 2 Accounts, Transferred");
    });
  });


  describe("RegistryExchange", function () {
    it("Testing #2", async function () {
      const data = await loadFixture(deployFixture);
      await printState(data, "Empty");

      addHash(data, "text0");
      addHash(data, "text1");
      addHash(data, "text2");
      addHash(data, "text3");
      addHash(data, "text4");
      const tx0 = await data.user0.sendTransaction({ to: data.registryReceiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("text0")) });
      const tx1 = await data.user0.sendTransaction({ to: data.registryReceiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("text1")) });
      const tx2 = await data.user0.sendTransaction({ to: data.registryReceiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("text2")) });
      const tx3 = await data.user0.sendTransaction({ to: data.registryReceiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("text3")) });
      const tx4 = await data.user0.sendTransaction({ to: data.registryReceiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("text4")) });
      await printTx(data, "tx0", await tx0.wait());

      console.log("      user0.setApprovalForAll(registryExchange, true)");
      const tx5 = await data.registry.connect(data.user0).setApprovalForAll(data.registryExchange.target, true);
      await printTx(data, "tx5", await tx5.wait());

      await printState(data, "Setup Tokens");
    });
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
