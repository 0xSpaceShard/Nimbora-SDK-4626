import { expect } from "chai";
import { keccak256, parseEther, toUtf8Bytes } from "ethers";
import { ethers } from "hardhat";

const SHARES_NAME = "usdc bridge"
const SHARES_SYMBOL = "usdc_b"
const RANDOM_ADDRESS = "0x0262e8331dfA2d2BeCF26395270BCe6a9Ac5A197"

const l2_BRIDGE = 839373
const l2_FW = 242244

const ADMIN_ROLE = "0x0000000000000000000000000000000000000000000000000000000000000000"
const PROCESS_ROLE = keccak256(toUtf8Bytes("0x01"));
const PAUSE_ROLE = keccak256(toUtf8Bytes("0x02"));
const LP_ROLE = keccak256(toUtf8Bytes("0x03"));

describe("Test", function () {

  async function loadFixture() {
    const owner = await ethers.provider.getSigner(0);
    console.log("Owner address:", owner.address);

    const relayer = await ethers.provider.getSigner(1);
    console.log("Relayer address:", relayer.address);

    const user1 = await ethers.provider.getSigner(2);
    console.log("user1:", relayer.address);

    const user2 = await ethers.provider.getSigner(3);
    console.log("user2:", relayer.address);

    const weth_mock = await ethers.getContractFactory('WETH');
    const weth = await weth_mock.deploy();
    const weth_address = await weth.getAddress()

    const weth_dust_mock = await ethers.getContractFactory('WETH');
    const weth_dust = await weth_dust_mock.deploy();

    await owner.sendTransaction({
      to: weth_address,
      value: parseEther("100"),
    });

    await weth.transfer(user1.address, ethers.parseEther("100"));
    await weth.transfer(user2.address, ethers.parseEther("100"));

    const starkGate_mock = await ethers.getContractFactory('StarkGate');
    const starkGate = await starkGate_mock.deploy(weth_address);
    const starkGate_address = await starkGate.getAddress();

    const starkGateEth_mock = await ethers.getContractFactory('StarkGateEth');
    const starkGateEth = await starkGateEth_mock.deploy();
    const starkGateEth_address = await starkGateEth.getAddress();

    await owner.sendTransaction({
      to: starkGateEth_address,
      value: parseEther("100"),
    });

    await weth.transfer(starkGate_address, ethers.parseEther("300"));

    const starknet_mock = await ethers.getContractFactory('Starknet');
    const starknet = await starknet_mock.deploy(); ``
    const starknet_address = await starknet.getAddress();

    const fw_mock = await ethers.getContractFactory('FWERC20');
    const fw = await fw_mock.deploy(
      weth_address,
      SHARES_NAME,
      SHARES_SYMBOL,
      starknet_address,
      starkGate_address,
      l2_BRIDGE,
      l2_FW);

    const fweth_mock = await ethers.getContractFactory('FWETH');
    const fweth = await fweth_mock.deploy(
      SHARES_NAME,
      SHARES_SYMBOL,
      starknet_address,
      starkGateEth_address,
      l2_BRIDGE,
      l2_FW);


    const provider = ethers.provider
    return { owner, relayer, user1, user2, weth, starkGate, starknet, fw, fweth, weth_dust, provider };
  }

  describe("Deployment", function () {
    it("Should set the right asset", async function () {
      const { weth, fw } = await loadFixture();
      const usdc_address = await weth.getAddress()
      expect(await fw.asset()).to.equal(usdc_address);
    });


    it("Should set the right starknet", async function () {
      const { starknet, fw } = await loadFixture();
      const starknet_address = await starknet.getAddress()
      expect(await fw.starknetCore()).to.equal(starknet_address);
    });

    it("Should set the right l1Bridge", async function () {
      const { starkGate, fw } = await loadFixture();
      const starkGate_address = await starkGate.getAddress()
      expect(await fw._l1Bridge()).to.equal(starkGate_address);
    });

    it("Should set the right l2Bridge", async function () {
      const { fw } = await loadFixture();
      expect(await fw._l2Bridge()).to.equal(l2_BRIDGE);
    });

    it("Should set the right l2FW", async function () {
      const { fw } = await loadFixture();
      expect(await fw._l2FW()).to.equal(l2_FW);
    });
  });


  describe("Access", function () {
    it("Should raise access error 1", async function () {
      const { user1, fw } = await loadFixture();
      await expect(
        fw.connect(user1).setL2FW(RANDOM_ADDRESS)
      ).to.be.revertedWith(`AccessControl: account ${user1.address.toLocaleLowerCase()} is missing role ${ADMIN_ROLE}`);
    });

    it("Should raise access error 2", async function () {
      const { user1, fw } = await loadFixture();
      await expect(
        fw.connect(user1).grantRole(LP_ROLE, user1.address)
      ).to.be.revertedWith(`AccessControl: account ${user1.address.toLocaleLowerCase()} is missing role ${ADMIN_ROLE}`);
    });

    it("Should raise access error 3", async function () {
      const { user1, fw } = await loadFixture();
      await expect(
        fw.connect(user1).revokeRole(LP_ROLE, user1.address)
      ).to.be.revertedWith(`AccessControl: account ${user1.address.toLocaleLowerCase()} is missing role ${ADMIN_ROLE}`);
    });

    it("Should raise access error 4", async function () {
      const { user1, fw } = await loadFixture();
      await expect(
        fw.connect(user1).pause()
      ).to.be.revertedWith(`AccessControl: account ${user1.address.toLocaleLowerCase()} is missing role ${PAUSE_ROLE}`);
    });

    it("Should raise access error 5", async function () {
      const { user1, fw } = await loadFixture();
      await expect(
        fw.connect(user1).unpause()
      ).to.be.revertedWith(`AccessControl: account ${user1.address.toLocaleLowerCase()} is missing role ${PAUSE_ROLE}`);
    });


    it("Should raise access error 6", async function () {
      const { user1, fw, weth } = await loadFixture();
      await expect(
        fw.connect(user1).harvestErc20(weth)
      ).to.be.revertedWith(`AccessControl: account ${user1.address.toLocaleLowerCase()} is missing role ${ADMIN_ROLE}`);
    });

    it("Should raise access error 7", async function () {
      const { user1, fw, weth } = await loadFixture();
      await expect(
        fw.connect(user1).harvestEth()
      ).to.be.revertedWith(`AccessControl: account ${user1.address.toLocaleLowerCase()} is missing role ${ADMIN_ROLE}`);
    });

    it("Should raise access error 8", async function () {
      const { user1, fw } = await loadFixture();
      await expect(
        fw.connect(user1).handleBridgeUsers([])
      ).to.be.revertedWith(`AccessControl: account ${user1.address.toLocaleLowerCase()} is missing role ${PROCESS_ROLE}`);
    });

    it("Should raise access error 9", async function () {
      const { user1, fw } = await loadFixture();
      await expect(
        fw.connect(user1).handleBridgeUsersManually([])
      ).to.be.revertedWith(`AccessControl: account ${user1.address.toLocaleLowerCase()} is missing role ${PROCESS_ROLE}`);
    });

    it("Should raise access error 10", async function () {
      const { user1, fw } = await loadFixture();
      await expect(
        fw.connect(user1).deposit("0x1", RANDOM_ADDRESS)
      ).to.be.revertedWith(`AccessControl: account ${user1.address.toLocaleLowerCase()} is missing role ${LP_ROLE}`);
    });

    it("Should raise access error 11", async function () {
      const { user1, fw } = await loadFixture();
      await expect(
        fw.connect(user1).mint("0x1", RANDOM_ADDRESS)
      ).to.be.revertedWith(`AccessControl: account ${user1.address.toLocaleLowerCase()} is missing role ${LP_ROLE}`);
    });

    it("Should raise access error 12", async function () {
      const { user1, fw } = await loadFixture();
      await expect(
        fw.connect(user1).redeem("0x1", RANDOM_ADDRESS, RANDOM_ADDRESS)
      ).to.be.revertedWith(`AccessControl: account ${user1.address.toLocaleLowerCase()} is missing role ${LP_ROLE}`);
    });

    it("Should raise access error 13", async function () {
      const { user1, fw } = await loadFixture();
      await expect(
        fw.connect(user1).withdraw("0x1", RANDOM_ADDRESS, RANDOM_ADDRESS)
      ).to.be.revertedWith(`AccessControl: account ${user1.address.toLocaleLowerCase()} is missing role ${LP_ROLE}`);
    });
  });



  describe("Failures", function () {
    it("Should raise FWAlreadySet", async function () {
      const { owner, fw } = await loadFixture();
      await expect(
        fw.connect(owner).setL2FW(RANDOM_ADDRESS)
      ).to.be.rejectedWith("FWAlreadySet()");
    });


    it("Should raise AddressNul", async function () {
      const { fw, owner } = await loadFixture();
      const recipientInfo = {
        user: ethers.ZeroAddress,
        debt: ethers.parseEther("15"),
        nonce: 0,
        l2Block: 1
      };
      await expect(
        fw.connect(owner).handleBridgeUsers([recipientInfo])
      ).to.be.rejectedWith("AddressNul()");
    });

    it("Should raise AmountNul", async function () {
      const { fw, owner } = await loadFixture();
      const recipientInfo = {
        user: RANDOM_ADDRESS,
        debt: ethers.parseEther("0"),
        nonce: 0,
        l2Block: 1
      };
      await expect(
        fw.connect(owner).handleBridgeUsers([recipientInfo])
      ).to.be.rejectedWith("AmountNul()");
    });

    it("Should raise Pausable: paused", async function () {
      const { owner, fw } = await loadFixture();
      await fw.connect(owner).pause()
      const payload = {
        nonce: 123,
        amountUnderlying: ethers.parseEther("1.0"),
        amountLpFees: ethers.parseEther("0.01"),
      };
      await expect(
        fw.connect(owner).executeBatch(payload)
      ).to.be.revertedWith("Pausable: paused");
    });

    it("Should raise InvalidBatchNonce", async function () {
      const { owner, fw } = await loadFixture();
      const payload = {
        nonce: 123,
        amountUnderlying: ethers.parseEther("1.0"),
        amountLpFees: ethers.parseEther("0.01"),
      };
      await expect(
        fw.connect(owner).executeBatch(payload)
      ).to.be.rejectedWith("InvalidBatchNonce()");
    });



    it("Should raise InsufficientUnderlying", async function () {
      const { fw, user1, relayer, weth, owner } = await loadFixture();
      await fw.connect(owner).grantRole(PROCESS_ROLE, relayer.address)

      const recipientInfo = {
        user: user1.address,
        debt: ethers.parseEther("1"),
        nonce: 1,
        l2Block: 1
      };
      const fw_address = await fw.getAddress()
      await weth.transfer(fw_address, ethers.parseEther("15"));
      await expect(
        fw.connect(relayer).handleBridgeUsers([recipientInfo])
      ).to.be.rejectedWith("InsufficientUnderlying()");
    });

    it("Should raise blockAleadyProcessed", async function () {
      const { owner, fw, user1, weth, relayer, user2 } = await loadFixture();
      await fw.connect(owner).grantRole(LP_ROLE, user1.address)
      await fw.connect(owner).grantRole(PROCESS_ROLE, relayer.address)

      let fw_address = await fw.getAddress()
      await weth.connect(user1).approve(fw_address, ethers.parseEther("100"))
      await fw.connect(user1).deposit(ethers.parseEther("100"), user1)
      expect(await fw._underlyingBalance()).to.be.equal(ethers.parseEther("100"))
      expect(await fw._dueAmount()).to.be.equal(ethers.parseEther("0"))
      expect(await fw.totalAssets()).to.be.equal(ethers.parseEther("100"))
      const user1Info = {
        user: user1.address,
        debt: ethers.parseEther("25"),
        nonce: 1,
        l2Block: 2
      };
      const user2Info = {
        user: user2.address,
        debt: ethers.parseEther("25"),
        nonce: 2,
        l2Block: 1
      };

      await (fw.connect(relayer).handleBridgeUsers([user1Info]))
      await expect(fw.connect(relayer).handleBridgeUsers([user2Info])).to.be.rejectedWith("BlockAleadyProcessed()");
    });

  });

  describe("Shares trading", function () {
    it("Should deposit to the bridge", async function () {
      const { owner, fw, user1, weth } = await loadFixture();
      await fw.connect(owner).grantRole(LP_ROLE, user1.address)
      let fw_address = await fw.getAddress()
      await weth.connect(user1).approve(fw_address, ethers.parseEther("50"))
      await fw.connect(user1).deposit(ethers.parseEther("50"), user1)
      expect(await fw._underlyingBalance()).to.be.equal(ethers.parseEther("50"))
    });

    it("Should mint shares from the bridge", async function () {
      const { owner, fw, user1, weth } = await loadFixture();
      await fw.connect(owner).grantRole(LP_ROLE, user1.address)
      let fw_address = await fw.getAddress()
      await weth.connect(user1).approve(fw_address, ethers.parseEther("50"))
      await fw.connect(user1).mint(ethers.parseEther("50"), user1)
      expect(await fw._underlyingBalance()).to.be.equal(ethers.parseEther("50"))
    });

    it("Should deposit to the bridge", async function () {
      const { owner, fw, user1, weth } = await loadFixture();
      await fw.connect(owner).grantRole(LP_ROLE, user1.address)
      let fw_address = await fw.getAddress()
      await weth.connect(user1).approve(fw_address, ethers.parseEther("50"))
      await fw.connect(user1).deposit(ethers.parseEther("50"), user1)

      // await fw.connect(user1).approve(fw_address, ethers.parseEther("50"))
      await fw.connect(user1).withdraw(ethers.parseEther("50"), user1, user1)
      expect(await fw._underlyingBalance()).to.be.equal(ethers.parseEther("0"))
    });

    it("Should redeem shares from the bridge", async function () {
      const { owner, fw, user1, weth } = await loadFixture();
      await fw.connect(owner).grantRole(LP_ROLE, user1.address)
      let fw_address = await fw.getAddress()
      await weth.connect(user1).approve(fw_address, ethers.parseEther("50"))
      await fw.connect(user1).deposit(ethers.parseEther("50"), user1)

      // await fw.connect(user1).approve(fw_address, ethers.parseEther("50"))
      await fw.connect(user1).redeem(ethers.parseEther("50"), user1, user1)
      expect(await fw._underlyingBalance()).to.be.equal(ethers.parseEther("0"))
    });
  });


  describe("Bridge", function () {
    it("Should handle bridge funds", async function () {
      const { owner, fw, user1, weth, relayer, user2 } = await loadFixture();
      await fw.connect(owner).grantRole(LP_ROLE, user1.address)
      await fw.connect(owner).grantRole(PROCESS_ROLE, relayer)


      let fw_address = await fw.getAddress()
      await weth.connect(user1).approve(fw_address, ethers.parseEther("50"))
      await fw.connect(user1).deposit(ethers.parseEther("50"), user1)

      expect(await fw._underlyingBalance()).to.be.equal(ethers.parseEther("50"))
      expect(await fw._dueAmount()).to.be.equal(ethers.parseEther("0"))
      expect(await fw.totalAssets()).to.be.equal(ethers.parseEther("50"))

      const user1Info = {
        user: user1.address,
        debt: ethers.parseEther("25"),
        nonce: 1,
        l2Block: 1
      };
      const user2Info = {
        user: user2.address,
        debt: ethers.parseEther("25"),
        nonce: 2,
        l2Block: 2
      };

      await expect(fw.connect(relayer).handleBridgeUsers([user1Info, user2Info]),)
        .to.emit(fw, "BridgeUserHandled")
      // .withArgs([ user1Info, user2Info]); // Wtff?

      expect(await fw._underlyingBalance()).to.be.equal(ethers.parseEther("0"))
      expect(await fw._dueAmount()).to.be.equal(ethers.parseEther("50"))
      expect(await fw.totalAssets()).to.be.equal(ethers.parseEther("50"))
      expect(await fw._lastL2Block()).to.be.equal("2")
    });



    it("Should handle execute batch", async function () {
      const { owner, fw, user1, weth, relayer, user2 } = await loadFixture();
      await fw.connect(owner).grantRole(LP_ROLE, user1.address)
      await fw.connect(owner).grantRole(PROCESS_ROLE, relayer.address)

      let fw_address = await fw.getAddress()
      await weth.connect(user1).approve(fw_address, ethers.parseEther("50"))
      await fw.connect(user1).deposit(ethers.parseEther("50"), user1)

      const user1Info = {
        user: user1.address,
        debt: ethers.parseEther("25"),
        nonce: 0,
        l2Block: 1
      };
      const user2Info = {
        user: user2.address,
        debt: ethers.parseEther("25"),
        nonce: 1,
        l2Block: 2
      };

      await fw.connect(relayer).handleBridgeUsers([user1Info, user2Info])

      const requestpayload = {
        nonce: 0,
        amountUnderlying: ethers.parseEther("50"),
        amountLpFees: ethers.parseEther("0.5"),
      };

      await expect(fw.connect(relayer).executeBatch(requestpayload))
        .to.emit(fw, "BatchProcessed")
      expect(await fw._underlyingBalance()).to.be.equal(ethers.parseEther("50.5"))
      expect(await fw._dueAmount()).to.be.equal(ethers.parseEther("0"))
      expect(await fw.totalAssets()).to.be.equal(ethers.parseEther("50.5"))
      expect(await fw._lastL2Block()).to.be.equal("2")

      await fw.connect(user1).redeem(ethers.parseEther("50"), user1, user1)

      // 125.5 eth, -1*10^-18 rounding
      expect(await weth.balanceOf(user1)).to.be.equal(ethers.parseEther("125.499999999999999999"))
    });

    it("testing many phases, 2LPers, 2 bridge handle, 3 batches", async function () {
      const { owner, fw, user1, weth, relayer, user2 } = await loadFixture();

      await fw.connect(owner).grantRole(LP_ROLE, user1.address)
      await fw.connect(owner).grantRole(LP_ROLE, user2.address)

      await fw.connect(owner).grantRole(PROCESS_ROLE, relayer)


      let fw_address = await fw.getAddress()

      await weth.connect(user1).approve(fw_address, ethers.parseEther("50"))
      await fw.connect(user1).deposit(ethers.parseEther("50"), user1)

      await weth.connect(user2).approve(fw_address, ethers.parseEther("50"))
      await fw.connect(user2).deposit(ethers.parseEther("50"), user2)

      const user1Info = {
        user: RANDOM_ADDRESS,
        debt: ethers.parseEther("80"),
        nonce: 0,
        l2Block: 1
      };

      const user2Info = {
        user: RANDOM_ADDRESS,
        debt: ethers.parseEther("20"),
        nonce: 1,
        l2Block: 2
      };

      await fw.connect(relayer).handleBridgeUsers([user1Info, user2Info])

      expect(await fw._underlyingBalance()).to.be.equal(ethers.parseEther("0"))
      expect(await fw._dueAmount()).to.be.equal(ethers.parseEther("100"))
      expect(await fw.totalAssets()).to.be.equal(ethers.parseEther("100"))
      expect(await fw._lastL2Block()).to.be.equal("2")

      //  let's consider 0.1% fees
      const requestpayload = {
        nonce: 0,
        amountUnderlying: ethers.parseEther("50"),
        amountLpFees: ethers.parseEther("0.5"),
      };

      await expect(fw.connect(relayer).executeBatch(requestpayload))
        .to.emit(fw, "BatchProcessed")
      // .withArgs(requestpayload);  Wtff?

      expect(await fw._underlyingBalance()).to.be.equal(ethers.parseEther("50.5"))
      expect(await fw._dueAmount()).to.be.equal(ethers.parseEther("50"))
      expect(await fw.totalAssets()).to.be.equal(ethers.parseEther("100.5"))


      await fw.connect(user1).redeem(ethers.parseEther("50"), user1, user1)

      // 100.25 eth, -1*10^-18 rounding
      expect(await weth.balanceOf(user1)).to.be.equal(ethers.parseEther("100.249999999999999999"))

      expect(await fw._underlyingBalance()).to.be.equal(ethers.parseEther("0.250000000000000001"))
      expect(await fw._dueAmount()).to.be.equal(ethers.parseEther("50"))
      expect(await fw.totalAssets()).to.be.equal(ethers.parseEther("50.250000000000000001"))

      await expect(fw.connect(user2).redeem(ethers.parseEther("1"), user2, user2)).to.be.rejectedWith('ERC20: transfer amount exceeds balance')

      const requestpayload2 = {
        nonce: 1,
        amountUnderlying: ethers.parseEther("20"),
        amountLpFees: ethers.parseEther("0.2"),
      };

      await expect(fw.connect(relayer).executeBatch(requestpayload2))
        .to.emit(fw, "BatchProcessed")

      expect(await fw._underlyingBalance()).to.be.equal(ethers.parseEther("20.450000000000000001"))
      expect(await fw._dueAmount()).to.be.equal(ethers.parseEther("30"))
      expect(await fw.totalAssets()).to.be.equal(ethers.parseEther("50.450000000000000001"))

      expect(await weth.balanceOf(user2)).to.be.equal(ethers.parseEther("50"))
      await fw.connect(user2).withdraw(ethers.parseEther("10"), user2, user2)
      expect(await weth.balanceOf(user2)).to.be.equal(ethers.parseEther("60"))

      expect(await fw._underlyingBalance()).to.be.equal(ethers.parseEther("10.450000000000000001"))
      expect(await fw._dueAmount()).to.be.equal(ethers.parseEther("30"))
      expect(await fw.totalAssets()).to.be.equal(ethers.parseEther("40.450000000000000001"))

      const user3Info = {
        user: RANDOM_ADDRESS,
        debt: ethers.parseEther("10.450000000000000001"),
        nonce: 3,
        l2Block: 3
      };
      await fw.connect(relayer).handleBridgeUsers([user3Info])


      expect(await fw._underlyingBalance()).to.be.equal(ethers.parseEther("0"))
      expect(await fw._dueAmount()).to.be.equal(ethers.parseEther("40.450000000000000001"))
      expect(await fw.totalAssets()).to.be.equal(ethers.parseEther("40.450000000000000001"))
      expect(await fw._lastL2Block()).to.be.equal("3")

      await weth.connect(user1).approve(fw_address, ethers.parseEther("50"))
      await fw.connect(user1).deposit(ethers.parseEther("50"), user1)

      expect(await fw._underlyingBalance()).to.be.equal(ethers.parseEther("50"))
      expect(await fw._dueAmount()).to.be.equal(ethers.parseEther("40.450000000000000001"))
      expect(await fw.totalAssets()).to.be.equal(ethers.parseEther("90.450000000000000001"))


      const requestpayload3 = {
        nonce: 2,
        amountUnderlying: ethers.parseEther("40.450000000000000001"),
        amountLpFees: ethers.parseEther("0.4045"),
      };

      await expect(fw.connect(relayer).executeBatch(requestpayload3))
        .to.emit(fw, "BatchProcessed")

      expect(await fw._underlyingBalance()).to.be.equal(ethers.parseEther("90.854500000000000001"))
      expect(await fw._dueAmount()).to.be.equal(ethers.parseEther("0"))
      expect(await fw.totalAssets()).to.be.equal(ethers.parseEther("90.854500000000000001"))
    });


    it("Should handle bridge funds for fw-eth", async function () {
      const { owner, fweth, user1, weth, relayer, user2 } = await loadFixture();
      await fweth.connect(owner).grantRole(LP_ROLE, user1.address)
      await fweth.connect(owner).grantRole(PROCESS_ROLE, relayer)

      await fweth.connect(owner).deposit(owner, { value: ethers.parseEther("50") })
      expect(await fweth._underlyingBalance()).to.be.equal(ethers.parseEther("50"))
      expect(await fweth._dueAmount()).to.be.equal(ethers.parseEther("0"))
      expect(await fweth.totalAssets()).to.be.equal(ethers.parseEther("50"))

      const user1Info = {
        user: user1.address,
        debt: ethers.parseEther("25"),
        nonce: 1,
        l2Block: 2
      };
      const user2Info = {
        user: user2.address,
        debt: ethers.parseEther("25"),
        nonce: 2,
        l2Block: 3
      };

      await expect(fweth.connect(relayer).handleBridgeUsers([user1Info, user2Info]),)
        .to.emit(fweth, "BridgeUserHandled")

      expect(await fweth._underlyingBalance()).to.be.equal(ethers.parseEther("0"))
      expect(await fweth._dueAmount()).to.be.equal(ethers.parseEther("50"))
      expect(await fweth.totalAssets()).to.be.equal(ethers.parseEther("50"))
      expect(await fweth._lastL2Block()).to.be.equal("3")
    });

    it("Should handle execute batch for fw-eth", async function () {
      const { owner, fweth, user1, relayer, user2, provider } = await loadFixture();
      await fweth.connect(owner).grantRole(LP_ROLE, user1.address)
      await fweth.connect(owner).grantRole(PROCESS_ROLE, relayer)


      const earlyBalance = await provider.getBalance(user1)
      await fweth.connect(owner).deposit(owner, { value: ethers.parseEther("50") })
      expect(await fweth._underlyingBalance()).to.be.equal(ethers.parseEther("50"))
      expect(await fweth._dueAmount()).to.be.equal(ethers.parseEther("0"))
      expect(await fweth.totalAssets()).to.be.equal(ethers.parseEther("50"))

      const user1Info = {
        user: user2.address,
        debt: ethers.parseEther("25"),
        nonce: 1,
        l2Block: 1
      };
      const user2Info = {
        user: user2.address,
        debt: ethers.parseEther("25"),
        nonce: 2,
        l2Block: 2
      };

      await fweth.connect(relayer).handleBridgeUsers([user1Info, user2Info])

      //  let's consider 0.1% fees
      const requestpayload = {
        nonce: 0,
        amountUnderlying: ethers.parseEther("50"),
        amountLpFees: ethers.parseEther("0.5"),
      };

      await expect(fweth.connect(relayer).executeBatch(requestpayload))
        .to.emit(fweth, "BatchProcessed")
      expect(await fweth._underlyingBalance()).to.be.equal(ethers.parseEther("50.5"))
      expect(await fweth._dueAmount()).to.be.equal(ethers.parseEther("0"))
      expect(await fweth.totalAssets()).to.be.equal(ethers.parseEther("50.5"))
      expect(await fweth._lastL2Block()).to.be.equal("2")


      await fweth.connect(owner).redeem(ethers.parseEther("50"), user1, owner)

      expect(await provider.getBalance(user1) - earlyBalance).to.be.equal(ethers.parseEther("50.499999999999999999"))

    });
  });






})



//   describe("harvest dust tokens", function () {
//     it("Should harvest dust token other than underlying ", async function () {
//       const { fw, weth_dust } = await loadFixture();
//       const fw_address = await fw.getAddress()
//       const weth_dust_address = await weth_dust.getAddress()
//       await weth_dust.transfer(fw_address, ethers.parseEther("100"));
//       expect(await weth_dust.balanceOf(fw_address)).to.be.equal(ethers.parseEther("100"))
//       await fw.harvestErc20(weth_dust_address);
//       expect(await weth_dust.balanceOf(fw_address)).to.be.equal(ethers.parseEther("0"))
//     })

//     it("Should harvest dust token which is the underlying", async function () {
//       const { fw, weth, owner, user1 } = await loadFixture();
//       owner
//       await fw.connect(owner).grantRole(PROCESS_ROLE, user1.address)
//       let fw_address = await fw.getAddress()
//       await weth.connect(user1).approve(fw_address, ethers.parseEther("50"))
//       await fw.connect(user1).deposit(ethers.parseEther("50"), user1)
//       expect(await fw._underlyingBalance()).to.be.equal(ethers.parseEther("50"))

//       const weth_address = await weth.getAddress()
//       await weth.transfer(fw_address, ethers.parseEther("100"));
//       expect(await weth.balanceOf(fw_address)).to.be.equal(ethers.parseEther("150"))
//       await fw.harvestErc20(weth_address);
//       expect(await weth.balanceOf(fw_address)).to.be.equal(ethers.parseEther("50"))
//     })

//     it("Should harvest dust eth", async function () {
//       const { fw, owner } = await loadFixture();
//       const fw_address = await fw.getAddress();

//       await owner.sendTransaction({
//         to: fw_address,
//         value: ethers.parseEther("100"),
//       });

//       const initialBalance = await ethers.provider.getBalance(fw_address);
//       expect(initialBalance).to.be.equal(ethers.parseEther("100"));

//       await fw.harvestEth();

//       const finalBalance = await ethers.provider.getBalance(fw_address);
//       expect(finalBalance).to.be.equal(ethers.parseEther("0"));
//     });

//   });

// });

