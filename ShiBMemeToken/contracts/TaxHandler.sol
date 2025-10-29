pragma solidity ^0.8;

import "./interfaces/ITaxHandler.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
contract TaxHandler is ITaxHandler, Ownable {
    mapping(address => bool) private _isTaxFree; // 设置是否收税开关
    event TaxFreeChanged(address indexed addr,bool flag);
        // 事件
    event TaxDistributed(uint256 amount, address indexed taxWallet);

    event TaxConfigUpdated(
        uint256 buyTaxFee,
        uint256 sellTaxFee,
        uint256 transferTaxFee,
        address taxWallet,
        address uniswapPair
    );
    
    // ---- 税收核心配置 ----
    // 交易税率配置 单位：500 -> 5%
    // 买入税率（基于10000，例如100表示1%）
    uint256 private _buyTaxFee;
    // 卖出税率（基于10000，例如100表示1%）
    uint256 private  _sellTaxFee;
    // 交易税率（基于10000，例如100表示1%）
    uint256 private _transferTaxFee;
    // 税收入款钱包
    address public taxWallet;
    // Uniswap交易对地址，用于判断交易类型
    address public uniswapPair;

    // ---- 税费处理比例 ----
    // （基于10000，例如100表示1%） 固定维护代币经济
    uint256 private _burnRatio;

    TaxInfoConfig private _taxInfoConfig;


    constructor(
    uint256 buyTaxFee_,
    uint256 sellTaxFee_,
    uint256 transferTaxFee_,
    address taxWallet_,
    address uniswapPair_
    ) Ownable(msg.sender) {
        //初始化配置

        _buyTaxFee = buyTaxFee_;
        _sellTaxFee = sellTaxFee_;
        _transferTaxFee = transferTaxFee_;
        taxWallet = taxWallet_;
        uniswapPair = uniswapPair_;
        _taxInfoConfig = TaxInfoConfig({
             buyTaxFee : _buyTaxFee,
             sellTaxFee : _sellTaxFee,
             transferTaxFee : _transferTaxFee,
             taxWallet : taxWallet,
             uniswapPair:uniswapPair
        });

        // 默认排除所有者和税务钱包进行税务计算
        _isTaxFree[msg.sender] = true;
        _isTaxFree[taxWallet] = true;

        // 设置销毁代币比例，从税收进行获取，税收比例的10%进行销毁
        _burnRatio = 1000;
    }
    
        // 更新税务配置
    function setTaxConfig(
        uint256 _buyTax,
        uint256 _sellTax,
        uint256 _transferTax,
        address _taxWallet,
        address _uniswapPair
    ) external onlyOwner{
        //限制最高阀值：10%
        require(_buyTax <= 1000 && _sellTax <= 1000 && _transferTax <= 1000, "Tax too high");
        require(_taxWallet != address(0), "Tax wallet cannot be zero address");
        
        _buyTaxFee = _buyTax;
        _sellTaxFee = _sellTax;
        _transferTaxFee = _transferTax;
        taxWallet = _taxWallet;
        uniswapPair = _uniswapPair;
         _taxInfoConfig = TaxInfoConfig({
             buyTaxFee : _buyTaxFee,
             sellTaxFee : _sellTaxFee,
             transferTaxFee : _transferTaxFee,
             taxWallet : taxWallet,
             uniswapPair : uniswapPair
        });

    }
    //获取税务配置信息
    function getTaxConfig() public view returns(TaxInfoConfig memory){
        return _taxInfoConfig;
    }
    
    function setTaxFree(address _addr, bool _isTaxFreeFlag) external onlyOwner {
        require(address(_addr)!=address(0),"setTaxFree address invalid");
        _isTaxFree[_addr] = _isTaxFreeFlag;
        emit TaxFreeChanged(_addr, _isTaxFree[_addr]);
    }

    function isTaxFree(address _addr) external view override returns (bool) {
        require(address(_addr)!=address(0),"isTaxFree address invalid");
        return _isTaxFree[_addr];
    }
    function getTax(address from, address to, uint256 amount) external view override returns(uint256){
        require(from != address(0),"getTax address invalid");
        require(to != address(0),"getTax address invalid");
        require(amount > 0,"getTax amount invalid");

        //判断是否存在免税地址列表
        if (_isTaxFree[from]) {
            return 0;
        }
        if (_isTaxFree[to]) {
            return 0;
        }

        // 根据交易类型计算税率
        if (from == _taxInfoConfig.uniswapPair) {
            // 买入交易 - 普通用户从交易所购买代币
            return amount * _taxInfoConfig.buyTaxFee / 10000;
        } else if (to == _taxInfoConfig.uniswapPair) {
            // 卖出交易 - 普通用户向交易所卖出代币
            return amount * _taxInfoConfig.sellTaxFee / 10000;
        } else {
            // 普通转账 - 用户之间的代币转账
            return amount * _taxInfoConfig.transferTaxFee / 10000;
        }

    }
    //税费分配特定钱包地址,并返回需要销毁的代币数量
    function burnTax(uint256 taxAmount) external override returns(uint256) {
        require(taxAmount > 0, "Tax amount must be positive");
        //发起转账

        //销毁金额
        uint256 burnAmount = taxAmount * _burnRatio / 10000;
        require(burnAmount < taxAmount, "Burn amount must be less than tax amount"); 
        // 这里需要实现实际的代币转移逻辑
        // 由于没有token引用，暂时返回burnAmount
        return burnAmount;
    }
}
