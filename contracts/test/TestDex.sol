// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface ITestDEX {
    function swap(
        address _fromToken,
        uint256 _inputAmount,
        address _toToken
    ) external;

    function swapAmountOut(
        address _fromToken,
        uint256 _inputAmount,
        address _toToken,
        uint256 _amountOutMin
    ) external;
}

contract TestDEX is ITestDEX {
    uint256 public constant price = 2;

    function swap(
        address _fromToken,
        uint256 _inputAmount,
        address _toToken
    ) external override {
        IERC20(_fromToken).transferFrom(msg.sender, address(this), _inputAmount);
        IERC20(_toToken).transfer(msg.sender, _inputAmount * price);
    }

    function swapAmountOut(
        address _fromToken,
        uint256 _inputAmount,
        address _toToken,
        uint256 _amountOutMin
    ) external override {
        IERC20(_fromToken).transferFrom(msg.sender, address(this), _inputAmount);
        require(_inputAmount * price >= _amountOutMin, 'Too few received');
        IERC20(_toToken).transfer(msg.sender, _inputAmount * price);
    }

    bytes4 private constant FUNC_SELECTOR = bytes4(keccak256('swap(address,uint256,address)'));
    bytes4 private constant FUNC_SELECTOR_AMOUNT_OUT = bytes4(keccak256('swapAmountOut(address,uint256,address,uint256)'));

    function viewEncodeDexCall(
        address _inputToken,
        uint256 _inputAmount,
        uint256 _chainId
    ) external pure returns (bytes memory) {
        bytes memory data = abi.encodeWithSelector(FUNC_SELECTOR, _inputToken, _inputAmount, _chainId);
        return data;
    }

    function viewEncodeDexAmountOut(uint256 _inputAmount, uint256 _chainId) external pure returns (bytes memory) {
        bytes memory data = abi.encodeWithSelector(FUNC_SELECTOR_AMOUNT_OUT, _inputAmount, _chainId);
        return data;
    }
}
