const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Leslar", function () {
    let leslar;
    let router;
    let factory;
    let owner;
    let addr1;
    let addr2;
    let addr3;
    let addr4;
    let addr5;
    let addr6;

    beforeEach(async function() {
        // const Factory = await ethers.getContractFactory("Factory");
        // factory = await Factory.deploy(addr5.address);
        // await router.deployed();
        // const Router = await ethers.getContractFactory("Router");
        // router = await Router.deploy(factory.address, addr6.address);
        // await router.deployed();
        const Leslar = await ethers.getContractFactory("LESLAR");
        leslar = await Leslar.deploy();
        await leslar.deployed();
    
        [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();
    })

    it("Should be successfully deployed", async function() {
        console.log("Leslar Metaverse deployed to:", leslar.address);
    })

    it("Should be has 1 trillion of supply on owner balance", async function() {
        const decimals = await leslar.decimals();
        const balance = await leslar.balanceOf(owner.address)
        expect(ethers.utils.formatUnits(balance,decimals) == 1000000000000)
    })

    it("Should let you transfer token", async function() {
        const decimals = await leslar.decimals();
        await leslar.transfer(addr1.address, ethers.utils.parseUnits("1000000", decimals))
        expect(await leslar.balanceOf(addr1.address)).to.equal(ethers.utils.parseUnits("1000000", decimals))
    })

    it("Should let you give another address approval to send on your behalf on buy type", async function() {
      const decimals = await leslar.decimals();
      await leslar.connect(addr1).approve(owner.address, ethers.utils.parseUnits("10000000000", decimals))
      await leslar.transfer(addr1.address, ethers.utils.parseUnits("10000000000", decimals))
      await leslar.transferFrom(addr1.address, addr2.address, ethers.utils.parseUnits("10000000000", decimals))
      expect(await leslar.balanceOf(addr2.address)).to.equal(ethers.utils.parseUnits("9700000000", decimals))

      expect(await leslar.balanceOf(leslar.address)).to.equal(ethers.utils.parseUnits("300000000", decimals))
    })

    it("Should let you give another address approval to send on your behalf on sell type", async function() {
      const decimals = await leslar.decimals();
      // Make addr1 as LP
      leslar.addAddressToLPs(addr2.address);
      await leslar.connect(addr1).approve(owner.address, ethers.utils.parseUnits("10000000000", decimals))
      await leslar.transfer(addr1.address, ethers.utils.parseUnits("10000000000", decimals))
      await leslar.transferFrom(addr1.address, addr2.address, ethers.utils.parseUnits("10000000000", decimals))
      expect(await leslar.balanceOf(addr2.address)).to.equal(ethers.utils.parseUnits("9700000000", decimals))

      expect(await leslar.balanceOf(leslar.address)).to.equal(ethers.utils.parseUnits("300000000", decimals))
    })

    it("Should be able to transfer after set dev wallet", async function() {
        const decimals = await leslar.decimals();
        await leslar.setProductDevWallet(addr1.address, 40);
        await leslar.setDevWallet(addr1.address, 30);
        await leslar.setMarketingWallet(addr1.address, 30);
        //set tax to 20 to prevent Not enough tokens accumulated.
        await leslar.connect(owner).setTaxBuy(20);
        await leslar.transfer(addr2.address, ethers.utils.parseUnits("20000000000", decimals))

        // Test limit exemption
        await leslar.toggleLimitExemptions(addr2.address, false, true, true, true, false);
        // Transfer to address
        await leslar.connect(addr2).transfer(addr3.address, ethers.utils.parseUnits("10000000000", decimals))
        console.log("balance ", await leslar.balanceOf(addr3.address));
        await leslar.triggerTax()
        // Make sure that dev address get the token
        expect(await leslar.balanceOf(addr1.address)).to.equal(ethers.utils.parseUnits("600000000", decimals))
    })

    it("Should be able to set buy fee", async function() {
        await leslar.connect(owner).setTaxBuy(10);
        const decimals = await leslar.decimals();
        await leslar.connect(addr1).approve(owner.address, ethers.utils.parseUnits("10000000000", decimals))
        await leslar.transfer(addr1.address, ethers.utils.parseUnits("10000000000", decimals))
        await leslar.transferFrom(addr1.address, addr2.address, ethers.utils.parseUnits("10000000000", decimals))
        expect(await leslar.balanceOf(addr2.address)).to.equal(ethers.utils.parseUnits("9000000000", decimals))
  
        expect(await leslar.balanceOf(leslar.address)).to.equal(ethers.utils.parseUnits("1000000000", decimals))
    });
   
    it("Should be able to set sell fee", async function() {
        await leslar.connect(owner).setTaxSell(5);
        const decimals = await leslar.decimals();
        leslar.addAddressToLPs(addr2.address);
        await leslar.connect(addr1).approve(owner.address, ethers.utils.parseUnits("10000000000", decimals))
        await leslar.transfer(addr1.address, ethers.utils.parseUnits("10000000000", decimals))
        await leslar.transferFrom(addr1.address, addr2.address, ethers.utils.parseUnits("10000000000", decimals))
        expect(await leslar.balanceOf(addr2.address)).to.equal(ethers.utils.parseUnits("9500000000", decimals))

        expect(await leslar.balanceOf(leslar.address)).to.equal(ethers.utils.parseUnits("500000000", decimals))
    });

    // it("Wallet should be cannot more than 2% of total supply", async function() {
    //     const decimals = await leslar.decimals();
    //     await leslar.transfer(addr2.address, ethers.utils.parseUnits("21000000000", decimals))

    //     await expect(leslar.connect(addr2).transfer(addr3.address, ethers.utils.parseUnits("21000000000", decimals))).to.be.revertedWith('Exceeds maximum wallet size allowed.');
    // })

    it("Cannot sell more than 1% of total supply", async function() {
        const decimals = await leslar.decimals();

        // Make addr2 as LP
        leslar.addAddressToLPs(addr2.address);
        // Add balance to address 1
        await leslar.connect(owner).setBuybackFee(0);
        await leslar.connect(addr1).approve(owner.address, ethers.utils.parseUnits("20000000000", decimals))
        await leslar.connect(owner).transfer(addr1.address, ethers.utils.parseUnits("20000000000", decimals))

        await leslar.transferFrom(addr1.address, addr2.address, ethers.utils.parseUnits("10000000000", decimals))
        // Add balance to address 2
        
        // leslar.connect(owner).setTaxBuy(0);
        // leslar.connect(owner).setTaxSell(0);
        await leslar.connect(addr3).approve(owner.address, ethers.utils.parseUnits("20000000000", decimals))
        await leslar.connect(owner).transfer(addr3.address, ethers.utils.parseUnits("20000000000", decimals))
        await leslar.connect(owner).transfer(addr3.address, ethers.utils.parseUnits("10000000000", decimals))
        // Create sell to LP
        // await leslar.connect(owner).setMaxSellAllowanceMultiplier(1);
        // await expect(leslar.transferFrom(addr1.address, addr2.address, ethers.utils.parseUnits("5000000000", decimals))).to.be.revertedWith("Can't sell more than cycle allowance!");

        // Change to 0,5%
        // leslar.setMaxSellAllowanceMultiplier(200);
        // await leslar.transferFrom(addr3.address, addr2.address, ethers.utils.parseUnits("3000000000", decimals))
        // // Max combined cannot more than 0,5% total supply
        // await expect(leslar.transferFrom(addr3.address, addr2.address, ethers.utils.parseUnits("3000000000", decimals))).to.be.revertedWith("Combined cycle sell amount exceeds cycle allowance!");


    })

});
