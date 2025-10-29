import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

describe("ShiBeMemeToken", function () {
  let shibMemeToken: any;
  let owner: any;
  let user1: any;

  beforeEach(async function () {
    [owner, user1] = await ethers.getSigners();

    const ShibMemeTokenFactory = await ethers.getContractFactory("MyMemeToken");
    shibMemeToken = await ShibMemeTokenFactory.deploy(
      ethers.ZeroAddress, // taxHandlerAddress
      ethers.ZeroAddress, // tradingRestricHandlerAddress
      ethers.ZeroAddress  // treasuryHandlerAddress
    );
    await shibMemeToken.waitForDeployment();
  });

  it("✅ 应该正确初始化代币基本信息", async function () {
    expect(await shibMemeToken.name()).to.equal("MyMeme");
    expect(await shibMemeToken.symbol()).to.equal("MME");
    expect(await shibMemeToken.totalSupply()).to.equal(ethers.parseEther("1000000"));
  });

  it("✅ 应该正确分配初始代币给所有者", async function () {
    const ownerBalance = await shibMemeToken.balanceOf(owner.address);
    expect(ownerBalance).to.equal(ethers.parseEther("1000000"));
  });

  it("✅ 应该正确设置处理器地址", async function () {
    expect(await shibMemeToken.taxHandler()).to.equal(ethers.ZeroAddress);
    expect(await shibMemeToken.tradingRestricHandler()).to.equal(ethers.ZeroAddress);
    expect(await shibMemeToken.treasuryHandler()).to.equal(ethers.ZeroAddress);
  });
});
