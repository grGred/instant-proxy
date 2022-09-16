// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

/**

  ___ _   _ ____ _____  _    _   _ _____   ____  ____   _____  ____   __
 |_ _| \ | / ___|_   _|/ \  | \ | |_   _| |  _ \|  _ \ / _ \ \/ /\ \ / /
  | ||  \| \___ \ | | / _ \ |  \| | | |   | |_) | |_) | | | \  /  \ V / 
  | || |\  |___) || |/ ___ \| |\  | | |   |  __/|  _ <| |_| /  \   | |  
 |___|_| \_|____/ |_/_/   \_\_| \_| |_|   |_|   |_| \_\\___/_/\_\  |_|  


*/

import '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import 'rubic-bridge-base/contracts/libraries/SmartApprove.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';

error DexNotAvailable();
error AmntReceivedSubAmntExpected(uint256 amountReceived, uint256 amountExpected);

/**
    @title InstantProxy
    @author Vladislav Yaroshuk
    @notice Universal proxy dex aggregator contract by Rubic exchange
 */
contract InsantProxy is OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // AddressSet of whitelisted addresses
    EnumerableSetUpgradeable.AddressSet internal availableDex;

    event DexSwap(address dex, address receiver, address inputToken, uint256 inputAmount, address outputToken);

    function initialize() external initializer {
        __Pausable_init();
        __Ownable_init();
        __ReentrancyGuard_init();
    }

    function dexCall(
        address _dex,
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        bytes calldata _data
    ) external payable nonReentrant whenNotPaused {
        if (!availableDex.contains(_dex)) {
            revert DexNotAvailable();
        }
        if (_tokenIn != address(0)){
            IERC20Upgradeable(_tokenIn).transferFrom(msg.sender, address(this), _amountIn); 
            SmartApprove.smartApprove(_tokenIn, _amountIn, _dex);
        }

        AddressUpgradeable.functionCallWithValue(_dex, _data, msg.value);

        emit DexSwap(_dex, msg.sender, _tokenIn, _amountIn, _tokenOut);
    }

    function dexCallWithReceiver(
        address _dex,
        address _receiver,
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        bytes calldata _data
    ) external payable nonReentrant whenNotPaused {
        if (!availableDex.contains(_dex)) {
            revert DexNotAvailable();
        }
        if (_tokenIn != address(0)){
            IERC20Upgradeable(_tokenIn).transferFrom(msg.sender, address(this), _amountIn); 
            SmartApprove.smartApprove(_tokenIn, _amountIn, _dex);
        }

        uint256 balanceBefore = IERC20Upgradeable(_tokenOut).balanceOf(address(this));

        AddressUpgradeable.functionCallWithValue(_dex, _data, msg.value);

        sendToken(_tokenOut, IERC20Upgradeable(_tokenOut).balanceOf(address(this)) - balanceBefore, _receiver);

        emit DexSwap(_dex, _receiver, _tokenIn, _amountIn, _tokenOut);
    }

    function simulateTransfer(address _tokenIn, uint256 _amountIn) external {
        uint256 balanceBefore = IERC20Upgradeable(_tokenIn).balanceOf(address(this));
        IERC20Upgradeable(_tokenIn).transferFrom(msg.sender, address(this), _amountIn);
        revert AmntReceivedSubAmntExpected(
            IERC20Upgradeable(_tokenIn).balanceOf(address(this)) - balanceBefore,
            _amountIn
        );
    }

    function simulateSwap(
        address _dex,
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        bytes calldata _data
    ) external payable {
        if (_tokenIn != address(0)){
            IERC20Upgradeable(_tokenIn).transferFrom(msg.sender, address(this), _amountIn); 
            SmartApprove.smartApprove(_tokenIn, _amountIn, _dex);
        }
        // execute swap
        AddressUpgradeable.functionCallWithValue(_dex, _data, msg.value);
        
        uint256 tokenAmntAfterSwap = IERC20Upgradeable(_tokenOut).balanceOf(address(this));
        uint256 balanceBefore = IERC20Upgradeable(_tokenOut).balanceOf(msg.sender);

        IERC20Upgradeable(_tokenOut).transfer(msg.sender, tokenAmntAfterSwap);
        revert AmntReceivedSubAmntExpected(
            IERC20Upgradeable(_tokenOut).balanceOf(msg.sender) - balanceBefore,
            balanceBefore
        );
    }

    function decreaseAllowance(address _token, uint256 _amount) external onlyOwner {
        // sendToken(_token, _amount, msg.sender);
    }

    function sweepTokens(address _token, uint256 _amount) external onlyOwner {
        sendToken(_token, _amount, msg.sender);
    }

    function pauseExecution() external onlyOwner {
        _pause();
    }

    function unpauseExecution() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Appends new available DEX
     * @param _dex DEX's address to add
     */
    function addAvailableDex(address _dex) external onlyOwner {
        if (_dex == address(0)) {
            revert ZeroAddress();
        }
        // Check that router exists is performed inside the library
        availableDex.add(_dex);
    }

    /**
     * @dev Removes existing available DEX
     * @param _dex DEX's address to remove
     */
    function removeAvailableDex(address _dex) external onlyOwner {
        // Check that router exists is performed inside the library
        availableDex.remove(_dex);
    }

    /**
     * @return Available dexes
     */
    function getAvailableDexes() external view returns (address[] memory) {
        return availableDex.values();
    }

    function sendToken(
        address _token,
        uint256 _amount,
        address _receiver
    ) internal {
        if (_token == address(0)) {
            AddressUpgradeable.sendValue(payable(_receiver), _amount);
        } else {
            IERC20Upgradeable(_token).safeTransfer(_receiver, _amount);
        }
    }

    /**
     * @dev Plain fallback function to receive native
     */
    receive() external payable {}

    /**
     * @dev Plain fallback function
     */
    fallback() external {}
}
