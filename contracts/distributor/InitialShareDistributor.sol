pragma solidity ^0.5.15;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '../interfaces/IDistributor.sol';
import '../interfaces/IRewardDistributionRecipient.sol';

contract InitialShareDistributor is IDistributor {
    using SafeMath for uint256;

    event Distributed(address pool, uint256 cashAmount);

    bool public once = true;

    IERC20 public share;
    IRewardDistributionRecipient public cashLPPool;
    uint256 public cashLPInitialBalance;
    IRewardDistributionRecipient public shareLPPool;
    uint256 public shareLPInitialBalance;

    constructor(
        IERC20 _share,
        IRewardDistributionRecipient _cashLPPool,
        uint256 _cashLPInitialBalance,
        IRewardDistributionRecipient _shareLPPool,
        uint256 _shareLPInitialBalance
    ) public {
        share = _share;
        cashLPPool = _cashLPPool;
        cashLPInitialBalance = _cashLPInitialBalance;
        shareLPPool = _shareLPPool;
        shareLPInitialBalance = _shareLPInitialBalance;
    }

    function distribute() public  {
        require(
            once,
            'InitialShareDistributor: you cannot run this function twice'
        );

        share.transfer(address(cashLPPool), cashLPInitialBalance);
        cashLPPool.notifyRewardAmount(cashLPInitialBalance);
        emit Distributed(address(cashLPPool), cashLPInitialBalance);

        share.transfer(address(shareLPPool), shareLPInitialBalance);
        shareLPPool.notifyRewardAmount(shareLPInitialBalance);
        emit Distributed(address(shareLPPool), shareLPInitialBalance);

        once = false;
    }
}
