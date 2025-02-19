/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-08-10
*/

// Sources flattened with hardhat v2.9.6 https://hardhat.org

// File @rari-capital/solmate/src/utils/[email protected]


pragma solidity >=0.8.0;

/// @notice Arithmetic library with operations for fixed-point numbers.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/FixedPointMathLib.sol)
/// @author Inspired by USM (https://github.com/usmfum/USM/blob/master/contracts/WadMath.sol)
library FixedPointMathLib {
    /*//////////////////////////////////////////////////////////////
                    SIMPLIFIED FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant WAD = 1e18; // The scalar of ETH and most ERC20s.

    function mulWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, y, WAD); // Equivalent to (x * y) / WAD rounded down.
    }

    function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, y, WAD); // Equivalent to (x * y) / WAD rounded up.
    }

    function divWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, WAD, y); // Equivalent to (x * WAD) / y rounded down.
    }

    function divWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, WAD, y); // Equivalent to (x * WAD) / y rounded up.
    }

    /*//////////////////////////////////////////////////////////////
                    LOW LEVEL FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function mulDivDown(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
            // Store x * y in z for now.
            z := mul(x, y)

            // Equivalent to require(denominator != 0 && (x == 0 || (x * y) / x == y))
            if iszero(and(iszero(iszero(denominator)), or(iszero(x), eq(div(z, x), y)))) {
                revert(0, 0)
            }

            // Divide z by the denominator.
            z := div(z, denominator)
        }
    }

    function mulDivUp(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
            // Store x * y in z for now.
            z := mul(x, y)

            // Equivalent to require(denominator != 0 && (x == 0 || (x * y) / x == y))
            if iszero(and(iszero(iszero(denominator)), or(iszero(x), eq(div(z, x), y)))) {
                revert(0, 0)
            }

            // First, divide z - 1 by the denominator and add 1.
            // We allow z - 1 to underflow if z is 0, because we multiply the
            // end result by 0 if z is zero, ensuring we return 0 if z is zero.
            z := mul(iszero(iszero(z)), add(div(sub(z, 1), denominator), 1))
        }
    }

    function rpow(
        uint256 x,
        uint256 n,
        uint256 scalar
    ) internal pure returns (uint256 z) {
        assembly {
            switch x
            case 0 {
                switch n
                case 0 {
                    // 0 ** 0 = 1
                    z := scalar
                }
                default {
                    // 0 ** n = 0
                    z := 0
                }
            }
            default {
                switch mod(n, 2)
                case 0 {
                    // If n is even, store scalar in z for now.
                    z := scalar
                }
                default {
                    // If n is odd, store x in z for now.
                    z := x
                }

                // Shifting right by 1 is like dividing by 2.
                let half := shr(1, scalar)

                for {
                    // Shift n right by 1 before looping to halve it.
                    n := shr(1, n)
                } n {
                    // Shift n right by 1 each iteration to halve it.
                    n := shr(1, n)
                } {
                    // Revert immediately if x ** 2 would overflow.
                    // Equivalent to iszero(eq(div(xx, x), x)) here.
                    if shr(128, x) {
                        revert(0, 0)
                    }

                    // Store x squared.
                    let xx := mul(x, x)

                    // Round to the nearest number.
                    let xxRound := add(xx, half)

                    // Revert if xx + half overflowed.
                    if lt(xxRound, xx) {
                        revert(0, 0)
                    }

                    // Set x to scaled xxRound.
                    x := div(xxRound, scalar)

                    // If n is even:
                    if mod(n, 2) {
                        // Compute z * x.
                        let zx := mul(z, x)

                        // If z * x overflowed:
                        if iszero(eq(div(zx, x), z)) {
                            // Revert if x is non-zero.
                            if iszero(iszero(x)) {
                                revert(0, 0)
                            }
                        }

                        // Round to the nearest number.
                        let zxRound := add(zx, half)

                        // Revert if zx + half overflowed.
                        if lt(zxRound, zx) {
                            revert(0, 0)
                        }

                        // Return properly scaled zxRound.
                        z := div(zxRound, scalar)
                    }
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        GENERAL NUMBER UTILITIES
    //////////////////////////////////////////////////////////////*/

    function sqrt(uint256 x) internal pure returns (uint256 z) {
        assembly {
            // Start off with z at 1.
            z := 1

            // Used below to help find a nearby power of 2.
            let y := x

            // Find the lowest power of 2 that is at least sqrt(x).
            if iszero(lt(y, 0x100000000000000000000000000000000)) {
                y := shr(128, y) // Like dividing by 2 ** 128.
                z := shl(64, z) // Like multiplying by 2 ** 64.
            }
            if iszero(lt(y, 0x10000000000000000)) {
                y := shr(64, y) // Like dividing by 2 ** 64.
                z := shl(32, z) // Like multiplying by 2 ** 32.
            }
            if iszero(lt(y, 0x100000000)) {
                y := shr(32, y) // Like dividing by 2 ** 32.
                z := shl(16, z) // Like multiplying by 2 ** 16.
            }
            if iszero(lt(y, 0x10000)) {
                y := shr(16, y) // Like dividing by 2 ** 16.
                z := shl(8, z) // Like multiplying by 2 ** 8.
            }
            if iszero(lt(y, 0x100)) {
                y := shr(8, y) // Like dividing by 2 ** 8.
                z := shl(4, z) // Like multiplying by 2 ** 4.
            }
            if iszero(lt(y, 0x10)) {
                y := shr(4, y) // Like dividing by 2 ** 4.
                z := shl(2, z) // Like multiplying by 2 ** 2.
            }
            if iszero(lt(y, 0x8)) {
                // Equivalent to 2 ** z.
                z := shl(1, z)
            }

            // Shifting right by 1 is like dividing by 2.
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            // Compute a rounded down version of z.
            let zRoundDown := div(x, z)

            // If zRoundDown is smaller, use it.
            if lt(zRoundDown, z) {
                z := zRoundDown
            }
        }
    }
}


// File contracts/libraries/DecimalMath.sol


//
//Copyright (c) 2019 Synthetix
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

pragma solidity ^0.8.9;

/**
 * @title DecimalMath
 * @author Lyra
 * @dev Modified synthetix SafeDecimalMath to include internal arithmetic underflow/overflow.
 * @dev https://docs.synthetix.io/contracts/source/libraries/SafeDecimalMath/
 */

library DecimalMath {
  /* Number of decimal places in the representations. */
  uint8 public constant decimals = 18;
  uint8 public constant highPrecisionDecimals = 27;

  /* The number representing 1.0. */
  uint public constant UNIT = 10**uint(decimals);

  /* The number representing 1.0 for higher fidelity numbers. */
  uint public constant PRECISE_UNIT = 10**uint(highPrecisionDecimals);
  uint private constant UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR = 10**uint(highPrecisionDecimals - decimals);

  /**
   * @return Provides an interface to UNIT.
   */
  function unit() external pure returns (uint) {
    return UNIT;
  }

  /**
   * @return Provides an interface to PRECISE_UNIT.
   */
  function preciseUnit() external pure returns (uint) {
    return PRECISE_UNIT;
  }

  /**
   * @return The result of multiplying x and y, interpreting the operands as fixed-point
   * decimals.
   *
   * @dev A unit factor is divided out after the product of x and y is evaluated,
   * so that product must be less than 2**256. As this is an integer division,
   * the internal division always rounds down. This helps save on gas. Rounding
   * is more expensive on gas.
   */
  function multiplyDecimal(uint x, uint y) internal pure returns (uint) {
    /* Divide by UNIT to remove the extra factor introduced by the product. */
    return (x * y) / UNIT;
  }

  /**
   * @return The result of safely multiplying x and y, interpreting the operands
   * as fixed-point decimals of the specified precision unit.
   *
   * @dev The operands should be in the form of a the specified unit factor which will be
   * divided out after the product of x and y is evaluated, so that product must be
   * less than 2**256.
   *
   * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
   * Rounding is useful when you need to retain fidelity for small decimal numbers
   * (eg. small fractions or percentages).
   */
  function _multiplyDecimalRound(
    uint x,
    uint y,
    uint precisionUnit
  ) private pure returns (uint) {
    /* Divide by UNIT to remove the extra factor introduced by the product. */
    uint quotientTimesTen = (x * y) / (precisionUnit / 10);

    if (quotientTimesTen % 10 >= 5) {
      quotientTimesTen += 10;
    }

    return quotientTimesTen / 10;
  }

  /**
   * @return The result of safely multiplying x and y, interpreting the operands
   * as fixed-point decimals of a precise unit.
   *
   * @dev The operands should be in the precise unit factor which will be
   * divided out after the product of x and y is evaluated, so that product must be
   * less than 2**256.
   *
   * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
   * Rounding is useful when you need to retain fidelity for small decimal numbers
   * (eg. small fractions or percentages).
   */
  function multiplyDecimalRoundPrecise(uint x, uint y) internal pure returns (uint) {
    return _multiplyDecimalRound(x, y, PRECISE_UNIT);
  }

  /**
   * @return The result of safely multiplying x and y, interpreting the operands
   * as fixed-point decimals of a standard unit.
   *
   * @dev The operands should be in the standard unit factor which will be
   * divided out after the product of x and y is evaluated, so that product must be
   * less than 2**256.
   *
   * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
   * Rounding is useful when you need to retain fidelity for small decimal numbers
   * (eg. small fractions or percentages).
   */
  function multiplyDecimalRound(uint x, uint y) internal pure returns (uint) {
    return _multiplyDecimalRound(x, y, UNIT);
  }

  /**
   * @return The result of safely dividing x and y. The return value is a high
   * precision decimal.
   *
   * @dev y is divided after the product of x and the standard precision unit
   * is evaluated, so the product of x and UNIT must be less than 2**256. As
   * this is an integer division, the result is always rounded down.
   * This helps save on gas. Rounding is more expensive on gas.
   */
  function divideDecimal(uint x, uint y) internal pure returns (uint) {
    /* Reintroduce the UNIT factor that will be divided out by y. */
    return (x * UNIT) / y;
  }

  /**
   * @return The result of safely dividing x and y. The return value is as a rounded
   * decimal in the precision unit specified in the parameter.
   *
   * @dev y is divided after the product of x and the specified precision unit
   * is evaluated, so the product of x and the specified precision unit must
   * be less than 2**256. The result is rounded to the nearest increment.
   */
  function _divideDecimalRound(
    uint x,
    uint y,
    uint precisionUnit
  ) private pure returns (uint) {
    uint resultTimesTen = (x * (precisionUnit * 10)) / y;

    if (resultTimesTen % 10 >= 5) {
      resultTimesTen += 10;
    }

    return resultTimesTen / 10;
  }

  /**
   * @return The result of safely dividing x and y. The return value is as a rounded
   * standard precision decimal.
   *
   * @dev y is divided after the product of x and the standard precision unit
   * is evaluated, so the product of x and the standard precision unit must
   * be less than 2**256. The result is rounded to the nearest increment.
   */
  function divideDecimalRound(uint x, uint y) internal pure returns (uint) {
    return _divideDecimalRound(x, y, UNIT);
  }

  /**
   * @return The result of safely dividing x and y. The return value is as a rounded
   * high precision decimal.
   *
   * @dev y is divided after the product of x and the high precision unit
   * is evaluated, so the product of x and the high precision unit must
   * be less than 2**256. The result is rounded to the nearest increment.
   */
  function divideDecimalRoundPrecise(uint x, uint y) internal pure returns (uint) {
    return _divideDecimalRound(x, y, PRECISE_UNIT);
  }

  /**
   * @dev Convert a standard decimal representation to a high precision one.
   */
  function decimalToPreciseDecimal(uint i) internal pure returns (uint) {
    return i * UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR;
  }

  /**
   * @dev Convert a high precision decimal to a standard decimal representation.
   */
  function preciseDecimalToDecimal(uint i) internal pure returns (uint) {
    uint quotientTimesTen = i / (UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR / 10);

    if (quotientTimesTen % 10 >= 5) {
      quotientTimesTen += 10;
    }

    return quotientTimesTen / 10;
  }
}


// File contracts/libraries/SignedDecimalMath.sol


//
//Copyright (c) 2019 Synthetix
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

pragma solidity ^0.8.9;

/**
 * @title SignedDecimalMath
 * @author Lyra
 * @dev Modified synthetix SafeSignedDecimalMath to include internal arithmetic underflow/overflow.
 * @dev https://docs.synthetix.io/contracts/source/libraries/safedecimalmath
 */
library SignedDecimalMath {
  /* Number of decimal places in the representations. */
  uint8 public constant decimals = 18;
  uint8 public constant highPrecisionDecimals = 27;

  /* The number representing 1.0. */
  int public constant UNIT = int(10**uint(decimals));

  /* The number representing 1.0 for higher fidelity numbers. */
  int public constant PRECISE_UNIT = int(10**uint(highPrecisionDecimals));
  int private constant UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR = int(10**uint(highPrecisionDecimals - decimals));

  /**
   * @return Provides an interface to UNIT.
   */
  function unit() external pure returns (int) {
    return UNIT;
  }

  /**
   * @return Provides an interface to PRECISE_UNIT.
   */
  function preciseUnit() external pure returns (int) {
    return PRECISE_UNIT;
  }

  /**
   * @dev Rounds an input with an extra zero of precision, returning the result without the extra zero.
   * Half increments round away from zero; positive numbers at a half increment are rounded up,
   * while negative such numbers are rounded down. This behaviour is designed to be consistent with the
   * unsigned version of this library (SafeDecimalMath).
   */
  function _roundDividingByTen(int valueTimesTen) private pure returns (int) {
    int increment;
    if (valueTimesTen % 10 >= 5) {
      increment = 10;
    } else if (valueTimesTen % 10 <= -5) {
      increment = -10;
    }
    return (valueTimesTen + increment) / 10;
  }

  /**
   * @return The result of multiplying x and y, interpreting the operands as fixed-point
   * decimals.
   *
   * @dev A unit factor is divided out after the product of x and y is evaluated,
   * so that product must be less than 2**256. As this is an integer division,
   * the internal division always rounds down. This helps save on gas. Rounding
   * is more expensive on gas.
   */
  function multiplyDecimal(int x, int y) internal pure returns (int) {
    /* Divide by UNIT to remove the extra factor introduced by the product. */
    return (x * y) / UNIT;
  }

  /**
   * @return The result of safely multiplying x and y, interpreting the operands
   * as fixed-point decimals of the specified precision unit.
   *
   * @dev The operands should be in the form of a the specified unit factor which will be
   * divided out after the product of x and y is evaluated, so that product must be
   * less than 2**256.
   *
   * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
   * Rounding is useful when you need to retain fidelity for small decimal numbers
   * (eg. small fractions or percentages).
   */
  function _multiplyDecimalRound(
    int x,
    int y,
    int precisionUnit
  ) private pure returns (int) {
    /* Divide by UNIT to remove the extra factor introduced by the product. */
    int quotientTimesTen = (x * y) / (precisionUnit / 10);
    return _roundDividingByTen(quotientTimesTen);
  }

  /**
   * @return The result of safely multiplying x and y, interpreting the operands
   * as fixed-point decimals of a precise unit.
   *
   * @dev The operands should be in the precise unit factor which will be
   * divided out after the product of x and y is evaluated, so that product must be
   * less than 2**256.
   *
   * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
   * Rounding is useful when you need to retain fidelity for small decimal numbers
   * (eg. small fractions or percentages).
   */
  function multiplyDecimalRoundPrecise(int x, int y) internal pure returns (int) {
    return _multiplyDecimalRound(x, y, PRECISE_UNIT);
  }

  /**
   * @return The result of safely multiplying x and y, interpreting the operands
   * as fixed-point decimals of a standard unit.
   *
   * @dev The operands should be in the standard unit factor which will be
   * divided out after the product of x and y is evaluated, so that product must be
   * less than 2**256.
   *
   * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
   * Rounding is useful when you need to retain fidelity for small decimal numbers
   * (eg. small fractions or percentages).
   */
  function multiplyDecimalRound(int x, int y) internal pure returns (int) {
    return _multiplyDecimalRound(x, y, UNIT);
  }

  /**
   * @return The result of safely dividing x and y. The return value is a high
   * precision decimal.
   *
   * @dev y is divided after the product of x and the standard precision unit
   * is evaluated, so the product of x and UNIT must be less than 2**256. As
   * this is an integer division, the result is always rounded down.
   * This helps save on gas. Rounding is more expensive on gas.
   */
  function divideDecimal(int x, int y) internal pure returns (int) {
    /* Reintroduce the UNIT factor that will be divided out by y. */
    return (x * UNIT) / y;
  }

  /**
   * @return The result of safely dividing x and y. The return value is as a rounded
   * decimal in the precision unit specified in the parameter.
   *
   * @dev y is divided after the product of x and the specified precision unit
   * is evaluated, so the product of x and the specified precision unit must
   * be less than 2**256. The result is rounded to the nearest increment.
   */
  function _divideDecimalRound(
    int x,
    int y,
    int precisionUnit
  ) private pure returns (int) {
    int resultTimesTen = (x * (precisionUnit * 10)) / y;
    return _roundDividingByTen(resultTimesTen);
  }

  /**
   * @return The result of safely dividing x and y. The return value is as a rounded
   * standard precision decimal.
   *
   * @dev y is divided after the product of x and the standard precision unit
   * is evaluated, so the product of x and the standard precision unit must
   * be less than 2**256. The result is rounded to the nearest increment.
   */
  function divideDecimalRound(int x, int y) internal pure returns (int) {
    return _divideDecimalRound(x, y, UNIT);
  }

  /**
   * @return The result of safely dividing x and y. The return value is as a rounded
   * high precision decimal.
   *
   * @dev y is divided after the product of x and the high precision unit
   * is evaluated, so the product of x and the high precision unit must
   * be less than 2**256. The result is rounded to the nearest increment.
   */
  function divideDecimalRoundPrecise(int x, int y) internal pure returns (int) {
    return _divideDecimalRound(x, y, PRECISE_UNIT);
  }

  /**
   * @dev Convert a standard decimal representation to a high precision one.
   */
  function decimalToPreciseDecimal(int i) internal pure returns (int) {
    return i * UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR;
  }

  /**
   * @dev Convert a high precision decimal to a standard decimal representation.
   */
  function preciseDecimalToDecimal(int i) internal pure returns (int) {
    int quotientTimesTen = i / (UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR / 10);
    return _roundDividingByTen(quotientTimesTen);
  }
}


// File contracts/libraries/HigherMath.sol

pragma solidity 0.8.9;

// Slightly modified version of:
// - https://github.com/recmo/experiment-solexp/blob/605738f3ed72d6c67a414e992be58262fbc9bb80/src/FixedPointMathLib.sol
library HigherMath {
  /// @dev Computes ln(x) for a 1e27 fixed point. Loses 9 last significant digits of precision.
  function lnPrecise(int x) internal pure returns (int r) {
    return ln(x / 1e9) * 1e9;
  }

  /// @dev Computes e ^ x for a 1e27 fixed point. Loses 9 last significant digits of precision.
  function expPrecise(int x) internal pure returns (uint r) {
    return exp(x / 1e9) * 1e9;
  }

  // Computes ln(x) in 1e18 fixed point.
  // Reverts if x is negative or zero.
  // Consumes 670 gas.
  function ln(int x) internal pure returns (int r) {
    unchecked {
      if (x < 1) {
        if (x < 0) revert LnNegativeUndefined();
        revert Overflow();
      }

      // We want to convert x from 10**18 fixed point to 2**96 fixed point.
      // We do this by multiplying by 2**96 / 10**18.
      // But since ln(x * C) = ln(x) + ln(C), we can simply do nothing here
      // and add ln(2**96 / 10**18) at the end.

      // Reduce range of x to (1, 2) * 2**96
      // ln(2^k * x) = k * ln(2) + ln(x)
      // Note: inlining ilog2 saves 8 gas.
      int k = int(ilog2(uint(x))) - 96;
      x <<= uint(159 - k);
      x = int(uint(x) >> 159);

      // Evaluate using a (8, 8)-term rational approximation
      // p is made monic, we will multiply by a scale factor later
      int p = x + 3273285459638523848632254066296;
      p = ((p * x) >> 96) + 24828157081833163892658089445524;
      p = ((p * x) >> 96) + 43456485725739037958740375743393;
      p = ((p * x) >> 96) - 11111509109440967052023855526967;
      p = ((p * x) >> 96) - 45023709667254063763336534515857;
      p = ((p * x) >> 96) - 14706773417378608786704636184526;
      p = p * x - (795164235651350426258249787498 << 96);
      //emit log_named_int("p", p);
      // We leave p in 2**192 basis so we don't need to scale it back up for the division.
      // q is monic by convention
      int q = x + 5573035233440673466300451813936;
      q = ((q * x) >> 96) + 71694874799317883764090561454958;
      q = ((q * x) >> 96) + 283447036172924575727196451306956;
      q = ((q * x) >> 96) + 401686690394027663651624208769553;
      q = ((q * x) >> 96) + 204048457590392012362485061816622;
      q = ((q * x) >> 96) + 31853899698501571402653359427138;
      q = ((q * x) >> 96) + 909429971244387300277376558375;
      assembly {
        // Div in assembly because solidity adds a zero check despite the `unchecked`.
        // The q polynomial is known not to have zeros in the domain. (All roots are complex)
        // No scaling required because p is already 2**96 too large.
        r := sdiv(p, q)
      }
      // r is in the range (0, 0.125) * 2**96

      // Finalization, we need to
      // * multiply by the scale factor s = 5.549…
      // * add ln(2**96 / 10**18)
      // * add k * ln(2)
      // * multiply by 10**18 / 2**96 = 5**18 >> 78
      // mul s * 5e18 * 2**96, base is now 5**18 * 2**192
      r *= 1677202110996718588342820967067443963516166;
      // add ln(2) * k * 5e18 * 2**192
      r += 16597577552685614221487285958193947469193820559219878177908093499208371 * k;
      // add ln(2**96 / 10**18) * 5e18 * 2**192
      r += 600920179829731861736702779321621459595472258049074101567377883020018308;
      // base conversion: mul 2**18 / 2**192
      r >>= 174;
    }
  }

  // Integer log2
  // @returns floor(log2(x)) if x is nonzero, otherwise 0. This is the same
  //          as the location of the highest set bit.
  // Consumes 232 gas. This could have been an 3 gas EVM opcode though.
  function ilog2(uint x) internal pure returns (uint r) {
    assembly {
      r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
      r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
      r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
      r := or(r, shl(4, lt(0xffff, shr(r, x))))
      r := or(r, shl(3, lt(0xff, shr(r, x))))
      r := or(r, shl(2, lt(0xf, shr(r, x))))
      r := or(r, shl(1, lt(0x3, shr(r, x))))
      r := or(r, lt(0x1, shr(r, x)))
    }
  }

  // Computes e^x in 1e18 fixed point.
  function exp(int x) internal pure returns (uint r) {
    unchecked {
      // Input x is in fixed point format, with scale factor 1/1e18.

      // When the result is < 0.5 we return zero. This happens when
      // x <= floor(log(0.5e18) * 1e18) ~ -42e18
      if (x <= -42139678854452767551) {
        return 0;
      }

      // When the result is > (2**255 - 1) / 1e18 we can not represent it
      // as an int256. This happens when x >= floor(log((2**255 -1) / 1e18) * 1e18) ~ 135.
      if (x >= 135305999368893231589) revert ExpOverflow();

      // x is now in the range (-42, 136) * 1e18. Convert to (-42, 136) * 2**96
      // for more intermediate precision and a binary basis. This base conversion
      // is a multiplication by 1e18 / 2**96 = 5**18 / 2**78.
      x = (x << 78) / 5**18;

      // Reduce range of x to (-½ ln 2, ½ ln 2) * 2**96 by factoring out powers of two
      // such that exp(x) = exp(x') * 2**k, where k is an integer.
      // Solving this gives k = round(x / log(2)) and x' = x - k * log(2).
      int k = ((x << 96) / 54916777467707473351141471128 + 2**95) >> 96;
      x = x - k * 54916777467707473351141471128;
      // k is in the range [-61, 195].

      // Evaluate using a (6, 7)-term rational approximation
      // p is made monic, we will multiply by a scale factor later
      int p = x + 2772001395605857295435445496992;
      p = ((p * x) >> 96) + 44335888930127919016834873520032;
      p = ((p * x) >> 96) + 398888492587501845352592340339721;
      p = ((p * x) >> 96) + 1993839819670624470859228494792842;
      p = p * x + (4385272521454847904632057985693276 << 96);
      // We leave p in 2**192 basis so we don't need to scale it back up for the division.
      // Evaluate using using Knuth's scheme from p. 491.
      int z = x + 750530180792738023273180420736;
      z = ((z * x) >> 96) + 32788456221302202726307501949080;
      int w = x - 2218138959503481824038194425854;
      w = ((w * z) >> 96) + 892943633302991980437332862907700;
      int q = z + w - 78174809823045304726920794422040;
      q = ((q * w) >> 96) + 4203224763890128580604056984195872;
      assembly {
        // Div in assembly because solidity adds a zero check despite the `unchecked`.
        // The q polynomial is known not to have zeros in the domain. (All roots are complex)
        // No scaling required because p is already 2**96 too large.
        r := sdiv(p, q)
      }
      // r should be in the range (0.09, 0.25) * 2**96.

      // We now need to multiply r by
      //  * the scale factor s = ~6.031367120...,
      //  * the 2**k factor from the range reduction, and
      //  * the 1e18 / 2**96 factor for base converison.
      // We do all of this at once, with an intermediate result in 2**213 basis
      // so the final right shift is always by a positive amount.
      r = (uint(r) * 3822833074963236453042738258902158003155416615667) >> uint(195 - k);
    }
  }

  error Overflow();
  error ExpOverflow();
  error LnNegativeUndefined();
}


// File contracts/libraries/BlackScholes.sol


//ISC License
//
//Copyright (c) 2021 Lyra Finance
//
//Permission to use, copy, modify, and/or distribute this software for any
//purpose with or without fee is hereby granted, provided that the above
//copyright notice and this permission notice appear in all copies.
//
//THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
//REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
//AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
//INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
//LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
//OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
//PERFORMANCE OF THIS SOFTWARE.

pragma solidity 0.8.9;



/**
* @title BlackScholes
* @author Lyra
* @dev Contract to compute the black scholes price of options. Where the unit is unspecified, it should be treated as a
* PRECISE_DECIMAL, which has 1e27 units of precision. The default decimal matches the ethereum standard of 1e18 units
* of precision.
*/
library BlackScholesLib {
    using DecimalMath for uint;
    using SignedDecimalMath for int;
    
    struct PricesDeltaStdVega {
        uint callPrice;
        uint putPrice;
        int callDelta;
        int putDelta;
        uint vega;
        uint stdVega;
    }
    
    /**
    * @param timeToExpirySec Number of seconds to the expiry of the option
    * @param volatilityDecimal Implied volatility over the period til expiry as a percentage
    * @param spotDecimal The current price of the base asset
    * @param strikePriceDecimal The strikePrice price of the option
    * @param rateDecimal The percentage risk free rate + carry cost
    */
    struct BlackScholesInputs {
        uint timeToExpirySec;
        uint volatilityDecimal;
        uint spotDecimal;
        uint strikePriceDecimal;
        int rateDecimal;
    }
    
    uint private constant SECONDS_PER_YEAR = 31536000;
    /// @dev Internally this library uses 27 decimals of precision
    uint private constant PRECISE_UNIT = 1e27;
    uint private constant SQRT_TWOPI = 2506628274631000502415765285;
    /// @dev Below this value, return 0
    int private constant MIN_CDF_STD_DIST_INPUT = (int(PRECISE_UNIT) * -45) / 10; // -4.5
    /// @dev Above this value, return 1
    int private constant MAX_CDF_STD_DIST_INPUT = int(PRECISE_UNIT) * 10;
    /// @dev Value to use to avoid any division by 0 or values near 0
    uint private constant MIN_T_ANNUALISED = PRECISE_UNIT / SECONDS_PER_YEAR; // 1 second
    uint private constant MIN_VOLATILITY = PRECISE_UNIT / 10000; // 0.001%
    uint private constant VEGA_STANDARDISATION_MIN_DAYS = 7 days;
    /// @dev Magic numbers for normal CDF
    uint private constant SPLIT = 7071067811865470000000000000;
    uint private constant N0 = 220206867912376000000000000000;
    uint private constant N1 = 221213596169931000000000000000;
    uint private constant N2 = 112079291497871000000000000000;
    uint private constant N3 = 33912866078383000000000000000;
    uint private constant N4 = 6373962203531650000000000000;
    uint private constant N5 = 700383064443688000000000000;
    uint private constant N6 = 35262496599891100000000000;
    uint private constant M0 = 440413735824752000000000000000;
    uint private constant M1 = 793826512519948000000000000000;
    uint private constant M2 = 637333633378831000000000000000;
    uint private constant M3 = 296564248779674000000000000000;
    uint private constant M4 = 86780732202946100000000000000;
    uint private constant M5 = 16064177579207000000000000000;
    uint private constant M6 = 1755667163182640000000000000;
    uint private constant M7 = 88388347648318400000000000;
    
    /////////////////////////////////////
    // Option Pricing public functions //
    /////////////////////////////////////
    
    /**
    * @dev Returns call and put prices for options with given parameters.
    */
    function optionPrices(BlackScholesInputs memory bsInput) public pure returns (uint call, uint put) {
        uint tAnnualised = _annualise(bsInput.timeToExpirySec);
        uint spotPrecise = bsInput.spotDecimal.decimalToPreciseDecimal();
        uint strikePricePrecise = bsInput.strikePriceDecimal.decimalToPreciseDecimal();
        int ratePrecise = bsInput.rateDecimal.decimalToPreciseDecimal();
        (int d1, int d2) = _d1d2(
            tAnnualised,
            bsInput.volatilityDecimal.decimalToPreciseDecimal(),
            spotPrecise,
            strikePricePrecise,
            ratePrecise
        );
        (call, put) = _optionPrices(tAnnualised, spotPrecise, strikePricePrecise, ratePrecise, d1, d2);
        return (call.preciseDecimalToDecimal(), put.preciseDecimalToDecimal());
    }
    
    /**
    * @dev Returns call/put prices and delta/stdVega for options with given parameters.
    */
    function pricesDeltaStdVega(BlackScholesInputs memory bsInput) public pure returns (PricesDeltaStdVega memory) {
        uint tAnnualised = _annualise(bsInput.timeToExpirySec);
        uint spotPrecise = bsInput.spotDecimal.decimalToPreciseDecimal();
        
        (int d1, int d2) = _d1d2(
            tAnnualised,
            bsInput.volatilityDecimal.decimalToPreciseDecimal(),
            spotPrecise,
            bsInput.strikePriceDecimal.decimalToPreciseDecimal(),
            bsInput.rateDecimal.decimalToPreciseDecimal()
        );
        (uint callPrice, uint putPrice) = _optionPrices(
            tAnnualised,
            spotPrecise,
            bsInput.strikePriceDecimal.decimalToPreciseDecimal(),
            bsInput.rateDecimal.decimalToPreciseDecimal(),
            d1,
            d2
        );
        (uint vegaPrecise, uint stdVegaPrecise) = _standardVega(d1, spotPrecise, bsInput.timeToExpirySec);
        (int callDelta, int putDelta) = _delta(d1);
        
        return
        PricesDeltaStdVega(
            callPrice.preciseDecimalToDecimal(),
            putPrice.preciseDecimalToDecimal(),
            callDelta.preciseDecimalToDecimal(),
            putDelta.preciseDecimalToDecimal(),
            vegaPrecise.preciseDecimalToDecimal(),
            stdVegaPrecise.preciseDecimalToDecimal()
        );
    }
    
    /**
    * @dev Returns call delta given parameters.
    */
    
    function delta(BlackScholesInputs memory bsInput) public pure returns (int callDeltaDecimal, int putDeltaDecimal) {
        uint tAnnualised = _annualise(bsInput.timeToExpirySec);
        uint spotPrecise = bsInput.spotDecimal.decimalToPreciseDecimal();
        
        (int d1, ) = _d1d2(
            tAnnualised,
            bsInput.volatilityDecimal.decimalToPreciseDecimal(),
            spotPrecise,
            bsInput.strikePriceDecimal.decimalToPreciseDecimal(),
            bsInput.rateDecimal.decimalToPreciseDecimal()
        );
        
        (int callDelta, int putDelta) = _delta(d1);
        return (callDelta.preciseDecimalToDecimal(), putDelta.preciseDecimalToDecimal());
    }
    
    /**
    * @dev Returns non-normalized vega given parameters. Quoted in cents.
    */
    function vega(BlackScholesInputs memory bsInput) public pure returns (uint vegaDecimal) {
        uint tAnnualised = _annualise(bsInput.timeToExpirySec);
        uint spotPrecise = bsInput.spotDecimal.decimalToPreciseDecimal();
        
        (int d1, ) = _d1d2(
            tAnnualised,
            bsInput.volatilityDecimal.decimalToPreciseDecimal(),
            spotPrecise,
            bsInput.strikePriceDecimal.decimalToPreciseDecimal(),
            bsInput.rateDecimal.decimalToPreciseDecimal()
        );
        return _vega(tAnnualised, spotPrecise, d1).preciseDecimalToDecimal();
    }
    
    //////////////////////
    // Computing Greeks //
    //////////////////////
    
    /**
    * @dev Returns internal coefficients of the Black-Scholes call price formula, d1 and d2.
    * @param tAnnualised Number of years to expiry
    * @param volatility Implied volatility over the period til expiry as a percentage
    * @param spot The current price of the base asset
    * @param strikePrice The strikePrice price of the option
    * @param rate The percentage risk free rate + carry cost
    */
    function _d1d2(
        uint tAnnualised,
        uint volatility,
        uint spot,
        uint strikePrice,
        int rate
    ) internal pure returns (int d1, int d2) {
        // Set minimum values for tAnnualised and volatility to not break computation in extreme scenarios
        // These values will result in option prices reflecting only the difference in stock/strikePrice, which is expected.
        // This should be caught before calling this function, however the function shouldn't break if the values are 0.
        tAnnualised = tAnnualised < MIN_T_ANNUALISED ? MIN_T_ANNUALISED : tAnnualised;
        volatility = volatility < MIN_VOLATILITY ? MIN_VOLATILITY : volatility;
        
        int vtSqrt = int(volatility.multiplyDecimalRoundPrecise(_sqrtPrecise(tAnnualised)));
        int log = HigherMath.lnPrecise(int(spot.divideDecimalRoundPrecise(strikePrice)));
        int v2t = (int(volatility.multiplyDecimalRoundPrecise(volatility) / 2) + rate).multiplyDecimalRoundPrecise(
            int(tAnnualised)
        );
        d1 = (log + v2t).divideDecimalRoundPrecise(vtSqrt);
        d2 = d1 - vtSqrt;
    }
    
    /**
    * @dev Internal coefficients of the Black-Scholes call price formula.
    * @param tAnnualised Number of years to expiry
    * @param spot The current price of the base asset
    * @param strikePrice The strikePrice price of the option
    * @param rate The percentage risk free rate + carry cost
    * @param d1 Internal coefficient of Black-Scholes
    * @param d2 Internal coefficient of Black-Scholes
    */
    function _optionPrices(
        uint tAnnualised,
        uint spot,
        uint strikePrice,
        int rate,
        int d1,
        int d2
    ) internal pure returns (uint call, uint put) {
        uint strikePricePV = strikePrice.multiplyDecimalRoundPrecise(
            HigherMath.expPrecise(int(-rate.multiplyDecimalRoundPrecise(int(tAnnualised))))
        );
        uint spotNd1 = spot.multiplyDecimalRoundPrecise(_stdNormalCDF(d1));
        uint strikePriceNd2 = strikePricePV.multiplyDecimalRoundPrecise(_stdNormalCDF(d2));
        
        // We clamp to zero if the minuend is less than the subtrahend
        // In some scenarios it may be better to compute put price instead and derive call from it depending on which way
        // around is more precise.
        call = strikePriceNd2 <= spotNd1 ? spotNd1 - strikePriceNd2 : 0;
        put = call + strikePricePV;
        put = spot <= put ? put - spot : 0;
    }
    
    /*
    * Greeks
    */
    
    /**
    * @dev Returns the option's delta value
    * @param d1 Internal coefficient of Black-Scholes
    */
    function _delta(int d1) internal pure returns (int callDelta, int putDelta) {
        callDelta = int(_stdNormalCDF(d1));
        putDelta = callDelta - int(PRECISE_UNIT);
    }
    
    /**
    * @dev Returns the option's vega value based on d1. Quoted in cents.
    *
    * @param d1 Internal coefficient of Black-Scholes
    * @param tAnnualised Number of years to expiry
    * @param spot The current price of the base asset
    */
    function _vega(
        uint tAnnualised,
        uint spot,
        int d1
    ) internal pure returns (uint) {
        return _sqrtPrecise(tAnnualised).multiplyDecimalRoundPrecise(_stdNormal(d1).multiplyDecimalRoundPrecise(spot));
    }
    
    /**
    * @dev Returns the option's vega value with expiry modified to be at least VEGA_STANDARDISATION_MIN_DAYS
    * @param d1 Internal coefficient of Black-Scholes
    * @param spot The current price of the base asset
    * @param timeToExpirySec Number of seconds to expiry
    */
    function _standardVega(
        int d1,
        uint spot,
        uint timeToExpirySec
    ) internal pure returns (uint, uint) {
        uint tAnnualised = _annualise(timeToExpirySec);
        uint normalisationFactor = _getVegaNormalisationFactorPrecise(timeToExpirySec);
        uint vegaPrecise = _vega(tAnnualised, spot, d1);
        return (vegaPrecise, vegaPrecise.multiplyDecimalRoundPrecise(normalisationFactor));
    }
    
    function _getVegaNormalisationFactorPrecise(uint timeToExpirySec) internal pure returns (uint) {
        timeToExpirySec = timeToExpirySec < VEGA_STANDARDISATION_MIN_DAYS ? VEGA_STANDARDISATION_MIN_DAYS : timeToExpirySec;
        uint daysToExpiry = timeToExpirySec / 1 days;
        uint thirty = 30 * PRECISE_UNIT;
        return _sqrtPrecise(thirty / daysToExpiry) / 100;
    }
    
    /////////////////////
    // Math Operations //
    /////////////////////
    
    /**
    * @dev Compute the absolute value of `val`.
    *
    * @param val The number to absolute value.
    */
    function _abs(int val) internal pure returns (uint) {
        return uint(val < 0 ? -val : val);
    }
    
    /// @notice Calculates the square root of x, rounding down (borrowed from https://github.com/paulrberg/prb-math)
    /// @dev Uses the Babylonian method https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
    /// @param x The uint256 number for which to calculate the square root.
    /// @return result The result as an uint256.
    function _sqrt(uint x) internal pure returns (uint result) {
        if (x == 0) {
            return 0;
        }
        
        // Calculate the square root of the perfect square of a power of two that is the closest to x.
        uint xAux = uint(x);
        result = 1;
        if (xAux >= 0x100000000000000000000000000000000) {
            xAux >>= 128;
            result <<= 64;
        }
        if (xAux >= 0x10000000000000000) {
            xAux >>= 64;
            result <<= 32;
        }
        if (xAux >= 0x100000000) {
            xAux >>= 32;
            result <<= 16;
        }
        if (xAux >= 0x10000) {
            xAux >>= 16;
            result <<= 8;
        }
        if (xAux >= 0x100) {
            xAux >>= 8;
            result <<= 4;
        }
        if (xAux >= 0x10) {
            xAux >>= 4;
            result <<= 2;
        }
        if (xAux >= 0x8) {
            result <<= 1;
        }
        
        // The operations can never overflow because the result is max 2^127 when it enters this block.
        unchecked {
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1; // Seven iterations should be enough
            uint roundedDownResult = x / result;
            return result >= roundedDownResult ? roundedDownResult : result;
        }
    }
    
    /**
    * @dev Returns the square root of the value using Newton's method.
    */
    function _sqrtPrecise(uint x) internal pure returns (uint) {
        // Add in an extra unit factor for the square root to gobble;
        // otherwise, sqrt(x * UNIT) = sqrt(x) * sqrt(UNIT)
        return _sqrt(x * PRECISE_UNIT);
    }
    
    /**
    * @dev The standard normal distribution of the value.
    */
    function _stdNormal(int x) internal pure returns (uint) {
        return
        HigherMath.expPrecise(int(-x.multiplyDecimalRoundPrecise(x / 2))).divideDecimalRoundPrecise(SQRT_TWOPI);
    }
    
    /**
    * @dev The standard normal cumulative distribution of the value.
    * borrowed from a C++ implementation https://stackoverflow.com/a/23119456
    */
    function _stdNormalCDF(int x) public pure returns (uint) {
        uint z = _abs(x);
        int c;
        
        if (z <= 37 * PRECISE_UNIT) {
            uint e = HigherMath.expPrecise(-int(z.multiplyDecimalRoundPrecise(z / 2)));
            if (z < SPLIT) {
                c = int(
                    (_stdNormalCDFNumerator(z).divideDecimalRoundPrecise(_stdNormalCDFDenom(z)).multiplyDecimalRoundPrecise(e))
                );
            } else {
                uint f = (z +
                    PRECISE_UNIT.divideDecimalRoundPrecise(
                        z +
                        (2 * PRECISE_UNIT).divideDecimalRoundPrecise(
                            z +
                            (3 * PRECISE_UNIT).divideDecimalRoundPrecise(
                                z + (4 * PRECISE_UNIT).divideDecimalRoundPrecise(z + ((PRECISE_UNIT * 13) / 20))
                            )
                        )
                    ));
                    c = int(e.divideDecimalRoundPrecise(f.multiplyDecimalRoundPrecise(SQRT_TWOPI)));
                }
            }
        return uint((x <= 0 ? c : (int(PRECISE_UNIT) - c)));
    }
        
    /**
    * @dev Helper for _stdNormalCDF
    */
    function _stdNormalCDFNumerator(uint z) internal pure returns (uint) {
        uint numeratorInner = ((((((N6 * z) / PRECISE_UNIT + N5) * z) / PRECISE_UNIT + N4) * z) / PRECISE_UNIT + N3);
        return (((((numeratorInner * z) / PRECISE_UNIT + N2) * z) / PRECISE_UNIT + N1) * z) / PRECISE_UNIT + N0;
    }
    
    /**
    * @dev Helper for _stdNormalCDF
    */
    function _stdNormalCDFDenom(uint z) internal pure returns (uint) {
        uint denominatorInner = ((((((M7 * z) / PRECISE_UNIT + M6) * z) / PRECISE_UNIT + M5) * z) / PRECISE_UNIT + M4);
        return
        (((((((denominatorInner * z) / PRECISE_UNIT + M3) * z) / PRECISE_UNIT + M2) * z) / PRECISE_UNIT + M1) * z) /
        PRECISE_UNIT +
        M0;
    }
    
    /**
    * @dev Converts an integer number of seconds to a fractional number of years.
    */
    function _annualise(uint secs) internal pure returns (uint yearFraction) {
        return secs.divideDecimalRoundPrecise(SECONDS_PER_YEAR);
    }
}


// File contracts/LyraResolver.sol

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IOptionMarket {
    struct Strike {
        // strike listing identifier
        uint id;
        // strike price
        uint strikePrice;
        // volatility component specific to the strike listing (boardIv * skew = vol of strike)
        uint skew;
        // total user long call exposure
        uint longCall;
        // total user short call (base collateral) exposure
        uint shortCallBase;
        // total user short call (quote collateral) exposure
        uint shortCallQuote;
        // total user long put exposure
        uint longPut;
        // total user short put (quote collateral) exposure
        uint shortPut;
        // id of board to which strike belongs
        uint boardId;
    }

    struct OptionBoard {
        // board identifier
        uint id;
        // expiry of all strikes belonging to board
        uint expiry;
        // volatility component specific to board (boardIv * skew = vol of strike)
        uint iv;
        // admin settable flag blocking all trading on this board
        bool frozen;
        // list of all strikes belonging to this board
        uint[] strikeIds;
    }

    function getBoardAndStrikeDetails(uint boardId) external view returns (OptionBoard memory, Strike[] memory, uint256[] memory, uint256);
    function getStrikeAndBoard(uint strikeId) external view returns (Strike memory, OptionBoard memory);
    function getLiveBoards() external view returns (uint256[] memory);
}

interface IExchangeRates {
    function rateAndInvalid(bytes32 currencyKey) external view returns (uint rate, bool isInvalid);
}

interface IOptionGreeksCache {
    struct GreekCacheParameters {
        // Cap the number of strikes per board to avoid hitting gasLimit constraints
        uint maxStrikesPerBoard;
        // How much spot price can move since last update before deposits/withdrawals are blocked
        uint acceptableSpotPricePercentMove;
        // How much time has passed since last update before deposits/withdrawals are blocked
        uint staleUpdateDuration;
        // Length of the GWAV for the baseline volatility used to fire the vol circuit breaker
        uint varianceIvGWAVPeriod;
        // Length of the GWAV for the skew ratios used to fire the vol circuit breaker
        uint varianceSkewGWAVPeriod;
        // Length of the GWAV for the baseline used to determine the NAV of the pool
        uint optionValueIvGWAVPeriod;
        // Length of the GWAV for the skews used to determine the NAV of the pool
        uint optionValueSkewGWAVPeriod;
        // Minimum skew that will be fed into the GWAV calculation
        // Prevents near 0 values being used to heavily manipulate the GWAV
        uint gwavSkewFloor;
        // Maximum skew that will be fed into the GWAV calculation
        uint gwavSkewCap;
        // Interest/risk free rate
        int rateAndCarry;
    }

    function getGreekCacheParams() external view returns (GreekCacheParameters memory);
}

contract PolynomialLyraResolver {
    using FixedPointMathLib for uint256;

    IOptionMarket public immutable optionMarket;
    IExchangeRates public immutable exchangeRates;
    IOptionGreeksCache public immutable greeks;

    struct MinimalStrike {
        uint256 strikeId;
        uint256 expiry;
        uint256 strikePrice;
    }

    struct StrikeWithDelta {
        uint256 strikeId;
        uint256 expiry;
        uint256 strikePrice;
        int256 callDelta;
        int256 putDelta;
    }

    constructor(
        IOptionMarket market,
        IExchangeRates rates,
        IOptionGreeksCache greek
    ) {
        optionMarket = market;
        exchangeRates = rates;
        greeks = greek;
    }

    function getPremium(uint256 strikeId) public view returns (uint256 callPremium, uint256 putPremium, uint256 underlyingPrice) {
        (
            IOptionMarket.Strike memory strike,
            IOptionMarket.OptionBoard memory board
        ) = optionMarket.getStrikeAndBoard(strikeId);

        (uint256 spotPrice, bool isInvalid) = exchangeRates.rateAndInvalid("sETH");

        if (spotPrice == 0 || isInvalid) {
            revert();
        }

        BlackScholesLib.BlackScholesInputs memory bsInput = BlackScholesLib.BlackScholesInputs({
            timeToExpirySec: board.expiry - block.timestamp,
            volatilityDecimal: board.iv.mulWadDown(strike.skew),
            spotDecimal: spotPrice,
            strikePriceDecimal: strike.strikePrice,
            rateDecimal: greeks.getGreekCacheParams().rateAndCarry
        });

        (callPremium, putPremium) = BlackScholesLib.optionPrices(bsInput);
        underlyingPrice = spotPrice;
    }

    function getDelta(uint256 strikeId) public view returns (int256 callDelta, int256 putDelta) {
        (
            IOptionMarket.Strike memory strike,
            IOptionMarket.OptionBoard memory board
        ) = optionMarket.getStrikeAndBoard(strikeId);

        (uint256 spotPrice, bool isInvalid) = exchangeRates.rateAndInvalid("sETH");

        if (spotPrice == 0 || isInvalid) {
            revert();
        }

        BlackScholesLib.BlackScholesInputs memory bsInput = BlackScholesLib.BlackScholesInputs({
            timeToExpirySec: board.expiry - block.timestamp,
            volatilityDecimal: board.iv.mulWadDown(strike.skew),
            spotDecimal: spotPrice,
            strikePriceDecimal: strike.strikePrice,
            rateDecimal: greeks.getGreekCacheParams().rateAndCarry
        });

        (callDelta, putDelta) = BlackScholesLib.delta(bsInput);
    }

    function getDeltaWithSpotPrice(uint256 spotPrice, uint256 strikeId) public view returns (int256 callDelta, int256 putDelta) {
        (
            IOptionMarket.Strike memory strike,
            IOptionMarket.OptionBoard memory board
        ) = optionMarket.getStrikeAndBoard(strikeId);

        BlackScholesLib.BlackScholesInputs memory bsInput = BlackScholesLib.BlackScholesInputs({
            timeToExpirySec: board.expiry - block.timestamp,
            volatilityDecimal: board.iv.mulWadDown(strike.skew),
            spotDecimal: spotPrice,
            strikePriceDecimal: strike.strikePrice,
            rateDecimal: greeks.getGreekCacheParams().rateAndCarry
        });

        (callDelta, putDelta) = BlackScholesLib.delta(bsInput);
    }

    function getDeltaWithInputs(uint256 spotPrice, IOptionMarket.OptionBoard memory board, IOptionMarket.Strike memory strike) public view returns (int256 callDelta, int256 putDelta) {
        BlackScholesLib.BlackScholesInputs memory bsInput = BlackScholesLib.BlackScholesInputs({
            timeToExpirySec: board.expiry - block.timestamp,
            volatilityDecimal: board.iv.mulWadDown(strike.skew),
            spotDecimal: spotPrice,
            strikePriceDecimal: strike.strikePrice,
            rateDecimal: greeks.getGreekCacheParams().rateAndCarry
        });

        (callDelta, putDelta) = BlackScholesLib.delta(bsInput);
    }

    function getDeltas(uint256[] memory strikeIds) public view returns (int256[] memory callDeltas, int256[] memory putDeltas) {
        callDeltas = new int256[](strikeIds.length);
        putDeltas = new int256[](strikeIds.length);

        (uint256 spotPrice, bool isInvalid) = exchangeRates.rateAndInvalid("sETH");

        if (spotPrice == 0 || isInvalid) {
            revert();
        }

        for (uint256 i = 0; i < strikeIds.length; i++) {
            (callDeltas[i], putDeltas[i]) = getDeltaWithSpotPrice(spotPrice, strikeIds[i]);
        }
    }

    function getLiveStrikes() public view returns (uint256 spotPrice, uint256 strikeCount, MinimalStrike[] memory strikes) {
        (spotPrice, ) = exchangeRates.rateAndInvalid("sETH");

        strikes = new MinimalStrike[](1000);

        uint256[] memory liveBoards = optionMarket.getLiveBoards();

        for (uint256 i = 0; i < liveBoards.length; i++) {
            (IOptionMarket.OptionBoard memory board, IOptionMarket.Strike[] memory boardStrikes, , ) = optionMarket.getBoardAndStrikeDetails(liveBoards[i]);
            for (uint256 j = 0; j < boardStrikes.length; j++) {
                strikes[strikeCount + j] = MinimalStrike({
                    strikeId: boardStrikes[j].id,
                    expiry: board.expiry,
                    strikePrice: boardStrikes[j].strikePrice
                });
            }

            strikeCount += boardStrikes.length;
        }
    }

    function getDetailedLiveStrikes() public view returns (uint256 spotPrice, uint256 strikeCount, StrikeWithDelta[] memory strikes) {
        (spotPrice, ) = exchangeRates.rateAndInvalid("sETH");

        strikes = new StrikeWithDelta[](1000);

        uint256[] memory liveBoards = optionMarket.getLiveBoards();

        for (uint256 i = 0; i < liveBoards.length; i++) {
            (IOptionMarket.OptionBoard memory board, IOptionMarket.Strike[] memory boardStrikes, , ) = optionMarket.getBoardAndStrikeDetails(liveBoards[i]);
            for (uint256 j = 0; j < boardStrikes.length; j++) {
                (int256 callDelta, int256 putDelta) = getDeltaWithInputs(spotPrice, board, boardStrikes[j]);
                strikes[strikeCount + j] = StrikeWithDelta({
                    strikeId: boardStrikes[j].id,
                    expiry: board.expiry,
                    strikePrice: boardStrikes[j].strikePrice,
                    callDelta: callDelta,
                    putDelta: putDelta
                });
            }

            strikeCount += boardStrikes.length;
        }
    }

    function getExpiries(uint256[] memory strikeIds) public view returns (uint256[] memory expiries) {
        expiries = new uint256[](strikeIds.length);

        for (uint256 i = 0; i < strikeIds.length; i++) {
            (, IOptionMarket.OptionBoard memory board) = optionMarket.getStrikeAndBoard(strikeIds[i]);
            expiries[i] = board.expiry;
        }
    }
}