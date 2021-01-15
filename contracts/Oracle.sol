pragma solidity ^0.5.15;

import '@openzeppelin/contracts/math/SafeMath.sol';

import './lib/Babylonian.sol';
import './lib/FixedPoint.sol';
import './lib/UQ112.sol';
import './utils/Epoch.sol';
import './PairPrice.sol';

// fixed window oracle that recomputes the average price for the entire period once every period
// note that the price average is only guaranteed to be over at least 1 period, but may be over a longer period
contract Oracle is Epoch {
    using FixedPoint for *;
    using SafeMath for uint256;
    using UQ112x112 for uint224;

    /* ========== STATE VARIABLES ========== */

    // uniswap
    address public token0;
    address public token1;
    // IUniswapV2Pair public pair;
    IPairPrice public pair;

    // oracle
    uint32 public blockTimestampLast;
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    FixedPoint.uq112x112 public price0Average;
    FixedPoint.uq112x112 public price1Average;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        IPairPrice _pair,
        address _tokenA,
        address _tokenB,
        uint256 _period,
        uint256 _startTime
    ) public Epoch(_period, _startTime, 0) {
        pair = _pair;
        token0 = _tokenA;
        token1 = _tokenB;

        (
            uint256 price0Cumulative,
            uint256 price1Cumulative,
            uint32 blockTimestamp
        ) = currentCumulativePrices();

        price0CumulativeLast = price0Cumulative; // fetch the current accumulated price value (1 / 0)
        price1CumulativeLast = price1Cumulative; // fetch the current accumulated price value (0 / 1)
        blockTimestampLast = blockTimestamp;
    }

    /* ========== MUTABLE FUNCTIONS ========== */

    /** @dev Updates 1-day EMA price from Uniswap.  */
    function update() external checkEpoch {
        (
            uint256 price0Cumulative,
            uint256 price1Cumulative,
            uint32 blockTimestamp
        ) = currentCumulativePrices();

        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired

        if (timeElapsed == 0) {
            // prevent divided by zero
            return;
        }

        // overflow is desired, casting never truncates
        // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
        price0Average = FixedPoint.uq112x112(
            uint224((price0Cumulative - price0CumulativeLast) / timeElapsed)
        );
        price1Average = FixedPoint.uq112x112(
            uint224((price1Cumulative - price1CumulativeLast) / timeElapsed)
        );

        price0CumulativeLast = price0Cumulative;
        price1CumulativeLast = price1Cumulative;
        blockTimestampLast = blockTimestamp;

        emit Updated(price0Cumulative, price1Cumulative);
    }

    // note this will always return 0 before update has been called successfully for the first time.
    function consult(address token, uint256 amountIn)
        external
        view
        returns (uint144 amountOut)
    {
        if (token == token0) {
            amountOut = price0Average.mul(amountIn).decode144();
        } else {
            require(token == token1, 'Oracle: INVALID_TOKEN');
            amountOut = price1Average.mul(amountIn).decode144();
        }
    }

    // collaboration of update / consult
    function expectedPrice(address token, uint256 amountIn)
        external
        view
        returns (uint224 amountOut)
    {
        (
            uint256 price0Cumulative,
            uint256 price1Cumulative,
            uint32 blockTimestamp
        ) = currentCumulativePrices();
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired

        FixedPoint.uq112x112 memory avg0 =
            FixedPoint.uq112x112(
                uint224((price0Cumulative - price0CumulativeLast) / timeElapsed)
            );
        FixedPoint.uq112x112 memory avg1 =
            FixedPoint.uq112x112(
                uint224((price1Cumulative - price1CumulativeLast) / timeElapsed)
            );

        if (token == token0) {
            amountOut = avg0.mul(amountIn).decode144();
        } else {
            require(token == token1, 'Oracle: INVALID_TOKEN');
            amountOut = avg1.mul(amountIn).decode144();
        }
        return amountOut;
    }

  function currentBlockTimestamp() internal view returns (uint32) {
        return uint32(block.timestamp);
  }

  // NOTE: must use price0Cumulative, price1Cumulative, blockTimestampLast from current contract's storage
  function currentCumulativePrices() public view returns (uint price0Cumulative, uint price1Cumulative, uint32 blockTimestamp) {
        blockTimestamp = currentBlockTimestamp();
        price0Cumulative = price0CumulativeLast;
        price1Cumulative = price1CumulativeLast;

        // if time has elapsed since the last update on the pair, mock the accumulated price values
        // (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = IUniswapV2Pair(pair).getReserves();
        if (blockTimestampLast != blockTimestamp) {
            // subtraction overflow is desired
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;

            (uint112 trx0, uint112 trx1) = IPairPrice(pair).currentPrices();
            // addition overflow is desired
            // counterfactual
            price0Cumulative += uint(UQ112x112.encode(trx0).uqdiv(trx1)) * timeElapsed;
            // counterfactual
            price1Cumulative += uint(UQ112x112.encode(trx1).uqdiv(trx0)) * timeElapsed;
        }
  }

    // i think one possible problem is that blockTimestampLast in the original
    // code uses the blockTimestampLast of Oracle, but here we are using
    // blockTimestampLast of PriceFeed.
    //
    // basically the problem now is that timeElapsed is different...
    //
    // so how do i fix this.
    //
    // the problem is also price0CumulativeLast price1CumulativeLast reading
    // from pair price, which are bigger numbers.

    // collaboration of update / consult
    // function expectedPrice(address token, uint256 amountIn)
    //     external
    //     view
    //     returns (uint224 amountOut)
    // {
    //     (
    //         uint256 price0Cumulative,
    //         uint256 price1Cumulative,
    //         uint32 blockTimestamp
    //     ) = UniswapV2OracleLibrary.currentCumulativePrices(address(pair));
    //     uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired

    //     FixedPoint.uq112x112 memory avg0 =
    //         FixedPoint.uq112x112(
    //             uint224((price0Cumulative - price0CumulativeLast) / timeElapsed)
    //         );
    //     FixedPoint.uq112x112 memory avg1 =
    //         FixedPoint.uq112x112(
    //             uint224((price1Cumulative - price1CumulativeLast) / timeElapsed)
    //         );

    //     if (token == token0) {
    //         amountOut = avg0.mul(amountIn).decode144();
    //     } else {
    //         require(token == token1, 'Oracle: INVALID_TOKEN');
    //         amountOut = avg1.mul(amountIn).decode144();
    //     }
    //     return amountOut;
    // }

    // function pairFor(
    //     address factory,
    //     address tokenA,
    //     address tokenB
    // ) external pure returns (address lpt) {
    //     return UniswapV2Library.pairFor(factory, tokenA, tokenB);
    // }

    event Updated(uint256 price0CumulativeLast, uint256 price1CumulativeLast);
}
