pragma solidity ^0.8;

interface ITreasuryHandler {

    struct TreasuryHandlerInfo {
        address token;           //ERC20 代币合约地址
        address liquidityWallet; //流动性钱包地址
        address uniswapV2RouterAddr;
        address uniswapV2FactoryAddr;
        address uniswapV2PairAddr;
        address taxHandlerAddr;
    }
        // 事件
    event LiquidityAdded(address source,address indexed sender,address to,uint256 tokenAmount, uint256 ethAmount, uint256 liquidity);
    event LiquidityRemoved(uint256 liquidity, uint256 tokenAmount, uint256 ethAmount);
    
    //接口分离和依赖注入
    function setERC20Contract(address erc20Addr) external;

    function getTreasuryHandlerInfo() external returns (TreasuryHandlerInfo memory handlerInfo);

    //添加流动性
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) external;

    //自动添加流动性，只传入token Amount
    function autoAddLiquidity(uint256 tokenAmount) external;
    //移除流动性，并接收LPT，并销毁LPT
    function removeLiquidity(uint256 liquidity) external;
    // 接收ETH（用于流动性添加）
    receive() external payable;
    
}