pragma solidity ^0.8;
// 代币税模块，设置交易税/持有税

interface ITaxHandler {
    /**
    *@notice 获取需要缴纳税款的金额
    *@param benefactor 纳税人地址
    *@param beneficiary 受益人地址
    *@param amount 交易金额
    *@return 需要缴纳的税款金额
     */ 
     function getTax(
     address benefactor,
     address beneficiary,
     uint256 amount
     ) external view returns (uint256);
}