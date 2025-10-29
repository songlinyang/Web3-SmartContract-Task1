pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ITaxHandler.sol";
import "./interfaces/ITradingRestricHandler.sol";
import "./interfaces/ITreasuryHandler.sol";

contract MyMemeToken is ERC20, Ownable {
    // MyMeme contract code here

    // 处理代币税收计算功能接口
    ITaxHandler public immutable taxHandler;
    // 处理交易限制功能接口
    ITradingRestricHandler public immutable tradingRestricHandler;
    // 处理金库管理功能接口 添加流动性/移除流动性
    ITreasuryHandler public immutable treasuryHandler;

    //事件
    // 税收处理器更改事件
    event TaxHandlerChanged(address indexed oldTaxHandler,address indexed newTaxHandler);
    // 交易限制处理器更改事件
    event TradingRestricHandlerChanged(address indexed oldTradingRestricHandler,address indexed newTradingRestricHandler);
    // 金库处理器更改事件
    event TreasuryHandlerChanged(address indexed oldTreasuryHandler,address indexed newTreasuryHandler);
    // 销毁时间
    event TokensBurned(address from, uint256 burnAmount);

    // 构造函数
    constructor(
        address taxHandlerAddress,
        address tradingRestricHandlerAddress,
        address treasuryHandlerAddress
    ) ERC20("MyMeme", "MME") Ownable(msg.sender) {

       
        // 获取操作对象，从实际合约地址获取
        taxHandler = ITaxHandler(taxHandlerAddress); 
        treasuryHandler = ITreasuryHandler(payable(treasuryHandlerAddress));
        tradingRestricHandler = ITradingRestricHandler(tradingRestricHandlerAddress);

        uint8 _decimals = 18;
        uint256 _initialSupply = 1000000 * (10 ** _decimals); //发行100万个代币
        // 初始铸造代币到合约创建者地址
        _mint(msg.sender, _initialSupply);
    }
    // // 获取代币名称
    // function getTokenName() external view  returns(string memory){
    //     return _name;
    // }
    // // 获取代币符号
    // function getTokenSymbol() external view returns(string memory){
    //     return _symbol;
    // }
    // // 获取代币总量
    // function getSupplyAmount() external view returns(uint256) {
    //     return _initialSupply;
    // }
    // // 获取代币位数
    // function getDecimal() external view returns(uint8){
    //     return _decimals;
    // }
     
    /**
     * @dev 重写ERC20转账函数，集成所有功能模块
     * @param from 发送方地址
     * @param to 接收方地址
     * @param amount 转账金额
     * 
     * 实现逻辑：
     * 1. 验证交易限制（最大交易额、钱包限额、每日卖出限额等）
     * 2. 计算税费（买入税、卖出税、转账税）
     * 3. 分配税费到税务钱包
     * 4. 自动添加流动性（如果是卖出交易）
     * 5. 执行实际转账
     */   
     function _update(address from, address to, uint256 amount) internal virtual override{
        require(from != address(0), "MyMemeToken:_transfer:FROM_ZERO: Cannot transfer from the zero address.");
        require(to != address(0), "MyMemeToken:_transfer:TO_ZERO: Cannot transfer to the zero address.");
        require(amount > 0, "MyMemeToken:_transfer:ZERO_AMOUNT: Transfer amount must be greater than zero.");
        require(amount <= balanceOf(from), "MyMemeToken:_transfer:INSUFFICIENT_BALANCE: Transfer amount exceeds balance.");
        
        //验证交易限制，防止被攻击
        tradingRestricHandler.validateTradeLimits(from, to, amount,treasuryHandler.getTreasuryHandlerInfo().uniswapV2PairAddr,balanceOf(to));
        
        //这里调用税率计算,根据交易类型应用不同税率
        uint256 taxedAmount = taxHandler.getTax(from, to, amount);
        uint256 transferAmount = amount - taxedAmount;

        //处理税收和销毁
        if (taxedAmount>0) {            
            uint256 burnAmount = taxHandler.burnTax(taxedAmount);
            //向指定的税收账户进行转账
            uint256 finalTaxAmount = taxedAmount - burnAmount;
            //先把税收转入当前合约账户，再由合约转入指定税收外部账户
            require(finalTaxAmount>0,"finalTaxAmount must be grater than 0"); //去除无效转账
            super._update(from,taxHandler.getTaxConfig().taxWallet,finalTaxAmount);
            //直接销毁
            if(burnAmount > 0){
                super._update(from,address(0),burnAmount);
                emit TokensBurned(from, burnAmount);
            }
        }
        // 执行实际金额的转账
        super._update(from,to,transferAmount);
    }
    
    // function transfer(address to, uint256 value) public override returns (bool) {
    //     address owner = _msgSender();
    //     _update(owner, to, value);
    //     return true;
    // }

    // function transferFrom(address from, address to, uint256 value) public override returns (bool) {
    //     address spender = _msgSender();
    //     _spendAllowance(from, spender, value);
    //     _update(from, to, value);
    //     return true;
    // }
    // ========== 流动性池管理函数 ==========

    /**
     * @dev 手动添加流动性（仅所有者可调用）
     * @param tokenAmount 代币数量
     * @param ethAmount ETH数量
     */
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) external onlyOwner {
        require(address(treasuryHandler)!=address(0),"treasuryHandler is invaild");
        treasuryHandler.addLiquidity(tokenAmount, ethAmount);
    }

    /**
     * @dev 手动移除流动性（仅所有者可调用）
     * @param liquidity 流动性代币数量
     */
    function removeLiquidity(uint256 liquidity) external onlyOwner {
        require(address(treasuryHandler)!=address(0),"treasuryHandler is invaild");
        treasuryHandler.removeLiquidity(liquidity);
    }


    
}
