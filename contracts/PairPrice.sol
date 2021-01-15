pragma solidity ^0.5.15;

import './lib/UQ112.sol';

interface JustSwapExchange {
  function getTokenToTrxInputPrice(uint256 tokens_sold) external view returns (uint256);
}

interface IPairPrice {
  function currentCumulativePrices() external view returns (uint price0Cumulative, uint price1Cumulative, uint32 blockTimestamp);
  function currentPrices() external view returns (uint112 trx0, uint112 trx1);
}

contract PairPrice {
  // Use the TRX prices of two assets, and calculate the relative price of two assets.
  // e.g. TRX / USDT
  using UQ112x112 for uint224;

  address public exchange0;
  address public exchange1;

  uint112 public inAmount0;
  uint112 public inAmount1;

  uint256 public price0CumulativeLast;
  uint256 public price1CumulativeLast;

  // NOTE: blockTimestampLast doesn't need to be initialized when the contract
  // is deployed, because consumer of this service takes the difference between
  // two cumulatives.
  uint32  public blockTimestampLast;

  // Disabled. For debugging.
  // uint112 public trx0;
  // uint112 public trx1;

  // _inAmount0 and _inAmount1 should be n*decimals of the target token
  constructor(address _exchange0, address _exchange1, uint112 _inAmount0, uint112 _inAmount1) public {
    exchange0 = _exchange0;
    exchange1 = _exchange1;
    inAmount0 = _inAmount0;
    inAmount1 = _inAmount1;
    update();
  }

  function update() public {
    // T1 / TRX
    uint112 trx0 = uint112(JustSwapExchange(exchange0).getTokenToTrxInputPrice(uint256(inAmount0)));
    // T2 / TRX
    uint112 trx1 = uint112(JustSwapExchange(exchange1).getTokenToTrxInputPrice(uint256(inAmount1)));

    // see also: https://github.com/Uniswap/uniswap-v2-core/issues/96
    uint32 blockTimestamp = uint32(block.timestamp);
    uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
    if (timeElapsed > 0) {

        // price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
        // price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;

        // * never overflows, and + overflow is desired
        price0CumulativeLast += uint(UQ112x112.encode(trx0).uqdiv(trx1)) * timeElapsed;
        price1CumulativeLast += uint(UQ112x112.encode(trx1).uqdiv(trx0)) * timeElapsed;
    }

    blockTimestampLast = blockTimestamp;
  }

  function currentPrices() external view returns (uint112 trx0, uint112 trx1) {
    trx0 = uint112(JustSwapExchange(exchange0).getTokenToTrxInputPrice(uint256(inAmount0)));
    trx1 = uint112(JustSwapExchange(exchange1).getTokenToTrxInputPrice(uint256(inAmount1)));
  }

  function currentBlockTimestamp() internal view returns (uint32) {
    return uint32(block.timestamp);
  }

  function currentCumulativePrices() external view returns (uint price0Cumulative, uint price1Cumulative, uint32 blockTimestamp) {
        blockTimestamp = currentBlockTimestamp();
        price0Cumulative = price0CumulativeLast;
        price1Cumulative = price1CumulativeLast;

        // if time has elapsed since the last update on the pair, mock the accumulated price values
        // (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = IUniswapV2Pair(pair).getReserves();
        if (blockTimestampLast != blockTimestamp) {
            // subtraction overflow is desired
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;

            uint112 trx0 = uint112(JustSwapExchange(exchange0).getTokenToTrxInputPrice(uint256(inAmount0)));
            uint112 trx1 = uint112(JustSwapExchange(exchange1).getTokenToTrxInputPrice(uint256(inAmount1)));
            // addition overflow is desired
            // counterfactual
            price0Cumulative += uint(UQ112x112.encode(trx0).uqdiv(trx1)) * timeElapsed;
            // counterfactual
            price1Cumulative += uint(UQ112x112.encode(trx1).uqdiv(trx0)) * timeElapsed;
        }
  }
}