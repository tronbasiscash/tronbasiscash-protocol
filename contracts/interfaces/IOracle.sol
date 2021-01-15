pragma solidity ^0.5.15;

interface IOracle {
    function callable() external view returns (bool);

    function update() external;

    function consult(address token, uint256 amountIn)
        external
        view
        returns (uint256 amountOut);
    // function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestamp);
}
