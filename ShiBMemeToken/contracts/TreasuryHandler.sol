pragma solidity ^0.8;

import "./interfaces/ITreasuryHandler.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ITaxHandler.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    //包装后的ETH，用来和代币配对，是在以太坊上交易的桥梁，用在UniswapV2上
    function WETH() external pure returns (address);

    //添加流动性ETH
    //使用 ETH 为 ERC-20⇄WETH 池增加流动性
    /**
    *amountToken 发送到池中的代币数量
    *amountETH 转换为WETH并发送到池中的ETH数量
    *liquidity 铸造流动性币数量 
     */
    function addLiquidityETH(
        address token,           //MEME代币池地址
        uint amountTokenDesired, //转入的代币，类示msg.sender，则作为流动性添加的代币数量
        uint amountTokenMin,     //滑点保护，限制交易撤销前WETH/代币价格上涨的幅度。必须小于等于amountTokenDesired
        uint amountETHMin,       //滑点保护，限制交易撤销前代币/WETH价格上涨的幅度。必须小于等于msg.value
        address to,              //流动性代币的接收者
        uint deadline            //交易将恢复的 Unix 时间戳。

    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    /**
    * return amountToken 收到的代币数量
    * return amountETH  收到的 ETH 数量
     */
    function removeLiquidityETH(
        address token,           //MEME代币池地址
        uint liquidity,          //要移除的流动性代币的数量。
        uint amountTokenMin,     //为使交易不被撤销，必须收到的最小代币数量
        uint amountETHMin,       //为避免交易撤销，必须收到的 ETH 的最低金额
        address to,              //基础资产的接收者
        uint deadline            //交易将恢复的 Unix 时间戳
    ) external returns (uint amountToken, uint amountETH);

    //与swapExactTokensForETH相同，但对于在转移时收取费用的代币有效
    //注意⚠️：如果收款地址是智能合约，则它必须具有接收 ETH 的能力
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,           //要发送的输入令牌的数量。需要一半，保持流动性池的恒定乘积做市商 x.y=k
        uint amountOutMin,       //为使交易不被撤销，必须接收的最小输出代币数量。
        address[] calldata path, //代币地址数组。path.length必须> = 2。每个连续地址对的池必须存在并且具有流动性。
        address to,              //ETH 的接收者。
        uint deadline            //交易将恢复的 Unix 时间戳。
    ) external;

}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Pair {
    function transferFrom(address from, address to, uint value) external returns (bool);
    function approve(address spender, uint value) external returns (bool);
    function balanceOf(address owner) external view returns (uint);
}


contract TreasuryHandler is ITreasuryHandler, Ownable {

    IERC20 public token; //放入代码区，减少store存储，优化gas

    ITaxHandler public immutable taxHandler;

    IUniswapV2Router02 public immutable uniswapV2Router02;

    IUniswapV2Factory public immutable uniswapV2Factory;
    
    IUniswapV2Pair public immutable uniswapV2Pair;

    address public liquidityWallet;

    address public uniswapV2Router02Addr;

    address public MemeTokenAddress;   

    address public uniswapV2PairAddr;
    


    TreasuryHandlerInfo private _treasuryHandlerInfo;
    constructor(
        address _liquidityWallet, //流动性钱包地址
        address _uniswapV2RouterAddr,
        address _uniswapV2FactoryAddr,
        address _uniswapV2PairAddr,
        address _taxHandlerAddr
    ) Ownable(msg.sender) {
        taxHandler = ITaxHandler(_taxHandlerAddr);
        liquidityWallet = _liquidityWallet;
        uniswapV2Router02Addr = _uniswapV2RouterAddr;
        uniswapV2PairAddr = _uniswapV2PairAddr;
        MemeTokenAddress = address(0); // Will be set later via setERC20Contract
        uniswapV2Router02 = IUniswapV2Router02(_uniswapV2RouterAddr);
        uniswapV2Factory = IUniswapV2Factory(_uniswapV2FactoryAddr);
        uniswapV2Pair = IUniswapV2Pair(_uniswapV2PairAddr);
        
        _treasuryHandlerInfo = TreasuryHandlerInfo({
            token:MemeTokenAddress,
            liquidityWallet:_liquidityWallet, //流动性钱包地址
            uniswapV2RouterAddr:_uniswapV2RouterAddr,
            uniswapV2FactoryAddr:_uniswapV2FactoryAddr,
            uniswapV2PairAddr:_uniswapV2PairAddr,
            taxHandlerAddr:_taxHandlerAddr
        });
    }

    function setERC20Contract(address erc20Addr) external  onlyOwner override {
        require(erc20Addr != address(0),"Invalid erc20Contract address");
        require(address(token) == address(0),"erc20Contract already set");
        token = IERC20(erc20Addr);
        MemeTokenAddress = erc20Addr;
        _treasuryHandlerInfo.token = erc20Addr;
    }

    function getTreasuryHandlerInfo() external override returns (TreasuryHandlerInfo memory handlerInfo){
        return _treasuryHandlerInfo;
    }
    //添加流动性
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) external override{
        require(tokenAmount > 0, "Token amount must be positive");
        require(ethAmount > 0, "ETH amount must be positive");

        //初始化流动性不收税
        taxHandler.setTaxFree(address(this), true);
        taxHandler.setTaxFree(msg.sender, true);
        // 授权Uniswap路由器使用代币
        require(
            token.transferFrom(msg.sender, address(this), tokenAmount),
            "Token transfer failed"
        );

        token.approve(uniswapV2Router02Addr, tokenAmount);

        //添加流动性
        uniswapV2Router02.addLiquidityETH{value:ethAmount}(MemeTokenAddress, tokenAmount, 0, 0, liquidityWallet, block.timestamp);
        emit LiquidityAdded(msg.sender,address(this),liquidityWallet,tokenAmount, ethAmount, 0);
    }

    //自动添加流动性，只传入token Amount
    function autoAddLiquidity(uint256 tokenAmount) external override{
        require(msg.sender == address(token), "Only token contract can auto add liquidity");
        require(tokenAmount > 0, "Token amount must be positive");
        //初始化流动性不收税
        taxHandler.setTaxFree(address(this), true);
        taxHandler.setTaxFree(msg.sender, true);

        
        uint256 halfAmount = tokenAmount / 2;
        uint256 otherHalf = tokenAmount - halfAmount;

        //交换一半代币为WETH
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = uniswapV2Router02.WETH();

        uint256 initialBalance = address(this).balance;

        //授权uniswapV2Router可以进行代币提取，进行添加到流动性
        token.approve(uniswapV2Router02Addr, halfAmount);
        // 创建Uniswap交易对
        uniswapV2Router02.swapExactTokensForETHSupportingFeeOnTransferTokens(halfAmount, 0, path, address(this), block.timestamp);

        uint256 newBalance = address(this).balance - initialBalance;

        // 添加流动性
        if (newBalance > 0) {
            token.approve(uniswapV2Router02Addr, otherHalf);
            uniswapV2Router02.addLiquidityETH{value:newBalance}(MemeTokenAddress, otherHalf, 0, 0, liquidityWallet, block.timestamp);
        }
        emit LiquidityAdded(msg.sender,address(this),liquidityWallet,otherHalf, newBalance, 0);


    }
    //移除流动性，并接收LPT，并销毁LPT
    function removeLiquidity(uint256 liquidity) external override{
        require(liquidity > 0, "Liquidity amount must be positive");
        //初始化流动性不收税
        taxHandler.setTaxFree(address(this), true);
        taxHandler.setTaxFree(msg.sender, true);
        // 获取LP代币
        require(
            uniswapV2Pair.transferFrom(msg.sender, address(this), liquidity),
            "LP token transfer failed"
        );
        //授权Uniswap路由器使用LP代币
        uniswapV2Pair.approve(uniswapV2Router02Addr, liquidity);

        //移除流动性
        (uint256 amountToken, uint256 amountETH) = uniswapV2Router02.removeLiquidityETH(
            MemeTokenAddress, liquidity, 0, 0,  msg.sender, block.timestamp);
        
        emit LiquidityRemoved(liquidity, amountToken, amountETH);
 
    }
    // 接收ETH（用于流动性添加）
    receive() external payable{}

}
