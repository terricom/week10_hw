// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISimpleSwap } from "./interface/ISimpleSwap.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

contract SimpleSwap is ISimpleSwap, ERC20 {
    // Implement core logic here
    using SafeMath for uint;
    address token0;
    address token1;
    uint reserve0;
    uint reserve1;

    constructor(address _tokenA, address _tokenB) ERC20("Simple-Swap-Token", "SWT") {

        require(Address.isContract(_tokenA), "SimpleSwap: TOKENA_IS_NOT_CONTRACT");
        require(Address.isContract(_tokenB), "SimpleSwap: TOKENB_IS_NOT_CONTRACT");
        require(_tokenA != _tokenB, "SimpleSwap: TOKENA_TOKENB_IDENTICAL_ADDRESS");

        // sort tokens
        bool aSmaller = uint256(uint160(_tokenA)) < uint256(uint160(_tokenB));
        token0 = aSmaller ? _tokenA : _tokenB;
        token1 = aSmaller ? _tokenB : _tokenB;
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external override returns (uint256 amountOut) {

        require(amountIn != 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");
        require(tokenIn == token0 || tokenIn == token1, "SimpleSwap: INVALID_TOKEN_IN");
        require(tokenOut == token0 || tokenOut == token1, "SimpleSwap: INVALID_TOKEN_OUT");
        require(tokenIn != tokenOut, "SimpleSwap: IDENTICAL_ADDRESS");
        
        bool token0In = tokenIn == token0;
        uint reserveA = token0In ? reserve0 : reserve1;
        uint reserveB = token0In ? reserve1 : reserve0;
        
        // BOut = reserveB - ((reserveA * reserveB - 1) / (reserveA + AIn) + 1)
        amountOut = reserveB - ((reserveA * reserveB - 1) / (reserveA + amountIn) + 1);

        // tokenIn transferFrom taker to SimpleSwap
        ERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // tokenOut transfer to taker
        ERC20(tokenOut).transfer(msg.sender, amountOut);

        // update reserves
        if (token0In) {
            reserve0 += amountIn;
            reserve1 -= amountOut;
        } else {
            reserve0 -= amountOut;
            reserve1 += amountIn;
        }
        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    function addLiquidity(uint256 amountAIn, uint256 amountBIn)
        external override returns (uint256 amountA, uint256 amountB, uint256 liquidity) {

            require(amountAIn > 0 && amountBIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");

            uint totalSupply = totalSupply();
            if (totalSupply == 0) {
                liquidity = Math.sqrt(amountAIn.mul(amountBIn));
                amountA = amountAIn;
                amountB = amountBIn;
            } else {
                liquidity = Math.min(amountAIn.mul(totalSupply) / reserve0, amountBIn.mul(totalSupply) / reserve1);
                amountA = (liquidity * reserve0) / totalSupply;
                amountB = (liquidity * reserve1) / totalSupply;
            }

            // transfer tokens from taker to SimpleSwap
            ERC20(token0).transferFrom(msg.sender, address(this), amountA);
            ERC20(token1).transferFrom(msg.sender, address(this), amountB);

            // update reserves
            reserve0 += amountA;
            reserve1 += amountB;

            // mint liquidity
            _mint(msg.sender, liquidity);
            emit AddLiquidity(msg.sender, amountA, amountB, liquidity);
    }

    function removeLiquidity(uint256 liquidity) external override returns (uint256 amountA, uint256 amountB) {

        require(liquidity > 0, "SimpleSwap: INSUFFICIENT_LIQUIDITY_BURNED");

        uint totalSupply = totalSupply();
        amountA = liquidity.mul(reserve0) / totalSupply; // using balances ensures pro-rata distribution
        amountB = liquidity.mul(reserve1) / totalSupply; // using balances ensures pro-rata distribution

        // transfer tokens to taker
        ERC20(token0).transfer(msg.sender, amountA);
        ERC20(token1).transfer(msg.sender, amountB);

        // update reserves
        reserve0 -= amountA;
        reserve1 -= amountB;

        // burn liquidity
        _burn(msg.sender, liquidity);
        emit Transfer(address(this), address(0), liquidity);
    }

    function getReserves() external view override returns (uint256 reserveA, uint256 reserveB) {
        reserveA = reserve0;
        reserveB = reserve1;
    }

    function getTokenA() external view override returns (address tokenA) {
        return token0;
    }

    function getTokenB() external view override returns (address tokenB) {
        return token1;
    }
}
