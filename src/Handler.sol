// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20 } from "solady/tokens/ERC20.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";


contract Handler {
  using FixedPointMathLib for *;

  error Expired(uint256 _deadline);

  function doTransfer(
    address _token,
    address _from,
    address _to,
    uint256 _value,
    uint256 _deadline,
    uint256 _priorityFee,
    uint256 _maxFeePerGas,
    uint256 _baseFeeRate,
    uint256 _gas,
    bytes32 _r,
    bytes32 _s,
    uint8 _v
  ) external {
    unchecked {
      if (block.timestamp > _deadline) {
        revert Expired(_deadline);
      }

      bytes32 ophash = keccak256(
        abi.encodePacked(
          _token,
          _from,
          _to,
          _value,
          _deadline,
          _maxFeePerGas,
          _priorityFee,
          _baseFeeRate,
          _gas
        )
      );

      // Compute how much we will need to pay in fees.
      // Notice that all units are in ERC20 except block.basefee
      uint256 blockBaseFee = block.basefee.rawMulWad(_baseFeeRate);
      uint256 feePerGas = _maxFeePerGas.min(blockBaseFee + _priorityFee);
      uint256 fee = feePerGas * _gas;
      uint256 maxFee = _maxFeePerGas * _gas;

      // Re-use the inner deadline for the permit
      // this way we only need ONE signature
      ERC20(_token).permit(
        _from,
        address(this),
        _value + maxFee,
        uint256(ophash),
        _v,
        _r,
        _s
      );

      // Send the main transfer
      SafeTransferLib.safeTransferFrom(
        _token,
        _from,
        _to,
        _value
      );

      // Pay the fee
      SafeTransferLib.safeTransferFrom(
        _token,
        _from,
        tx.origin,
        fee
      );
    }
  }
}
