pragma solidity ^0.8;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IGovernanceToken.sol";
import "./ITaxHandler.sol";
import "./ITreasuryHandler.sol";

// Floki代币合约
contract MyFloki is IERC20, Ownable,IGovernanceToken {
    //@dev Register of user token balances
    mapping(address => uint256) private _balances;

    //@dev Register of addresses users have given allowances to.
    mapping(address => mapping(address => uint256)) private _allowances;

    //@notice Registry of user delegates for governance
    mapping(address => address) public delegates;

    //@notice Registry of nonces for vote delegation
    mapping(address => uint256) public nonces;

    // @notic Registry of the number of balance checkpoints an account has

}