pragma solidity ^0.5.15;

// interface IOracle {
//     function callable() external view returns (bool);

//     function update() external;

//     function consult(address token, uint256 amountIn)
//         external
//         view
//         returns (uint256 amountOut);
//     // function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestamp);
// }

contract FakeOracle {

  uint256 public amountOut;

  function callable() external view returns (bool) {
    return true;
  }

  function update() external {
    // no op
  }

  function consult(address token, uint256 amountIn) external view returns (uint256) {
    // amountsIn is always 1e18 from treasury
    require(amountIn == 1e18, "amountIn must be 1e18");
    return amountOut;
  }

  function setAmountOut(uint256 value) public {
    amountOut = value;
  }
}