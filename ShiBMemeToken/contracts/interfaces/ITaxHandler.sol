
pragma solidity ^0.8;

interface ITaxHandler {

    // Tax configuration structure (matches implementation)
    struct TaxInfoConfig {
        uint256 buyTaxFee;
        uint256 sellTaxFee;
        uint256 transferTaxFee;
        address taxWallet;
        address uniswapPair;
    }

    // 更新税务配置
    function setTaxConfig(
        uint256 _buyTax,
        uint256 _sellTax,
        uint256 _transferTax,
        address _taxWallet,
        address _uniswapPair
    ) external;

    // 获取税务配置信息
    function getTaxConfig() external view returns (TaxInfoConfig memory);

    // 向免税列表添加/移除账户地址
    function setTaxFree(address _addr, bool _isTaxFreeFlag) external;

    // 获取当前地址是否免税
    function isTaxFree(address _addr) external view returns (bool);

    // 计算给定转账/交易的税额
    function getTax(address from, address to, uint256 amount) external view returns (uint256);

    // 税费分配到特定钱包地址, 并返回需要销毁的代币数量
    function burnTax(uint256 taxAmount) external returns (uint256);
}