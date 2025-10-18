pragma solidity ^0.8;

//国库模型，处理流动性挖矿奖励和税收分配
interface ITreasuryHandler {
    /**
    *@notice 处理税收分配 交易前调用
    *@param benefactor 纳税人地址
    *@param beneficiary 受益人地址
    *@param amount 交易金额
     */
    function beforeTransferHandle(
        address  benefactor,
        address beneficiary,
        uint256 amount
    ) external;
    /**
    *@notice 处理税收s分配 交易后调用
    *@param benefactor 纳税人地址
    *@param beneficiary 受益人地址
    *@param amount 交易金额
     */
    function afterTransferHandle(
        address  benefactor,
        address beneficiary,
        uint256 amount
    ) external;

}