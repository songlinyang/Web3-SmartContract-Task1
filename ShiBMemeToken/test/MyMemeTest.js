const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ShiBeMemeToken", async () => {

    let uniswapV2PairAddress, uniswapV2FactoryAddress, uniswapV2Router02Address;
    let owner, user1, user2, taxWallet, liquidityWallet;
    let taxHandlerAddress, treasuryHandlerAddress, tradingRestricHandlerAddress;
    let shibMemeToken, taxHandler, tradingRestricHandler, treasuryHandler;
    let mockWETH, mockUniswapPair, mockUniswapFactory, mockUniswapRouter;
    
    // 税率配置（基点：100 = 1%）
    const BUY_TAX = 200;    // 2%
    const SELL_TAX = 300;   // 3%
    const TRANSFER_TAX = 100; // 1%
    const LIQUIDITY_FEE = 1000; // 10% of tax amount
    
    // 交易限制
    const MAX_TX_AMOUNT = ethers.parseEther("10000");
    const MAX_WALLET_AMOUNT = ethers.parseEther("50000");
    const DAILY_SELL_LIMIT = ethers.parseEther("5000");
    const DAILY_TX_COUNT_LIMIT = 100;
    
    const INITIAL_SUPPLY = ethers.parseEther("1000000"); // 100万代币

    const setupTestEnvironment = async () => {
        [owner, user1, user2, taxWallet, liquidityWallet] = await ethers.getSigners();
        
        // 初始化uniswap
        await deployMockUniswapContracts();
        
        // 部署处理器
        await deployHandlerContracts();

        // 部署meme合约
        const ShibMemeTokenFactory = await ethers.getContractFactory("MyMemeToken");
        shibMemeToken = await ShibMemeTokenFactory.deploy(
            taxHandlerAddress,
            tradingRestricHandlerAddress,
            treasuryHandlerAddress
        );
        await shibMemeToken.waitForDeployment();
    };

    // uniswapMock测试辅助函数
    const deployMockUniswapContracts = async () => {
        // Deploy Mock WETH
        const MockWETHFactory = await ethers.getContractFactory("MockWETH");
        mockWETH = await MockWETHFactory.deploy();
        await mockWETH.waitForDeployment();
        
        // Deploy Mock Uniswap Pair
        const MockUniswapV2PairFactory = await ethers.getContractFactory("MockUniswapV2Pair");
        mockUniswapPair = await MockUniswapV2PairFactory.deploy();
        await mockUniswapPair.waitForDeployment();
        uniswapV2PairAddress = await mockUniswapPair.getAddress();
        
        // Deploy Mock Uniswap Factory
        const MockUniswapV2FactoryFactory = await ethers.getContractFactory("MockUniswapV2Factory");
        mockUniswapFactory = await MockUniswapV2FactoryFactory.deploy(await mockUniswapPair.getAddress());
        await mockUniswapFactory.waitForDeployment();
        uniswapV2FactoryAddress = await mockUniswapFactory.getAddress();

        // Deploy Mock Uniswap Router
        const MockUniswapV2RouterFactory = await ethers.getContractFactory("MockUniswapV2Router");
        mockUniswapRouter = await MockUniswapV2RouterFactory.deploy(
            await mockUniswapFactory.getAddress(),
            await mockWETH.getAddress()
        );
        await mockUniswapRouter.waitForDeployment();
        uniswapV2Router02Address = await mockUniswapRouter.getAddress();
    };

    // 部署处理器
    const deployHandlerContracts = async () => {
        const TaxHandlerFactory = await ethers.getContractFactory("TaxHandler");
        const TradingRestricHandlerFactory = await ethers.getContractFactory("TradingRestricHandler");
        const TreasuryHandlerFactory = await ethers.getContractFactory("TreasuryHandler");

        // 部署税收处理器
        taxHandler = await TaxHandlerFactory.deploy(
            BUY_TAX,
            SELL_TAX,
            TRANSFER_TAX,
            taxWallet.address,
            uniswapV2PairAddress
        ); 
        await taxHandler.waitForDeployment();
        taxHandlerAddress = await taxHandler.getAddress();
        
        // 部署交易限制处理器
        tradingRestricHandler = await TradingRestricHandlerFactory.deploy(
            MAX_TX_AMOUNT,
            MAX_WALLET_AMOUNT,
            DAILY_SELL_LIMIT,
            DAILY_TX_COUNT_LIMIT
        );
        await tradingRestricHandler.waitForDeployment();
        tradingRestricHandlerAddress = await tradingRestricHandler.getAddress();

        // 部署金库处理器
        treasuryHandler = await TreasuryHandlerFactory.deploy(
            liquidityWallet.address,
            uniswapV2Router02Address,
            uniswapV2FactoryAddress,
            uniswapV2PairAddress,
            taxHandlerAddress
        );
        await treasuryHandler.waitForDeployment();
        treasuryHandlerAddress = await treasuryHandler.getAddress();
    };

    // 运行每个测试案例，都进行测试环境初始化
    beforeEach(async () => {
        await setupTestEnvironment();
    });

    describe("🚀 合约部署与初始化", async () => {
        it("✅ 应该正确初始化代币基本信息", async () => {
            // 验证代币名称和符号
            expect(await shibMemeToken.name()).to.equal("MyMeme");
            expect(await shibMemeToken.symbol()).to.equal("MME");
            
            // 验证初始供应量
            expect(await shibMemeToken.totalSupply()).to.equal(INITIAL_SUPPLY);
            
            // 验证代币所有者拥有初始供应量
            expect(await shibMemeToken.balanceOf(owner.address)).to.equal(INITIAL_SUPPLY);
        });

        it("✅ 应该正确部署所有处理器", async () => {
            // 验证处理器地址不为零地址
            expect(await shibMemeToken.taxHandler()).to.equal(taxHandlerAddress);
            expect(await shibMemeToken.tradingRestricHandler()).to.equal(tradingRestricHandlerAddress);
            expect(await shibMemeToken.treasuryHandler()).to.equal(treasuryHandlerAddress);
            
            // 验证处理器合约已正确部署
            expect(taxHandlerAddress).to.not.equal(ethers.ZeroAddress);
            expect(tradingRestricHandlerAddress).to.not.equal(ethers.ZeroAddress);
            expect(treasuryHandlerAddress).to.not.equal(ethers.ZeroAddress);
        });

        it("✅ 应该正确配置税收处理器", async () => {
            const taxConfig = await taxHandler.getTaxConfig();
            
            expect(taxConfig.buyTaxFee).to.equal(BUY_TAX);
            expect(taxConfig.sellTaxFee).to.equal(SELL_TAX);
            expect(taxConfig.transferTaxFee).to.equal(TRANSFER_TAX);
            expect(taxConfig.taxWallet).to.equal(taxWallet.address);
            expect(taxConfig.uniswapPair).to.equal(uniswapV2PairAddress);
        });
    });

    describe("💰 税收功能测试", async () => {
        it("✅ 应该正确计算买入税", async () => {
            const amount = ethers.parseEther("100");
            const expectedTax = amount * BigInt(BUY_TAX) / 10000n;
            
            // 模拟从Uniswap交易对买入（from是交易对地址）
            const taxAmount = await taxHandler.getTax(uniswapV2PairAddress, user1.address, amount);
            expect(taxAmount).to.equal(expectedTax);
        });

        it("✅ 应该正确计算卖出税", async () => {
            const amount = ethers.parseEther("100");
            const expectedTax = amount * BigInt(SELL_TAX) / 10000n;
            
            // 模拟向Uniswap交易对卖出（to是交易对地址）
            const taxAmount = await taxHandler.getTax(user1.address, uniswapV2PairAddress, amount);
            expect(taxAmount).to.equal(expectedTax);
        });

        it("✅ 应该正确计算转账税", async () => {
            const amount = ethers.parseEther("100");
            const expectedTax = amount * BigInt(TRANSFER_TAX) / 10000n;
            
            // 模拟普通用户间转账
            const taxAmount = await taxHandler.getTax(user1.address, user2.address, amount);
            expect(taxAmount).to.equal(expectedTax);
        });

        it("✅ 免税地址应该不收取税费", async () => {
            const amount = ethers.parseEther("100");
            
            // 设置免税地址
            await taxHandler.setTaxFree(user1.address, true);
            
            // 从免税地址转账应该不收税
            const taxAmount = await taxHandler.getTax(user1.address, user2.address, amount);
            expect(taxAmount).to.equal(0);
        });

        it("✅ 应该正确计算销毁金额", async () => {
            const taxAmount = ethers.parseEther("10");
            const burnAmount = await taxHandler.burnTax(taxAmount);
            
            // 销毁比例是10%，所以应该是taxAmount的10%
            const expectedBurnAmount = taxAmount * 1000n / 10000n;
            expect(burnAmount).to.equal(expectedBurnAmount);
        });
    });

    describe("🛡️ 交易限制功能测试", async () => {
        it("✅ 应该验证交易金额不超过最大限制", async () => {
            const validAmount = ethers.parseEther("5000"); // 小于最大限制
            const invalidAmount = ethers.parseEther("15000"); // 超过最大限制
            
            // 验证有效金额应该通过
            await expect(
                tradingRestricHandler.validateTradeLimits(
                    user1.address,
                    user2.address,
                    validAmount,
                    uniswapV2PairAddress,
                    ethers.parseEther("1000")
                )
            ).to.not.be.reverted;
            
            // 验证无效金额应该失败
            await expect(
                tradingRestricHandler.validateTradeLimits(
                    user1.address,
                    user2.address,
                    invalidAmount,
                    uniswapV2PairAddress,
                    ethers.parseEther("1000")
                )
            ).to.be.reverted;
        });

        it("✅ 应该验证钱包余额不超过最大限制", async () => {
            const amount = ethers.parseEther("1000");
            const currentBalance = ethers.parseEther("49000"); // 接近最大限制
            
            // 如果接收后余额超过最大限制，应该失败
            await expect(
                tradingRestricHandler.validateTradeLimits(
                    user1.address,
                    user2.address,
                    amount,
                    uniswapV2PairAddress,
                    currentBalance
                )
            ).to.be.reverted;
        });
    });

    describe("🔄 代币转账功能测试", async () => {
        beforeEach(async () => {
            // 给用户1分配一些代币用于测试
            await shibMemeToken.transfer(user1.address, ethers.parseEther("1000"));
        });

        it("✅ 应该成功执行普通转账", async () => {
            const transferAmount = ethers.parseEther("100");
            
            // 记录初始余额
            const initialBalanceUser1 = await shibMemeToken.balanceOf(user1.address);
            const initialBalanceUser2 = await shibMemeToken.balanceOf(user2.address);
            
            // 执行转账
            await shibMemeToken.connect(user1).transfer(user2.address, transferAmount);
            
            // 验证余额变化
            const finalBalanceUser1 = await shibMemeToken.balanceOf(user1.address);
            const finalBalanceUser2 = await shibMemeToken.balanceOf(user2.address);
            
            // 用户1应该减少转账金额（包含税费）
            expect(initialBalanceUser1 - finalBalanceUser1).to.be.gt(transferAmount);
            // 用户2应该增加转账金额（扣除税费）
            expect(finalBalanceUser2 - initialBalanceUser2).to.be.lt(transferAmount);
        });

        it("✅ 应该拒绝零地址转账", async () => {
            const transferAmount = ethers.parseEther("100");
            
            await expect(
                shibMemeToken.connect(user1).transfer(ethers.ZeroAddress, transferAmount)
            ).to.be.revertedWith("MyMemeToken:_transfer:TO_ZERO");
        });

        it("✅ 应该拒绝余额不足的转账", async () => {
            const excessiveAmount = ethers.parseEther("2000"); // 超过用户1的余额
            
            await expect(
                shibMemeToken.connect(user1).transfer(user2.address, excessiveAmount)
            ).to.be.revertedWith("MyMemeToken:_transfer:INSUFFICIENT_BALANCE");
        });
    });

    describe("🔥 代币销毁功能测试", async () => {
        it("✅ 应该正确销毁代币", async () => {
            const initialSupply = await shibMemeToken.totalSupply();
            const burnAmount = ethers.parseEther("100");
            
            // 执行转账（会产生销毁）
            await shibMemeToken.transfer(user1.address, burnAmount);
            
            const finalSupply = await shibMemeToken.totalSupply();
            
            // 总供应量应该减少（因为有销毁）
            expect(finalSupply).to.be.lt(initialSupply);
        });
    });

    describe("🏦 流动性管理功能测试", async () => {
        it("✅ 应该允许所有者添加流动性", async () => {
            const tokenAmount = ethers.parseEther("1000");
            const ethAmount = ethers.parseEther("1");
            
            // 给合约授权足够的代币
            await shibMemeToken.approve(treasuryHandlerAddress, tokenAmount);
            
            // 应该能够成功添加流动性
            await expect(
                shibMemeToken.addLiquidity(tokenAmount, ethAmount)
            ).to.not.be.reverted;
        });

        it("✅ 应该拒绝非所有者添加流动性", async () => {
            const tokenAmount = ethers.parseEther("1000");
            const ethAmount = ethers.parseEther("1");
            
            await expect(
                shibMemeToken.connect(user1).addLiquidity(tokenAmount, ethAmount)
            ).to.be.revertedWithCustomError(shibMemeToken, "OwnableUnauthorizedAccount");
        });
    });

    describe("⚙️ 配置更新功能测试", async () => {
        it("✅ 应该允许所有者更新税收配置", async () => {
            const newBuyTax = 150; // 1.5%
            const newSellTax = 250; // 2.5%
            const newTransferTax = 50; // 0.5%
            
            await taxHandler.setTaxConfig(
                newBuyTax,
                newSellTax,
                newTransferTax,
                taxWallet.address,
                uniswapV2PairAddress
            );
            
            const taxConfig = await taxHandler.getTaxConfig();
            
            expect(taxConfig.buyTaxFee).to.equal(newBuyTax);
            expect(taxConfig.sellTaxFee).to.equal(newSellTax);
            expect(taxConfig.transferTaxFee).to.equal(newTransferTax);
        });

        it("✅ 应该拒绝非所有者更新税收配置", async () => {
            await expect(
                taxHandler.connect(user1).setTaxConfig(100, 100, 100, user1.address, uniswapV2PairAddress)
            ).to.be.revertedWithCustomError(taxHandler, "OwnableUnauthorizedAccount");
        });
    });
});
