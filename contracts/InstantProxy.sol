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
error NativeNotSupported();

/**
    @title InstantProxy
    @author Vladislav Yaroshuk
    @notice Universal proxy dex aggregator contract by Rubic exchange
 */
contract InstantProxy is BridgeBase {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using SafeERC20Upgradeable for IERC20Upgradeable;

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
        address _recipient,
        bytes calldata _data
    ) external nonReentrant whenNotPaused onlyWithoutFees {
        if (!availableRouters.contains(_dex)) {
            revert DexNotAvailable();
        }

        uint256 tokenInAfter;
        (_amountIn, tokenInAfter) = _checkAmountIn(_tokenIn, _amountIn);

        SafeERC20Upgradeable.safeIncreaseAllowance(IERC20Upgradeable(_tokenIn), _dex, _amountIn);

        (uint256 tokenOutBefore, uint256 tokenOutAfter) = _performCallAndChecks(_tokenOut, _dex, _data, 0);

        if (tokenInAfter - IERC20Upgradeable(_tokenIn).balanceOf(address(this)) != _amountIn) {
            revert DifferentAmountSpent();
        }

        // send tokens to user in case router doesn't support receiver address
        if (tokenOutBefore != tokenOutAfter) {
            sendToken(_tokenOut, tokenOutAfter - tokenOutBefore, _recipient);
        }

        // reset allowance back to zero, just in case
        if (IERC20Upgradeable(_tokenIn).allowance(address(this), _dex) > 0) {
            IERC20Upgradeable(_tokenIn).safeApprove(_dex, 0);
        }

        emit DexSwap(_dex, _recipient, _tokenIn, _amountIn, _tokenOut);
    }

    function dexCallNative(
        address _dex,
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        address _recipient,
        bytes calldata _data
    ) external payable nonReentrant whenNotPaused onlyWithoutFees {
        if (!availableRouters.contains(_dex)) {
            revert DexNotAvailable();
        }

        (uint256 tokenOutBefore, uint256 tokenOutAfter) = _performCallAndChecks(
            _tokenOut,
            _dex,
            _data,
            msg.value
        );

        // no need to check for different amount spent since we called router with all value
        
        // send tokens to user in case router doesn't support receiver address
        if (tokenOutAfter != tokenOutBefore) {
            sendToken(_tokenOut, tokenOutAfter - tokenOutBefore, _recipient);
        }

        emit DexSwap(_dex, _recipient, _tokenIn, _amountIn, _tokenOut);
    }

    function dexCallWithFee(
        address _dex,
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        address _recipient,
        address _integrator,
        bytes calldata _data
    ) external payable nonReentrant whenNotPaused {
        if (!availableRouters.contains(_dex)) {
            revert DexNotAvailable();
        }
        IntegratorFeeInfo memory _info = integratorToFeeInfo[_integrator];

        uint256 tokenInAfter;
        (_amountIn, tokenInAfter) = _checkAmountIn(_tokenIn, _amountIn);

        _amountIn = accrueTokenFees(_integrator, _info, _amountIn, 0, _integrator);

        // approve for received amountIn - fees
        SafeERC20Upgradeable.safeIncreaseAllowance(IERC20Upgradeable(_tokenIn), _dex, _amountIn);

        (uint256 tokenOutBefore, uint256 tokenOutAfter) = _performCallAndChecks(
            _tokenOut,
            _dex,
            _data,
            accrueFixedCryptoFee(_integrator, _info)
        );

        if (tokenInAfter - IERC20Upgradeable(_tokenIn).balanceOf(address(this)) != _amountIn) {
            revert DifferentAmountSpent();
        }

        if (tokenOutAfter != tokenOutBefore) {
            sendToken(_tokenOut, tokenOutAfter - tokenOutBefore, _recipient);
        }

        // reset allowance back to zero, just in case
        if (IERC20Upgradeable(_tokenIn).allowance(address(this), _dex) > 0) {
            IERC20Upgradeable(_tokenIn).safeApprove(_dex, 0);
        }

        emit DexSwap(_dex, _recipient, _tokenIn, _amountIn, _tokenOut);
    }

    function dexCallNativeWithFee(
        address _dex,
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        address _recipient,
        address _integrator,
        bytes calldata _data
    ) external payable nonReentrant whenNotPaused {
        if (!availableRouters.contains(_dex)) {
            revert DexNotAvailable();
        }
        IntegratorFeeInfo memory _info = integratorToFeeInfo[_integrator];

        (uint256 tokenOutBefore, uint256 tokenOutAfter) = _performCallAndChecks(
            _tokenOut,
            _dex,
            _data,
            accrueFixedCryptoFee(_integrator, _info)
        );

        // no need to check for different amount spent since we called router with all value

        // send tokens to user in case router doesn't support receiver address
        if (tokenOutAfter != tokenOutBefore) {
            sendToken(_tokenOut, tokenOutAfter - tokenOutBefore, _recipient);
        }

        emit DexSwap(_dex, _recipient, _tokenIn, _amountIn, _tokenOut);
    }

    function _checkAmountIn(address _tokenIn, uint256 _amountIn) internal returns (uint256, uint256) {
        uint256 balanceBeforeTransfer = IERC20Upgradeable(_tokenIn).balanceOf(address(this));
        IERC20Upgradeable(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountIn);
        uint256 balanceAfterTransfer = IERC20Upgradeable(_tokenIn).balanceOf(address(this));
        _amountIn = balanceAfterTransfer - balanceBeforeTransfer;
        return (_amountIn, balanceAfterTransfer);
    }

    function _performCallAndChecks(
        address _tokenOut,
        address _dex,
        bytes calldata _data,
        uint256 _value
    ) internal returns (uint256 balanceBeforeSwap, uint256 balanceAfterSwap) {
        _tokenOut == address(0)
            ? balanceBeforeSwap = address(this).balance
            : balanceBeforeSwap = IERC20Upgradeable(_tokenOut).balanceOf(address(this));

        AddressUpgradeable.functionCallWithValue(_dex, _data, _value);

        _tokenOut == address(0)
            ? balanceAfterSwap = address(this).balance
            : balanceAfterSwap = IERC20Upgradeable(_tokenOut).balanceOf(address(this));
    }

    function sweepTokens(address _token, uint256 _amount) external onlyAdmin {
        sendToken(_token, _amount, msg.sender);
    }
}
