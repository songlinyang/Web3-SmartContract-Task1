pragma solidity ^0.8;

import "./interfaces/ITradingRestricHandler.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TradingRestricHandler is ITradingRestricHandler, Ownable {
    mapping(address => bool) private _isTradingFree;
    TradeLimit private _tradeLimit; //交易限制
    mapping (address => TradeData) public TradeDataMap;  //记录地址交易数据状态

    constructor(
        uint256 _maxTxAmount,  //限制最大交易金额
        uint256 _maxWalletAmount,//用来限制单个钱包（地址）持有的代币总量，也就是钱包余额上限。通常在转账/接收时做校验，防止某个地址持有超过该上限（防止"大户"或操纵）
        uint256 _dailySellLimit, //_dailySellLimit 是限制单个地址在 24 小时内可卖出的代币次数总量，相对于单个账户，用来防止大户在一天内大量抛售导致价格剧烈波动。
        uint256 _dailyTxCountLimit
    ) Ownable(msg.sender) {
        _tradeLimit = TradeLimit({
            maxTxAmount: _maxTxAmount,
            maxWalletAmount: _maxWalletAmount,
            dailySellLimit :_dailySellLimit,
            dailyTxCountLimit:_dailyTxCountLimit
        });
        //对初始化合约账户，和当前合约地址，不进行限制
        _isTradingFree[owner()]=true;
        _isTradingFree[address(this)]=true;
    }

    //验证交易限制
    function validateTradeLimits(address from,address to,uint256 amount,address uniswapV2Pair,uint256 balanceOf) external override {
        TradeData memory data  = TradeDataMap[from];
        //检查单笔交易最大额度
        if (from != owner() && to != owner() && !_isTradingFree[from] && !_isTradingFree[to]){
            require(amount <= _tradeLimit.maxTxAmount,"transfer amount exceeds max transaction limit");
        }

        //检查钱包最大持有量（仅接收方）
        if(to!=address(0) && to!=uniswapV2Pair && !_isTradingFree[to]){
            require(
                balanceOf + amount <= _tradeLimit.maxWalletAmount,"Transfer amount exceeds max wallet limit"
            );
        }

        //检查每日卖出限制
        if(to==uniswapV2Pair && !_isTradingFree[from] && !_isTradingFree[to]){
            uint256 currentDay = block.timestamp / 1 days;
            uint256 lastSellDay = TradeDataMap[from].lastSellTime / 1 days;

            if (currentDay > lastSellDay){
                // 新的一天，重置卖出金额
                data.dailySellAmount = 0;
            }
            require(
               data.dailySellAmount + amount <= _tradeLimit.dailySellLimit,
                "Daily sell limit exceeded"
            );
            data.dailySellAmount +=amount;
            data.lastSellTime = block.timestamp;
        }
        //交易次数限制
        uint256 currentTxDay = block.timestamp / 1 days;
        uint256 lastTxDay = data.lastTxTime / 1 days;
        if (currentTxDay>lastTxDay){
            //新的一天，重制交易次数
            data.dailyTxCount = 0;
        }

        require(data.dailyTxCount <= _tradeLimit.dailyTxCountLimit);

        data.dailyTxCount ++;
        data.lastTxTime = block.timestamp;

    }


    function setTradingFree(address _addr, bool _isFree) external override onlyOwner {
        _isTradingFree[_addr] = _isFree;
    }

    function isTradingFree(address _addr) external view override returns (bool) {
        return _isTradingFree[_addr];
    }

    // 如单笔交易最大额度
    function setTradeLimits(
        uint256 _maxTxAmount,  //限制最大交易金额
        uint256 _maxWalletAmount,//用来限制单个钱包（地址）持有的代币总量，也就是钱包余额上限。通常在转账/接收时做校验，防止某个地址持有超过该上限（防止"大户"或操纵）
        uint256 _dailySellLimit, //_dailySellLimit 是限制单个地址在 24 小时内可卖出的代币次数总量，相对于单个账户，用来防止大户在一天内大量抛售导致价格剧烈波动。
        uint256 _dailyTxCountLimit
    ) external override {
        _tradeLimit = TradeLimit({
            maxTxAmount: _maxTxAmount,
            maxWalletAmount: _maxWalletAmount,
            dailySellLimit: _dailySellLimit,
            dailyTxCountLimit: _dailyTxCountLimit
        });
    }
    function getTradeLimitsInfo() external view override returns (TradeLimit memory) {
        return _tradeLimit;
    }
}
