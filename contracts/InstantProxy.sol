// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

/**

  ___ _   _ ____ _____  _    _   _ _____   ____  ____   _____  ____   __
 |_ _| \ | / ___|_   _|/ \  | \ | |_   _| |  _ \|  _ \ / _ \ \/ /\ \ / /
  | ||  \| \___ \ | | / _ \ |  \| | | |   | |_) | |_) | | | \  /  \ V / 
  | || |\  |___) || |/ ___ \| |\  | | |   |  __/|  _ <| |_| /  \   | |  
 |___|_| \_|____/ |_/_/   \_\_| \_| |_|   |_|   |_| \_\\___/_/\_\  |_|  


*/

import '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol';
import 'rubic-bridge-base/contracts/errors/Errors.sol';
import 'rubic-bridge-base/contracts/BridgeBase.sol';

error DexNotAvailable();
error FeesEnabled();
error DifferentAmountSpent();

/**
    @title InstantProxy
    @author Vladislav Yaroshuk
    @notice Universal proxy dex aggregator contract by Rubic exchange
 */
contract InstantProxy is BridgeBase {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bool public feesEnabled;

    modifier onlyWithoutFees() {
        checkFees();
        _;
    }

    /**
     * @notice Used in modifier
     * @dev Function to check if the fees are enabled
     */
    function checkFees() internal view {
        if (fixedCryptoFee > 0) {
            revert FeesEnabled();
        }
    }

    event DexSwap(address dex, address receiver, address inputToken, uint256 inputAmount, address outputToken);

    function initialize(
        address[] memory _routers,
        address[] memory _tokens,
        uint256[] memory _minTokenAmounts,
        uint256[] memory _maxTokenAmounts
    ) internal initializer {
        __BridgeBaseInit(0, 0, _routers, _tokens, _minTokenAmounts, _maxTokenAmounts);
    }

    function dexCall(
        address _dex,
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        bytes calldata _data
    ) external payable nonReentrant whenNotPaused onlyWithoutFees {
        if (!availableRouters.contains(_dex)) {
            revert DexNotAvailable();
        }
        if (_tokenIn != address(0) && msg.value == 0) {
            uint256 balanceBeforeTransfer = IERC20Upgradeable(_tokenIn).balanceOf(address(this));
            IERC20Upgradeable(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountIn);
            SafeERC20Upgradeable.safeIncreaseAllowance(
                IERC20Upgradeable(_tokenIn),
                _dex,
                IERC20Upgradeable(_tokenIn).balanceOf(address(this)) - balanceBeforeTransfer
            );
        }

        uint256 balanceBeforeSwap;
        _tokenOut == address(0)
            ? balanceBeforeSwap = address(this).balance
            : IERC20Upgradeable(_tokenOut).balanceOf(address(this));

        // perform swap directly to user
        AddressUpgradeable.functionCallWithValue(_dex, _data, msg.value);

        uint256 balanceAfterSwap;
        _tokenOut == address(0)
            ? balanceBeforeSwap = address(this).balance
            : IERC20Upgradeable(_tokenOut).balanceOf(address(this));

        if (balanceAfterSwap != balanceBeforeSwap) {
            sendToken(_tokenOut, balanceAfterSwap - balanceBeforeSwap, msg.sender);
        }

        // reset allowance back to zero, just in case
        if (IERC20Upgradeable(_tokenIn).allowance(address(this), _dex) > 0) {
            IERC20Upgradeable(_tokenIn).safeApprove(_dex, 0);
        }

        emit DexSwap(_dex, msg.sender, _tokenIn, _amountIn, _tokenOut);
    }

    function dexCallWithFee(
        address _dex,
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        address _integrator,
        bytes calldata _data
    ) external payable nonReentrant whenNotPaused {
        if (!availableRouters.contains(_dex)) {
            revert DexNotAvailable();
        }
        IntegratorFeeInfo memory _info = integratorToFeeInfo[_integrator];

        uint256 balanceAfterTransfer;
        if (_tokenIn != address(0)) {
            uint256 balanceBeforeTransfer = IERC20Upgradeable(_tokenIn).balanceOf(address(this));
            IERC20Upgradeable(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountIn);
            balanceAfterTransfer = IERC20Upgradeable(_tokenIn).balanceOf(address(this));

            _amountIn = accrueTokenFees(
                _integrator,
                _info,
                balanceAfterTransfer - balanceBeforeTransfer,
                0,
                _integrator
            );
            
            SafeERC20Upgradeable.safeIncreaseAllowance(
                IERC20Upgradeable(_tokenIn),
                _dex,
                _amountIn
            );
        }

        uint256 balanceBeforeSwap;
        _tokenOut == address(0)
            ? balanceBeforeSwap = address(this).balance
            : IERC20Upgradeable(_tokenOut).balanceOf(address(this));

        // perform swap directly to user
        AddressUpgradeable.functionCallWithValue(_dex, _data, accrueFixedCryptoFee(_integrator, _info));

        if (_tokenIn != address(0)) {
            if (balanceAfterTransfer - IERC20Upgradeable(_tokenIn).balanceOf(address(this)) != _amountIn) {
                revert DifferentAmountSpent();
            }
        }

        uint256 balanceAfterSwap;
        if (_tokenOut == address(0)) {
            balanceAfterSwap = address(this).balance;
        } else {
            balanceAfterSwap = IERC20Upgradeable(_tokenOut).balanceOf(address(this));
        }

        if (balanceAfterSwap != balanceBeforeSwap) {
            sendToken(_tokenOut, balanceAfterSwap - balanceBeforeSwap, msg.sender);
        }

        // reset allowance back to zero, just in case
        if (IERC20Upgradeable(_tokenIn).allowance(address(this), _dex) > 0) {
            IERC20Upgradeable(_tokenIn).safeApprove(_dex, 0);
        }

        emit DexSwap(_dex, msg.sender, _tokenIn, _amountIn, _tokenOut);
    }

    function sweepTokens(address _token, uint256 _amount) external onlyAdmin {
        sendToken(_token, _amount, msg.sender);
    }
}
