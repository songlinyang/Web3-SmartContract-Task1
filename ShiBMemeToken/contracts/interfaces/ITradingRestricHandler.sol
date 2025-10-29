pragma solidity ^0.8;

interface ITradingRestricHandler {
    struct TradeLimit {
        uint256 maxTxAmount;
        uint256 maxWalletAmount;
        uint256 dailySellLimit;
        uint256 dailyTxCountLimit;
    }

    struct TradeData {
       uint256 lastSellTime;
       uint256 dailySellAmount;
       uint256 dailyTxCount;
       uint256 lastTxTime;
    }

        // 验证交易限制
    function validateTradeLimits(address from,address to,uint256 amount,address uniswapV2Pair,uint256 balanceOf) external;
    // 如单笔交易最大额度
    function setTradeLimits(
        uint256 _maxTxAmount,  //限制最大交易金额
        uint256 _maxWalletAmount,//用来限制单个钱包（地址）持有的代币总量，也就是钱包余额上限。通常在转账/接收时做校验，防止某个地址持有超过该上限（防止"大户"或操纵）
        uint256 _dailySellLimit, //_dailySellLimit 是限制单个地址在 24 小时内可卖出的代币次数总量，相对于单个账户，用来防止大户在一天内大量抛售导致价格剧烈波动。
        uint256 _dailyTxCountLimit
    ) external;

    // 获取交易限额信息
    function  getTradeLimitsInfo() external view returns(TradeLimit memory);
    // 免交易限额，合约自身、流动性对（uniswapPair）、白名单地址、owner 或授权合约等通常被排除在限制之外。
    function setTradingFree(address _addr, bool _isFree) external;
    // 判断地址是否再免交易限额地址队列中，返回true，或 false
    function isTradingFree(address _addr) external view returns (bool);
}
