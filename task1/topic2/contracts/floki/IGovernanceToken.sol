pragma solidity ^0.8;
// 治理模块
/**
定义检查点结构，用于记录区块号和投票数

提供历史投票查询接口
 */
interface IGovernanceToken {
    struct CheckPoint {
        uint32 blockNumber;
        uint224 votes;
    
    }

    function getVotesAtBlock(address account,uint32 blockNumber) external view returns (uint224);
    // 每当用户变更新的委托人时发出通知
    event DelegateChanged (address delegator, address currentDelegate, address newDelegate);
    event DeleteVotesChaned(address delegate, uint224 oldVotes, uint224 newVotes);

}