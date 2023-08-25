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
const ACTIONS = ["Offer", "Bid", "Buy", "Sell", "CollectionOffer", "CollectionBid", "CollectionBuy", "CollectionSell"];

const INPUT_OFFER = 0;
const INPUT_BID = 1;
const INPUT_BUY = 2;
const INPUT_SELL = 3;
const INPUT_COLLECTION_OFFER = 4;
const INPUT_COLLECTION_BID = 5;
const INPUT_COLLECTION_BUY = 6;
const INPUT_COLLECTION_SELL = 7;

const INPUT = {
  "OFFER": 0,
  "BID": 1,
  "BUY": 2,
  "SELL": 3,
  "COLLECTION_OFFER": 4,
  "COLLECTION_BID": 5,
  "COLLECTION_BUY": 6,
  "COLLECTION_SELL": 7,
};

const FUSE_OWNER_CAN_UPDATE_DESCRIPTION = 0x01; // DESCRIPT DESCR
const FUSE_OWNER_CAN_UPDATE_ROYALTIES = 0x02; // ROYALTIES ROYAL
const FUSE_OWNER_CAN_BURN_USER_ITEM = 0x04; // OWNERBURN OBURN
const FUSE_OWNER_CAN_MINT_ITEM = 0x08; // OWNERMINT OMINT
const FUSE_MINTER_LIST_CAN_MINT_ITEM = 0x10; // MINTLIST MLIST
const FUSE_ANY_USER_CAN_MINT_ITEM = 0x20; // ANY AUSER

describe("Registry", function () {
  async function deployFixture() {
    const [deployer, user0, user1, user2, royalty0, royalty1, royalty2, feeAccount, uiFeeAccount] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("Token");
    const weth = await Token.deploy("WETH", "Wrapped Ether", 18, ethers.parseEther("3000"));
    const Registry = await ethers.getContractFactory("Registry");
    const registry = await Registry.deploy();
    const Exchange = await ethers.getContractFactory("Exchange");
    const exchange = await Exchange.deploy(weth.target, registry.target);
    const receiver = await registry.getReceiver(0);
    const exchangeOwner = await exchange.owner();
    const accounts = [deployer.address, user0.address, user1.address, user2.address, royalty0.address, royalty1.address, royalty2.address, feeAccount.address, uiFeeAccount.address, weth.target, registry.target, receiver, exchange.target];
    const accountNames = {};
    accountNames[deployer.address.toLowerCase()] = "deployer";
    accountNames[user0.address.toLowerCase()] = "user0";
    accountNames[user1.address.toLowerCase()] = "user1";
    accountNames[user2.address.toLowerCase()] = "user2";
    accountNames[royalty0.address.toLowerCase()] = "royalty0";
    accountNames[royalty1.address.toLowerCase()] = "royalty1";
    accountNames[royalty2.address.toLowerCase()] = "royalty2";
    accountNames[feeAccount.address.toLowerCase()] = "feeAccount";
    accountNames[uiFeeAccount.address.toLowerCase()] = "uiFeeAccount";
    accountNames[weth.target.toLowerCase()] = "weth";
    accountNames[registry.target.toLowerCase()] = "registry";
    accountNames[receiver.toLowerCase()] = "receiver";
    accountNames[exchange.target.toLowerCase()] = "exchange";
    const data = { weth, registry, receiver, exchange, deployer, user0, user1, user2, royalty0, royalty1, royalty2, feeAccount, uiFeeAccount, accounts, accountNames, hashes: {} };

    const updateFeeAccountTx = await exchange.updateFeeAccount(feeAccount);
    // await printTx(data, "updateFeeAccountTx", await updateFeeAccountTx.wait());
    const amount0 = ethers.parseEther("1000");
    const txWethTransfer0 = await weth.connect(deployer).transfer(user0.address, amount0);
    const txWethTransfer1 = await weth.connect(deployer).transfer(user1.address, amount0);
    const txWethTransfer2 = await weth.connect(deployer).transfer(user2.address, amount0);
    // await printTx(data, "txWethTransfer0", await txWethTransfer0.wait());
    // await printTx(data, "txWethTransfer1", await txWethTransfer1.wait());
    // await printTx(data, "txWethTransfer2", await txWethTransfer2.wait());
    const approveAmount0 = ethers.parseEther("111.111111111");
    const txWethApprove0 = await weth.connect(user0).approve(exchange.target, approveAmount0);
    const txWethApprove1 = await weth.connect(user1).approve(exchange.target, approveAmount0);
    const txWethApprove2 = await weth.connect(user2).approve(exchange.target, approveAmount0);
    // await printTx(data, "txWethApprove0", await txWethApprove0.wait());
    // await printTx(data, "txWethApprove1", await txWethApprove1.wait());
    // await printTx(data, "txWethApprove2", await txWethApprove2.wait());
    return data;
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
  function addHash(collectionName, data, string) {
    let hash = ethers.keccak256(ethers.toUtf8Bytes(string || ''));
    if (collectionName != '') {
      hash = ethers.solidityPackedKeccak256(["string", "bytes32"], [collectionName, hash]);
    }
    if (!(hash in data.hashes)) {
      data.hashes[hash] = string;
    }
  }
  function getHashData(data, hash, length = 36) {
    if (hash != null) {
      if (hash in data.hashes) {
        if (!data.hashes[hash]) {
          return padRight("(null)", length);
        } else {
          return padRight('"' + data.hashes[hash].substring(0, length - 9) + '":' + hash.substring(0, 6), length);
        }
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
      } else if (log.address == data.exchange.target) {
        logData = data.exchange.interface.parseLog(log);
      } else if (log.address == data.weth.target) {
        logData = data.weth.interface.parseLog(log);
      }
      // console.log("data: " + JSON.stringify(data, (_, v) => typeof v === 'bigint' ? v.toString() : v));
      var result = logData.name + "(";
      let separator = "";
      logData.fragment.inputs.forEach((a) => {
        result = result + separator + a.name + ": ";
        if (a.type == 'address') {
          result = result + getAccountName(data, logData.args[a.name].toString());
        } else if (a.type == 'uint256' || a.type == 'uint128' || a.type == 'uint96' || a.type == 'uint64') {
          if (a.name == 'timestamp' || a.name == 'expiry') {
            result = result + new Date(parseInt(logData.args[a.name].toString()) * 1000).toISOString().substring(0, 19);
          } else if (a.name == 'tokens' || a.name == 'price') {
            result = result + ethers.formatEther(logData.args[a.name]);
            // if (a.name == 'tokens') {
              const amount = logData.args[a.name] * ethUsd / ethers.parseUnits("1", 18);
              result = result + " $" + ethers.formatEther(amount);
            // }
          } else {
            result = result + logData.args[a.name].toString();
          }
        } else if (a.type == 'uint8') {
          if (a.name == 'action') {
            result = result + ACTIONS[logData.args[a.name]];
          } else {
            result = result + logData.args[a.name].toString();
          }
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
    console.log();
    console.log("      --- " + prefix + " ---");
    console.log("       Id Account                                        ETH                     WETH");
    console.log("      --- ------------------------- ------------------------ ------------------------");
    for (let i = 0; i < data.accounts.length; i++) {
      const account = data.accounts[i];
      const balance = await ethers.provider.getBalance(account);
      const wethBalance = data.weth == null ? 0 : await data.weth.balanceOf(account);
      console.log("      " + padLeft(i, 3) + " " + padRight(getAccountName(data, account), 25) + " " + padLeft(ethers.formatEther(balance), 24) + " " + padLeft(ethers.formatEther(wethBalance), 24));
    }
    console.log();

    const collectionData = await data.registry.getCollections(10, 0);
    let i = 0;
    console.log("       Id Collection Name      Description          Receiver               Owner                  Items Descr Royal OBurn OMint MintL AnyUs Created");
    console.log("      --- -------------------- -------------------- ---------------------- -------------------- ------- ----- ----- ----- ----- ----- ----- ------------------------");
    for (const _d of collectionData) {
      const [name, description, owner, receiver, fuses, items, created] = _d;
      if (created == 0) {
        break;
      }
      const ownerCanUpdateDescription = (parseInt(fuses) & FUSE_OWNER_CAN_UPDATE_DESCRIPTION) == FUSE_OWNER_CAN_UPDATE_DESCRIPTION ? "y" : "n";
      const ownerCanUpdateRoyalties = (parseInt(fuses) & FUSE_OWNER_CAN_UPDATE_ROYALTIES) == FUSE_OWNER_CAN_UPDATE_ROYALTIES ? "y" : "n";
      const ownerCanBurnUserItems = (parseInt(fuses) & FUSE_OWNER_CAN_BURN_USER_ITEM) == FUSE_OWNER_CAN_BURN_USER_ITEM ? "y" : "n";
      const ownerCanMintItems = (parseInt(fuses) & FUSE_OWNER_CAN_MINT_ITEM) == FUSE_OWNER_CAN_MINT_ITEM ? "y" : "n";
      const minterListCanMintItems = (parseInt(fuses) & FUSE_MINTER_LIST_CAN_MINT_ITEM) == FUSE_MINTER_LIST_CAN_MINT_ITEM ? "y" : "n";
      const anyUserCanMintItems = (parseInt(fuses) & FUSE_ANY_USER_CAN_MINT_ITEM) == FUSE_ANY_USER_CAN_MINT_ITEM ? "y" : "n";
      console.log("      " + padLeft(i, 3) + " " + padRight(name || '(default)', 20) + " " + padRight(description || '(default)', 20) + " " +
        padRight(getAccountName(data, receiver), 22) + " " + padRight(getAccountName(data, owner), 20) + " " +
        padLeft(items, 7) + " " +
        padLeft(ownerCanUpdateDescription, 5) + " " +
        padLeft(ownerCanUpdateRoyalties, 5) + " " +
        padLeft(ownerCanBurnUserItems, 5) + " " +
        padLeft(ownerCanMintItems, 5) + " " +
        padLeft(minterListCanMintItems, 5) + " " +
        padLeft(anyUserCanMintItems, 5) + " " +
        new Date(parseInt(created) * 1000).toISOString());
      i++;
    }
    console.log();

    const receiver = await data.registry.getReceiver(0);
    const items = await data.registry.getItems(10, 0);
    i = 0;
    console.log("       Id Collection Id String:Hash                          Owner                          Registered");
    console.log("      --- ------------- ------------------------------------ ------------------------------ ------------------------");
    for (const item of items) {
      const [collectionId, hash, owner, created] = item;
      if (hash == ZERO_HASH) {
        break;
      }
      console.log("      " + padLeft(i, 3) + " " + padLeft(collectionId, 13) + " " + padRight(getHashData(data, hash).substring(0, 36), 36) + " " + padRight(getAccountName(data, owner), 30) + " " + new Date(parseInt(created) * 1000).toISOString());
      i++;
    }
    // TODO: Make sure tested separately
    // const length = await data.registry.itemsLength();
    // for (let i = 0; i < length; i++) {
    //   const hash = await data.registry.hashes(i);
    //   const owner = await data.registry.ownerOf(i);
    //   console.log("      printState using ownerOf(i) - " + prefix + " - " + hash + " " + owner);
    // }
    console.log();
  }


  describe("Exchange - All Order Types", function () {
    it("Exchange - Offer & Buy #1", async function () {
      const data = await loadFixture(deployFixture);

      addHash("", data, "user0string0");
      addHash("", data, "user0string1");
      addHash("", data, "user0string2");
      addHash("", data, "user0string3");
      addHash("", data, "user0string4");

      const tx0 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string0")) });
      const tx1 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string1")) });
      const tx2 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string2")) });
      const tx3 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string3")) });
      const tx4 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string4")) });

      const expiry = parseInt(new Date() / 1000) + 60 * 60;
      const offerData = [[INPUT_OFFER, ZERO_ADDRESS, 1, ethers.parseEther("1.1"), 1, expiry], [INPUT_OFFER, ZERO_ADDRESS, 2, ethers.parseEther("2.2"), 1, expiry], [INPUT_OFFER, ZERO_ADDRESS, 3, ethers.parseEther("3.3"), 1, expiry]];
      const tx5 = await data.exchange.connect(data.user0).execute(offerData, data.uiFeeAccount);
      await printTx(data, "tx5", await tx5.wait());

      const tx6 = await data.registry.connect(data.user0).setApprovalForAll(data.exchange.target, true);
      // await printTx(data, "tx6", await tx6.wait());

      // await printState(data, "DEBUG");

      const buyData1 = [[INPUT_BUY, data.user0.address, 1, ethers.parseEther("1.1"), 0, 0], [INPUT_BUY, data.user0.address, 3, ethers.parseEther("3.3"), 0, 0]];
      const tx7 = await data.exchange.connect(data.user1).execute(buyData1, data.uiFeeAccount);
      await printTx(data, "tx7", await tx7.wait());

      await printState(data, "End");
    });

    it("Exchange - Bid & Sell #1", async function () {
      const data = await loadFixture(deployFixture);

      addHash("", data, "user0string0");
      addHash("", data, "user0string1");
      addHash("", data, "user0string2");
      addHash("", data, "user0string3");
      addHash("", data, "user0string4");

      const tx0 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string0")) });
      const tx1 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string1")) });
      const tx2 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string2")) });
      const tx3 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string3")) });
      const tx4 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string4")) });

      const expiry = parseInt(new Date() / 1000) + 60 * 60;
      const bidData = [[INPUT_BID, ZERO_ADDRESS, 1, ethers.parseEther("1.1"), 1, expiry], [INPUT_BID, ZERO_ADDRESS, 2, ethers.parseEther("2.2"), 1, expiry], [INPUT_BID, ZERO_ADDRESS, 3, ethers.parseEther("3.3"), 1, expiry]];
      const tx5 = await data.exchange.connect(data.user1).execute(bidData, data.uiFeeAccount);
      await printTx(data, "tx5", await tx5.wait());

      const tx6 = await data.registry.connect(data.user0).setApprovalForAll(data.exchange.target, true);
      // await printTx(data, "tx6", await tx6.wait());

      // await printState(data, "DEBUG");

      const sellData1 = [[INPUT_SELL, data.user1.address, 1, ethers.parseEther("1.1"), 0, 0], [INPUT_SELL, data.user1.address, 3, ethers.parseEther("3.3"), 0, 0]];
      const tx7 = await data.exchange.connect(data.user0).execute(sellData1, data.uiFeeAccount);
      await printTx(data, "tx7", await tx7.wait());

      await printState(data, "End");
    });

    it.skip("Exchange - Collection Offer & Collection Buy #1", async function () {
      const data = await loadFixture(deployFixture);

      addHash("", data, "user0string0");
      addHash("", data, "user0string1");
      addHash("", data, "user0string2");
      addHash("", data, "user0string3");
      addHash("", data, "user0string4");

      const tx0 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string0")) });
      const tx1 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string1")) });
      const tx2 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string2")) });
      const tx3 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string3")) });
      const tx4 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string4")) });

      const royalties = [ [ data.royalty0.address, "10" ], [ data.royalty1.address, "20" ], [ data.royalty2.address, "30" ] ];

      // const FUSE_OWNER_CAN_UPDATE_DESCRIPTION = 0x01; // DESCRIPT DESCR
      // const FUSE_OWNER_CAN_UPDATE_ROYALTIES = 0x02; // ROYALTIES ROYAL
      // const FUSE_OWNER_CAN_BURN_USER_ITEM = 0x04; // OWNERBURN OBURN
      // const FUSE_OWNER_CAN_MINT_ITEM = 0x08; // OWNERMINT OMINT
      // const FUSE_MINTER_LIST_CAN_MINT_ITEM = 0x10; // MINTLIST MLIST
      // const FUSE_ANY_USER_CAN_MINT_ITEM = 0x20; // ANY AUSER

      const fuses = FUSE_OWNER_CAN_UPDATE_DESCRIPTION | FUSE_OWNER_CAN_UPDATE_ROYALTIES | FUSE_OWNER_CAN_BURN_USER_ITEM;

      const tx5 = await data.registry.connect(data.user0).newCollection("Name #1", "Collection #1", fuses, royalties);
      await printTx(data, "tx5", await tx5.wait());

      const receiver1 = await data.registry.getReceiver(1);
      data.accountNames[receiver1.toLowerCase()] = "receiver#1";

      addHash("Name #1", data, "collection1user1string0");
      addHash("Name #1", data, "collection1user1string1");
      addHash("Name #1", data, "collection1user1string2");

      const tx6 = await data.user1.sendTransaction({ to: receiver1, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("collection1user1string0")) });
      const tx7 = await data.user1.sendTransaction({ to: receiver1, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("collection1user1string1")) });
      const tx8 = await data.user1.sendTransaction({ to: receiver1, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("collection1user1string2")) });
      await printTx(data, "tx6", await tx6.wait());
      await printTx(data, "tx7", await tx7.wait());
      await printTx(data, "tx8", await tx8.wait());

      const expiry = parseInt(new Date() / 1000) + 60 * 60;
      const collectionOfferData = [[INPUT_COLLECTION_OFFER, ZERO_ADDRESS, 1, ethers.parseEther("1.1"), 5, expiry], [INPUT_COLLECTION_OFFER, ZERO_ADDRESS, 2, ethers.parseEther("2.2"), 5, expiry], [INPUT_COLLECTION_OFFER, ZERO_ADDRESS, 3, ethers.parseEther("3.3"), 5, expiry]];
      const tx9 = await data.exchange.connect(data.user1).execute(collectionOfferData, data.uiFeeAccount);
      await printTx(data, "tx9", await tx9.wait());

      const tx10 = await data.registry.connect(data.user1).setApprovalForAll(data.exchange.target, true);
      // await printTx(data, "tx10", await tx10.wait());

      await printState(data, "DEBUG");

      const sellData1 = [[INPUT_COLLECTION_BUY, data.user1.address, 6, ethers.parseEther("1.1"), 0, 0]];
      const tx11 = await data.exchange.connect(data.user2).execute(sellData1, data.uiFeeAccount);
      await printTx(data, "tx11", await tx11.wait());


      await printState(data, "End");
    });

    it.skip("Exchange - Collection Bid & Collection Sell #1", async function () {
      const data = await loadFixture(deployFixture);

      addHash("", data, "user0string0");
      addHash("", data, "user0string1");
      addHash("", data, "user0string2");
      addHash("", data, "user0string3");
      addHash("", data, "user0string4");

      const tx0 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string0")) });
      const tx1 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string1")) });
      const tx2 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string2")) });
      const tx3 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string3")) });
      const tx4 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string4")) });

      const royalties = [ [ data.royalty0.address, "10" ], [ data.royalty1.address, "20" ], [ data.royalty2.address, "30" ] ];

      const tx5 = await data.registry.connect(data.user0).newCollection("Name #1", "Collection #1", 0, royalties);
      await printTx(data, "tx5", await tx5.wait());

      const receiver1 = await data.registry.getReceiver(1);
      data.accountNames[receiver1.toLowerCase()] = "receiver#1";

      addHash("Name #1", data, "collection1user1string0");
      addHash("Name #1", data, "collection1user1string1");
      addHash("Name #1", data, "collection1user1string2");

      const tx6 = await data.user1.sendTransaction({ to: receiver1, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("collection1user1string0")) });
      const tx7 = await data.user1.sendTransaction({ to: receiver1, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("collection1user1string1")) });
      const tx8 = await data.user1.sendTransaction({ to: receiver1, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("collection1user1string2")) });
      await printTx(data, "tx6", await tx6.wait());
      await printTx(data, "tx7", await tx7.wait());
      await printTx(data, "tx8", await tx8.wait());


      const expiry = parseInt(new Date() / 1000) + 60 * 60;
      const collectionOfferData = [[INPUT_COLLECTION_BID, ZERO_ADDRESS, 1, ethers.parseEther("1.1"), 5, expiry], [INPUT_COLLECTION_BID, ZERO_ADDRESS, 2, ethers.parseEther("2.2"), 5, expiry], [INPUT_COLLECTION_BID, ZERO_ADDRESS, 3, ethers.parseEther("3.3"), 5, expiry]];
      const tx9 = await data.exchange.connect(data.user2).execute(collectionOfferData, data.uiFeeAccount);
      await printTx(data, "tx9", await tx9.wait());

      const tx10 = await data.registry.connect(data.user1).setApprovalForAll(data.exchange.target, true);
      // await printTx(data, "tx10", await tx10.wait());

      await printState(data, "DEBUG");

      const sellData1 = [[INPUT_COLLECTION_SELL, data.user2.address, 6, ethers.parseEther("1.1"), 0, 0]];
      const tx11 = await data.exchange.connect(data.user1).execute(sellData1, data.uiFeeAccount);
      await printTx(data, "tx11", await tx11.wait());

      // expect(await data.weth.balanceOf(data.user1)).to.equal(ethers.parseEther("997.54"));
      // expect(await data.weth.balanceOf(data.feeAccount)).to.equal(ethers.parseEther("0.000615"));
      // expect(await data.weth.balanceOf(data.uiFeeAccount)).to.equal(ethers.parseEther("0.000615"));
      //
      // // Update fee to 7bp
      // await expect(data.exchange.connect(data.deployer).updateFee(7))
      //   .to.emit(data.exchange, "FeeUpdated")
      //   .withArgs(5, 7, anyValue);
      // expect(await data.exchange.fee()).to.equal(7);
      //
      // const buyData2 = [[INPUT_BUY, data.user0.address, 2, ethers.parseEther("1.23"), 0]];
      // const tx8 = await data.exchange.connect(data.user2).execute(buyData2, data.uiFeeAccount);
      // await printTx(data, "tx8", await tx8.wait());
      //
      // expect(await data.weth.balanceOf(data.user2)).to.equal(ethers.parseEther("998.77"));
      // expect(await data.weth.balanceOf(data.feeAccount)).to.equal(ethers.parseEther("0.0010455"));
      // expect(await data.weth.balanceOf(data.uiFeeAccount)).to.equal(ethers.parseEther("0.0010455"));
      //
      // const bidData = [[INPUT_BID, ZERO_ADDRESS, 0, ethers.parseEther("1.11"), expiry], [INPUT_BID, ZERO_ADDRESS, 1, ethers.parseEther("1.11"), expiry], [INPUT_BID, ZERO_ADDRESS, 2, ethers.parseEther("1.11"), expiry], [INPUT_BID, ZERO_ADDRESS, 3, ethers.parseEther("1.11"), expiry], [INPUT_BID, ZERO_ADDRESS, 4, ethers.parseEther("1.11"), expiry]];
      // const tx9 = await data.exchange.connect(data.user2).execute(bidData, data.uiFeeAccount);
      // await printTx(data, "tx9", await tx9.wait());
      //
      // const tx10 = await data.registry.connect(data.user2).setApprovalForAll(data.exchange.target, true);

      await printState(data, "End");
    });
  });


  it.only("Collection Fuses #1", async function () {
    const data = await loadFixture(deployFixture);

    addHash("", data, "user0string0");
    addHash("", data, "user0string1");
    addHash("", data, "user0string2");
    addHash("", data, "user0string3");
    addHash("", data, "user0string4");

    const tx0 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string0")) });
    const tx1 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string1")) });
    const tx2 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string2")) });
    const tx3 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string3")) });
    const tx4 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string4")) });

    const royalties = [ [ data.royalty0.address, "10" ], [ data.royalty1.address, "20" ], [ data.royalty2.address, "30" ] ];

    // const FUSE_OWNER_CAN_UPDATE_DESCRIPTION = 0x01; // DESCRIPT DESCR
    // const FUSE_OWNER_CAN_UPDATE_ROYALTIES = 0x02; // ROYALTIES ROYAL
    // const FUSE_OWNER_CAN_BURN_USER_ITEM = 0x04; // OWNERBURN OBURN
    // const FUSE_OWNER_CAN_MINT_ITEM = 0x08; // OWNERMINT OMINT
    // const FUSE_MINTER_LIST_CAN_MINT_ITEM = 0x10; // MINTLIST MLIST
    // const FUSE_ANY_USER_CAN_MINT_ITEM = 0x20; // ANY AUSER

    const fuses0 = FUSE_OWNER_CAN_UPDATE_DESCRIPTION;
    const tx5 = await data.registry.connect(data.user0).newCollection("Name #1", "Collection #1", fuses0, royalties);
    await printTx(data, "tx5", await tx5.wait());

    const fuses1 = FUSE_OWNER_CAN_UPDATE_DESCRIPTION | FUSE_OWNER_CAN_UPDATE_ROYALTIES;
    const tx6 = await data.registry.connect(data.user0).newCollection("Name #2", "Collection #2", fuses1, royalties);
    await printTx(data, "tx6", await tx6.wait());

    const fuses2 = FUSE_OWNER_CAN_UPDATE_DESCRIPTION | FUSE_OWNER_CAN_UPDATE_ROYALTIES | FUSE_OWNER_CAN_BURN_USER_ITEM;
    const tx7 = await data.registry.connect(data.user0).newCollection("Name #3", "Collection #3", fuses2, royalties);
    await printTx(data, "tx7", await tx7.wait());

    const fuses3 = FUSE_OWNER_CAN_UPDATE_DESCRIPTION | FUSE_OWNER_CAN_UPDATE_ROYALTIES | FUSE_OWNER_CAN_BURN_USER_ITEM | FUSE_OWNER_CAN_MINT_ITEM;
    const tx8 = await data.registry.connect(data.user0).newCollection("Name #4", "Collection #4", fuses3, royalties);
    await printTx(data, "tx8", await tx8.wait());

    const fuses4 = FUSE_OWNER_CAN_UPDATE_DESCRIPTION | FUSE_OWNER_CAN_UPDATE_ROYALTIES | FUSE_OWNER_CAN_BURN_USER_ITEM | FUSE_OWNER_CAN_MINT_ITEM | FUSE_MINTER_LIST_CAN_MINT_ITEM;
    const tx9 = await data.registry.connect(data.user0).newCollection("Name #5", "Collection #5", fuses4, royalties);
    await printTx(data, "tx9", await tx9.wait());

    const fuses5 = FUSE_OWNER_CAN_UPDATE_DESCRIPTION | FUSE_OWNER_CAN_UPDATE_ROYALTIES | FUSE_OWNER_CAN_BURN_USER_ITEM | FUSE_OWNER_CAN_MINT_ITEM | FUSE_MINTER_LIST_CAN_MINT_ITEM | FUSE_ANY_USER_CAN_MINT_ITEM;
    const tx10 = await data.registry.connect(data.user0).newCollection("Name #6", "Collection #6", fuses5, royalties);
    await printTx(data, "tx10", await tx10.wait());


    // const fuses = FUSE_OWNER_CAN_UPDATE_DESCRIPTION | FUSE_OWNER_CAN_UPDATE_ROYALTIES | FUSE_OWNER_CAN_BURN_USER_ITEM;
    // const tx6 = await data.registry.connect(data.user0).newCollection("Name #1", "Collection #1", fuses, royalties);
    // await printTx(data, "tx6", await tx6.wait());

    // const receiver1 = await data.registry.getReceiver(1);
    // data.accountNames[receiver1.toLowerCase()] = "receiver#1";
    //
    // addHash("Name #1", data, "collection1user1string0");
    // addHash("Name #1", data, "collection1user1string1");
    // addHash("Name #1", data, "collection1user1string2");

    // const tx6 = await data.user1.sendTransaction({ to: receiver1, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("collection1user1string0")) });
    // const tx7 = await data.user1.sendTransaction({ to: receiver1, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("collection1user1string1")) });
    // const tx8 = await data.user1.sendTransaction({ to: receiver1, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("collection1user1string2")) });
    // await printTx(data, "tx6", await tx6.wait());
    // await printTx(data, "tx7", await tx7.wait());
    // await printTx(data, "tx8", await tx8.wait());
    //
    // const expiry = parseInt(new Date() / 1000) + 60 * 60;
    // const collectionOfferData = [[INPUT_COLLECTION_OFFER, ZERO_ADDRESS, 1, ethers.parseEther("1.1"), 5, expiry], [INPUT_COLLECTION_OFFER, ZERO_ADDRESS, 2, ethers.parseEther("2.2"), 5, expiry], [INPUT_COLLECTION_OFFER, ZERO_ADDRESS, 3, ethers.parseEther("3.3"), 5, expiry]];
    // const tx9 = await data.exchange.connect(data.user1).execute(collectionOfferData, data.uiFeeAccount);
    // await printTx(data, "tx9", await tx9.wait());
    //
    // const tx10 = await data.registry.connect(data.user1).setApprovalForAll(data.exchange.target, true);
    // // await printTx(data, "tx10", await tx10.wait());
    //
    // await printState(data, "DEBUG");
    //
    // const sellData1 = [[INPUT_COLLECTION_BUY, data.user1.address, 6, ethers.parseEther("1.1"), 0, 0]];
    // const tx11 = await data.exchange.connect(data.user2).execute(sellData1, data.uiFeeAccount);
    // await printTx(data, "tx11", await tx11.wait());


    await printState(data, "End");
  });


  describe("Receiver", function () {
    it.skip("Receiver #1", async function () {
      const data = await loadFixture(deployFixture);
      // await printState(data, "Empty");

      addHash("", data, null);
      addHash("", data, "Bleergh");

      // Revert if ETH sent
      await expect(data.user0.sendTransaction({ to: data.receiver, value: ethers.parseEther("0.1"), data: ethers.hexlify(ethers.toUtf8Bytes("Bleergh")) })).to.be.reverted;

      // Registration of null data is OK
      await expect(data.user0.sendTransaction({ to: data.receiver, value: 0, data: null }))
        .to.emit(data.registry, "Registered");
        // .withArgs(lockedAmount, anyValue); // We accept any value as `when` arg

      // Registration of duplicated null data is not OK
      await expect(data.user1.sendTransaction({ to: data.receiver, value: 0, data: null })).to.be.revertedWithCustomError(
        data.registry,
        "AlreadyRegistered"
      ).withArgs(anyValue, data.user0.address, 0, anyValue);

      // Registration of a string is OK
      addHash("", data, ethers.hexlify(ethers.toUtf8Bytes("Bleergh")));
      await expect(data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("Bleergh")) }))
        .to.emit(data.registry, "Registered");

      // Registration of a duplicated string is not OK
      await expect(data.user1.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("Bleergh")) })).to.be.revertedWithCustomError(
        data.registry,
        "AlreadyRegistered"
      ).withArgs(anyValue, data.user0.address, 1, anyValue);

      await expect(data.registry.connect(data.user0).transfer(ZERO_ADDRESS, 1))
        .to.emit(data.registry, "Transfer");

      await expect(data.user2.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("Bleergh")) }))
        .to.emit(data.registry, "Registered");

      // await printState(data, "End");
    });
  });


  describe("Registry", function () {
    it.skip("Registry #1", async function () {
      const data = await loadFixture(deployFixture);
      // await printState(data, "Empty");

      // Only Receiver can register
      await expect(data.registry.register(DUMMY_HASH, data.user0.address)).to.be.revertedWithCustomError(
        data.registry,
        "InvalidCollection"
      );

      addHash("", data, "user0string");
      addHash("", data, "user1string");
      addHash("", data, "user2string");

      // Check owner
      const tx0 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string")) });
      const tx1 = await data.user1.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user1string")) });
      const tx2 = await data.user2.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user2string")) });

      // Check ownerOf
      expect(await data.registry.ownerOf(0)).to.equal(data.user0.address);
      expect(await data.registry.ownerOf(1)).to.equal(data.user1.address);
      expect(await data.registry.ownerOf(2)).to.equal(data.user2.address);

      // Check length
      expect(await data.registry.itemsCount()).to.equal(3);

      // Owner can transfer tokens
      const tx3 = await data.registry.connect(data.user0).transfer(data.user1.address, 0);
      expect(await data.registry.ownerOf(0)).to.equal(data.user1.address);

      // Non-owner cannot transfer token
      await expect(
        data.registry.connect(data.user0).transfer(data.user2.address, 0)).to.be.revertedWithCustomError(
        data.registry,
        "NotOwnerNorApproved"
      );

      // Test isApprovedForAll
      expect(await data.registry.isApprovedForAll(data.user1, data.user0)).to.equal(false);

      // Approve for user0 to transfer user1's tokens
      const tx4 = await data.registry.connect(data.user1).setApprovalForAll(data.user0.address, true);

      // Test isApprovedForAll
      expect(await data.registry.isApprovedForAll(data.user1, data.user0)).to.equal(true);

      // Transfer and check
      await data.registry.connect(data.user0).transfer(data.user2.address, 0);
      expect(await data.registry.ownerOf(0)).to.equal(data.user2.address);

      // await printState(data, "End");
    });
  });


  describe("Registry - Collections", function () {
    it.skip("Registry - Collections #1", async function () {
      const data = await loadFixture(deployFixture);
      // await printState(data, "Empty");

      addHash("", data, null);
      addHash("", data, "user0string");
      addHash("", data, "user1string");
      addHash("", data, "user2string");

      // Check owner
      const tx0 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: null });
      const tx1 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string")) });
      const tx2 = await data.user1.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user1string")) });
      const tx3 = await data.user2.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user2string")) });
      await printTx(data, "tx0", await tx0.wait());
      await printTx(data, "tx1", await tx1.wait());
      await printTx(data, "tx2", await tx2.wait());
      await printTx(data, "tx3", await tx3.wait());

      await printState(data, "DEBUG");

      // uint64 private constant LOCK_NONE = 0x00;
      // uint64 private constant LOCK_OWNER_SET_DESCRIPTION = 0x01;
      // uint64 private constant LOCK_OWNER_REMOVE_ITEM = 0x02;
      // uint64 private constant LOCK_USER_ADD_ITEM = 0x04;
      // uint64 private constant LOCK_COLLECTION = 0x08;
      // uint64 private constant LOCK_ROYALTIES = 0x10;

      const royalties = [
        [ data.royalty0.address, "10" ],
        [ data.royalty1.address, "20" ],
        [ data.royalty2.address, "30" ],
      ];

      const tx4 = await data.registry.connect(data.user0).newCollection("Name #1", "Collection #1", 0, royalties);
      await printTx(data, "tx4", await tx4.wait());
      // expect(await data.exchange.newOwner()).to.equal(data.user2.address);

      await expect(
        data.registry.connect(data.user0).newCollection("Name #1", "Collection #1", 0, [])).to.be.revertedWithCustomError(
        data.registry,
        "DuplicateCollectionName"
      );

      const receiver1 = await data.registry.getReceiver(1);
      data.accountNames[receiver1.toLowerCase()] = "receiver#1";

      addHash("Name #1", data, "collection1user1string");

      const tx5 = await data.user1.sendTransaction({ to: receiver1, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("collection1user1string")) });
      await printTx(data, "tx5", await tx5.wait());

      // const collectionData = await data.registry.getCollections(10, 0);
      // // console.log("collectionData: " + JSON.stringify(collectionData, null, 2));
      // console.log("collectionData: " + JSON.stringify(collectionData, (_, v) => typeof v === 'bigint' ? v.toString() : v));

      await printState(data, "End");
    });
  });


  describe("Exchange - Owned", function () {
    it.skip("Exchange - Owned #1", async function () {
      const data = await loadFixture(deployFixture);
      // await printState(data, "Empty");

      // owner() function
      expect(await data.exchange.owner()).to.equal(data.deployer.address);

      // Non-owner cannot transfer ownership
      await expect(
        data.exchange.connect(data.user0).transferOwnership(data.user1.address)).to.be.revertedWithCustomError(
        data.exchange,
        "NotOwner"
      );

      // Non-newOwner cannot accept ownership transfer
      await expect(
        data.exchange.connect(data.user2).acceptOwnership()).to.be.revertedWithCustomError(
        data.exchange,
        "NotNewOwner"
      );

      const tx1 = await data.exchange.connect(data.deployer).transferOwnership(data.user2.address);
      expect(await data.exchange.newOwner()).to.equal(data.user2.address);

      const tx2 = await data.exchange.connect(data.user2).acceptOwnership();
      expect(await data.exchange.owner()).to.equal(data.user2.address);
      expect(await data.exchange.newOwner()).to.equal(ZERO_ADDRESS);

      // await printState(data, "End");
    });
  });


  describe("Exchange - Bulk Transfer", function () {
    it.skip("Exchange - Bulk Transfer #1", async function () {
      const data = await loadFixture(deployFixture);
      // await printState(data, "Empty");

      addHash("", data, "user0string0");
      addHash("", data, "user1string1");
      addHash("", data, "user2string0");
      addHash("", data, "user2string1");
      addHash("", data, "user2string2");

      const tx0 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string0")) });
      const tx1 = await data.user1.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user1string1")) });
      const tx2 = await data.user2.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user2string0")) });
      const tx3 = await data.user2.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user2string1")) });
      const tx4 = await data.user2.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user2string2")) });

      // Token owner cannot bulk transfer before approving
      await expect(
        data.exchange.connect(data.user2).bulkTransfer(data.user0.address, [2, 4])).to.be.revertedWithCustomError(
        data.registry,
        "NotOwnerNorApproved"
      );

      const tx6 = await data.registry.connect(data.user2).setApprovalForAll(data.exchange.target, true);

      // Only token owner can bulk transfer
      await expect(
        data.exchange.connect(data.user1).bulkTransfer(data.user0.address, [2, 4])).to.be.revertedWithCustomError(
        data.exchange,
        "OnlyTokenOwnerCanTransfer"
      );

      const tx7 = await data.exchange.connect(data.user2).bulkTransfer(data.user0.address, [2, 4]);

      expect(await data.registry.ownerOf(2)).to.equal(data.user0.address);
      expect(await data.registry.ownerOf(4)).to.equal(data.user0.address);

      // await printState(data, "End");

    });
  });


  // TODO: Fix bug
  describe("Exchange - Update Fee", function () {
    it.skip("Exchange - Update Fee #1", async function () {
      const data = await loadFixture(deployFixture);
      // await printState(data, "Empty");

      expect(await data.exchange.fee()).to.equal(10);

      // Non-owner cannot update the fee
      await expect(
        data.exchange.connect(data.user2).updateFee(11)).to.be.revertedWithCustomError(
        data.exchange,
        "NotOwner"
      );

      // Cannot set fee > MAX_FEE
      await expect(
        data.exchange.connect(data.deployer).updateFee(11)).to.be.revertedWithCustomError(
        data.exchange,
        "InvalidFee"
      ).withArgs(11, 10);

      // Update fee to 5bp
      await expect(data.exchange.connect(data.deployer).updateFee(5))
        .to.emit(data.exchange, "FeeUpdated")
        .withArgs(10, 5, anyValue);
      expect(await data.exchange.fee()).to.equal(5);

      addHash("", data, "user0string0");
      addHash("", data, "user0string1");
      addHash("", data, "user0string2");
      addHash("", data, "user0string3");
      addHash("", data, "user0string4");

      const tx0 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string0")) });
      const tx1 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string1")) });
      const tx2 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string2")) });
      const tx3 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string3")) });
      const tx4 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("user0string4")) });

      const expiry = parseInt(new Date() / 1000) + 60 * 60;
      const offerData = [[INPUT_OFFER, ZERO_ADDRESS, 1, ethers.parseEther("1.23"), expiry], [INPUT_OFFER, ZERO_ADDRESS, 2, ethers.parseEther("1.23"), expiry], [INPUT_OFFER, ZERO_ADDRESS, 3, ethers.parseEther("1.23"), expiry]];
      const tx5 = await data.exchange.connect(data.user0).execute(offerData, data.uiFeeAccount);
      await printTx(data, "tx5", await tx5.wait());

      const tx6 = await data.registry.connect(data.user0).setApprovalForAll(data.exchange.target, true);
      // await printTx(data, "tx6", await tx6.wait());

      await printState(data, "DEBUG");

      const buyData1 = [[INPUT_BUY, data.user0.address, 1, ethers.parseEther("1.23"), 0], [INPUT_BUY, data.user0.address, 3, ethers.parseEther("1.23"), 0]];
      const tx7 = await data.exchange.connect(data.user1).execute(buyData1, data.uiFeeAccount);
      await printTx(data, "tx7", await tx7.wait());

      expect(await data.weth.balanceOf(data.user1)).to.equal(ethers.parseEther("997.54"));
      expect(await data.weth.balanceOf(data.feeAccount)).to.equal(ethers.parseEther("0.000615"));
      expect(await data.weth.balanceOf(data.uiFeeAccount)).to.equal(ethers.parseEther("0.000615"));

      // Update fee to 7bp
      await expect(data.exchange.connect(data.deployer).updateFee(7))
        .to.emit(data.exchange, "FeeUpdated")
        .withArgs(5, 7, anyValue);
      expect(await data.exchange.fee()).to.equal(7);

      const buyData2 = [[INPUT_BUY, data.user0.address, 2, ethers.parseEther("1.23"), 0]];
      const tx8 = await data.exchange.connect(data.user2).execute(buyData2, data.uiFeeAccount);
      await printTx(data, "tx8", await tx8.wait());

      expect(await data.weth.balanceOf(data.user2)).to.equal(ethers.parseEther("998.77"));
      expect(await data.weth.balanceOf(data.feeAccount)).to.equal(ethers.parseEther("0.0010455"));
      expect(await data.weth.balanceOf(data.uiFeeAccount)).to.equal(ethers.parseEther("0.0010455"));

      const bidData = [[INPUT_BID, ZERO_ADDRESS, 0, ethers.parseEther("1.11"), expiry], [INPUT_BID, ZERO_ADDRESS, 1, ethers.parseEther("1.11"), expiry], [INPUT_BID, ZERO_ADDRESS, 2, ethers.parseEther("1.11"), expiry], [INPUT_BID, ZERO_ADDRESS, 3, ethers.parseEther("1.11"), expiry], [INPUT_BID, ZERO_ADDRESS, 4, ethers.parseEther("1.11"), expiry]];
      const tx9 = await data.exchange.connect(data.user2).execute(bidData, data.uiFeeAccount);
      await printTx(data, "tx9", await tx9.wait());

      const tx10 = await data.registry.connect(data.user2).setApprovalForAll(data.exchange.target, true);

      // TODO: BUG here with user0 and user2 mixed up
      // await printState(data, "DEBUG");
      //
      // const sellData1 = [[INPUT_SELL, data.user2.address, 2, ethers.parseEther("1.11"), 0]];
      // const tx11 = await data.exchange.connect(data.user0).execute(sellData1, ZERO_ADDRESS);
      // await printTx(data, "tx11", await tx11.wait());
      //
      // expect(await data.weth.balanceOf(data.user0)).to.equal(ethers.parseEther("1004.797132"));
      // expect(await data.weth.balanceOf(data.feeAccount)).to.equal(ethers.parseEther("0.0018225"));
      // expect(await data.weth.balanceOf(data.uiFeeAccount)).to.equal(ethers.parseEther("0.0010455"));

      await printState(data, "End");
    });
  });


  describe("Exchange - Offer & Buy", function () {
    it.skip("Exchange - Offer & Buy #1", async function () {
      const data = await loadFixture(deployFixture);
      // await printState(data, "Empty");

      // await printState(data, "End");
    });
  });


  describe("Exchange - Bid & Sell", function () {
    it.skip("Exchange - Bid & Sell #1", async function () {
      const data = await loadFixture(deployFixture);
      // await printState(data, "Empty");

      // await printState(data, "End");
    });
  });


  describe("Registry OLD", function () {
    it.skip("Registry OLD #1", async function () {
      const data = await loadFixture(deployFixture);
      await printState(data, "Empty");

      await expect(data.user0.sendTransaction({ to: data.receiver, value: ethers.parseEther("0.1"), data: ethers.hexlify(ethers.toUtf8Bytes("123")) })).to.be.reverted;

      const string0 = "abcdef";
      addHash(data, string0);
      console.log("      string0.length: " + string0.length);
      const tx0 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes(string0)) });
      await printTx(data, "tx0", await tx0.wait());
      await expect(data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes(string0)) })).to.be.revertedWithCustomError(
        data.registry,
        "AlreadyRegistered"
      ).withArgs(anyValue, data.user0.address, 0, anyValue);
      await expect(data.registry.register(DUMMY_HASH, data.user0.address)).to.be.revertedWithCustomError(
        data.registry,
        "InvalidCollection"
      );
      const tx0Regular = await data.user0.sendTransaction({ to: data.user0.address, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes(string0)) });
      await printTx(data, "tx0Regular", await tx0Regular.wait());
      await printState(data, "Single Entry");

      const string1 = "abcdefgh";
      addHash(data, string1);
      console.log("      string1.length: " + string1.length);
      const tx1 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes(string1)) });
      await printTx(data, "tx1", await tx1.wait());
      const tx1Regular = await data.user0.sendTransaction({ to: data.user0.address, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes(string1)) });
      await printTx(data, "tx1Regular", await tx1Regular.wait());
      await printState(data, "2 Entries");

      const string2 = "1".repeat(1000);
      addHash(data, string2);
      console.log("      string2.length: " + string2.length);
      const tx2 = await data.user1.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes(string2)) });
      await printTx(data, "tx2", await tx2.wait());
      const tx2Regular = await data.user1.sendTransaction({ to: data.user1.address, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes(string2)) });
      await printTx(data, "tx2Regular", await tx2Regular.wait());
      await printState(data, "3 Entries, 2 Accounts");

      await expect(
        data.registry.connect(data.user0).transfer(data.user1.address, 2)).to.be.revertedWithCustomError(
        data.registry,
        "NotOwnerNorApproved"
      );
      console.log("      user0 -> registry.transfer(" + getAccountName(data, data.user1.address) + ", 1)");
      const tx3 = await data.registry.connect(data.user0).transfer(data.user1.address, 1);
      await printTx(data, "tx3", await tx3.wait());
      await printState(data, "3 Entries, 2 Accounts, Transferred");

      const string4 = "22".repeat(10000);
      addHash(data, string4);
      console.log("      string4.length: " + string4.length);
      const tx4 = await data.user1.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes(string4)) });
      await printTx(data, "tx4", await tx4.wait());
      const tx4Regular = await data.user1.sendTransaction({ to: data.user1.address, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes(string4)) });
      await printTx(data, "tx4Regular", await tx4Regular.wait());
      await printState(data, "4 Entries, 2 Accounts, large item");

      const string5 = "3".repeat(1000000);
      addHash(data, string5);
      console.log("      string5.length: " + string5.length);
      const tx5 = await data.user1.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes(string5)) });
      await printTx(data, "tx5", await tx5.wait());
      const tx5Regular = await data.user1.sendTransaction({ to: data.user1.address, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes(string5)) });
      await printTx(data, "tx5Regular", await tx5Regular.wait());
      await printState(data, "5 Entries, 2 Accounts, large items");

      await expect(
        data.exchange.connect(data.user1).bulkTransfer(data.user0.address, [0])).to.be.revertedWithCustomError(
        data.exchange,
        "OnlyTokenOwnerCanTransfer"
      );
      await expect(
        data.exchange.connect(data.user1).bulkTransfer(data.user0.address, [1, 2])).to.be.revertedWithCustomError(
        data.registry,
        "NotOwnerNorApproved"
      );

      console.log("      user1 -> registry.setApprovalForAll(" + getAccountName(data, data.exchange.target) + ", true)");
      const tx6 = await data.registry.connect(data.user1).setApprovalForAll(data.exchange.target, true);
      await printTx(data, "tx6", await tx6.wait());

      console.log("      user1 -> exchange.bulkTransfer(" + getAccountName(data, data.user0.address) + ", [1, 3])");
      const tx7 = await data.exchange.connect(data.user1).bulkTransfer(data.user0.address, [1, 3]);
      await printTx(data, "tx7", await tx7.wait());
      await printState(data, "5 Entries, 2 Accounts, Transferred");
    });
  });


  describe("Exchange OLD", function () {
    it.skip("Exchange OLD #1", async function () {
      const data = await loadFixture(deployFixture);
      await printState(data, "Empty");

      addHash(data, "text0");
      addHash(data, "text1");
      addHash(data, "text2");
      addHash(data, "text3");
      addHash(data, "text4");
      const tx0 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("text0")) });
      const tx1 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("text1")) });
      const tx2 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("text2")) });
      const tx3 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("text3")) });
      const tx4 = await data.user0.sendTransaction({ to: data.receiver, value: 0, data: ethers.hexlify(ethers.toUtf8Bytes("text4")) });
      await printTx(data, "tx0", await tx0.wait());

      console.log("      user0 -> registry.setApprovalForAll(exchange, true)");
      const tx5a = await data.registry.connect(data.user0).setApprovalForAll(data.exchange.target, true);
      await printTx(data, "tx5a", await tx5a.wait());
      console.log("      user1 -> registry.setApprovalForAll(exchange, true)");
      const tx5b = await data.registry.connect(data.user1).setApprovalForAll(data.exchange.target, true);
      await printTx(data, "tx5b", await tx5b.wait());

      const now = parseInt(new Date() / 1000);
      const expiry = parseInt(now) + 60 * 60;
      const offerData = [[1, ethers.parseEther("11"), expiry], [2, ethers.parseEther("22"), expiry], [3, ethers.parseEther("33"), expiry]];
      console.log("      user0 -> exchange.offer(offerData)");
      const tx6 = await data.exchange.connect(data.user0).offer(offerData);
      await printTx(data, "tx6", await tx6.wait());

      await printState(data, "After Offers Setup");

      const buyData = [[data.user0.address, 1, ethers.parseEther("11")], [data.user0.address, 3, ethers.parseEther("33")]];
      console.log("      user1 -> exchange.buy(buyData)");
      const tx7 = await data.exchange.connect(data.user1).buy(buyData, data.uiFeeAccount, { value: ethers.parseEther("110") });
      await printTx(data, "tx7", await tx7.wait());

      await printState(data, "After Purchases");

      const bidData = [[1, ethers.parseEther("11"), expiry], [2, ethers.parseEther("22"), expiry], [3, ethers.parseEther("33"), expiry]];
      console.log("      user2 -> exchange.bid(bidData)");
      const tx8 = await data.exchange.connect(data.user2).bid(bidData);
      await printTx(data, "tx8", await tx8.wait());

      await printState(data, "After Bids Setup");

      const sellData = [[data.user2.address, 1, ethers.parseEther("11")], [data.user2.address, 3, ethers.parseEther("33")]];
      console.log("      user1 -> exchange.sell(sellData)");
      const tx9 = await data.exchange.connect(data.user1).sell(sellData, data.uiFeeAccount);
      await printTx(data, "tx9", await tx9.wait());

      await printState(data, "After Sales");

      console.log("      deployer -> exchange.withdraw(0, 0)");
      const tx10 = await data.exchange.connect(data.deployer).withdraw(ZERO_ADDRESS, 0);
      await printTx(data, "tx10", await tx10.wait());
      console.log("      deployer -> exchange.withdraw(WETH, 0)");
      const tx11 = await data.exchange.connect(data.deployer).withdraw(data.weth.target, 0);
      await printTx(data, "tx11", await tx11.wait());

      await printState(data, "After Deployer Withdraw");
    });
  });


  // describe("Withdrawals", function () {
  //   describe("Validations", function () {
  //     it.skip("Should revert with the right error if called too soon", async function () {
  //       const { lock } = await loadFixture(deployOneYearLockFixture);
  //
  //       await expect(lock.withdraw()).to.be.revertedWith(
  //         "You can't withdraw yet"
  //       );
  //     });
  //
  //     it.skip("Should revert with the right error if called from another account", async function () {
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
  //     it.skip("Shouldn't fail if the unlockTime has arrived and the owner calls it", async function () {
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
  //     it.skip("Should emit an event on withdrawals", async function () {
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
  //     it.skip("Should transfer the funds to the owner", async function () {
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


// 365 * 24 * 60 * 60 = 2191536000 or 2,191,536,000 per year
// 2^64 = 18, 446,744,073,709,551,616 <- expiry = 2^64 / 365 / 24 / 60 / 60

// 2^16 = 65,536
// 2^32 = 4,294,967,296
// 2^48 = 281,474,976,710,656 = 128,437.304571157398281 years for unixtime
// 2^60 = 1, 152,921,504, 606,846,976 <- ok for price max 1_000_000 9dp
// 2^64 = 18, 446,744,073,709,551,616 <- expiry
// 2^72 = 4,722,366,482,869,645,213,696
// 2^80 = 1,208,925, 819,614,629, 174,706,176 <- ok for price max 1_000_000 18dp
// 2^96 = 79,228,162,514, 264,337,593,543,950,336
// 2^112 = 5192296858534827628530496329220096
// 2^128 = 340, 282,366,920,938,463,463, 374,607,431,768,211,456
// 2^256 = 115,792, 089,237,316,195,423,570, 985,008,687,907,853,269, 984,665,640,564,039,457, 584,007,913,129,639,936
