// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library TokensHelper {
    enum TransferErrors {
        TransferFailed,
        TransferFromFailed,
        TransferNativeFailed
    }

    error ApproveFailed();
    error TransferFailed(TransferErrors);
    error TokenMintingFailed();

    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes("approve(address,uint256)")));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        if (!(success && (data.length == 0 || abi.decode(data, (bool))))) revert ApproveFailed();
    }

    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes("transfer(address,uint256)")));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        if (!(success && (data.length == 0 || abi.decode(data, (bool)))))
            revert TransferFailed(TransferErrors.TransferFailed);
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes("transferFrom(address,address,uint256)")));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        if (!(success && (data.length == 0 || abi.decode(data, (bool)))))
            revert TransferFailed(TransferErrors.TransferFromFailed);
    }

    function safeTransferNativeTokens(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        if (!success) revert TransferFailed(TransferErrors.TransferNativeFailed);
    }

    function safeMint(
        address token,
        address to,
        uint256 amount
    ) internal {
        // bytes4(keccak256(bytes("mint(address,uint256)")));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x40c10f19, to, amount));
        if (!(success && (data.length == 0 || abi.decode(data, (bool))))) revert TokenMintingFailed();
    }

    function safeBurn(
        address token,
        address from,
        uint256 amount
    ) internal {
        // bytes4(keccak256(bytes("burn(address,uint256)")));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x9dc29fac, from, amount));
        if (!(success && (data.length == 0 || abi.decode(data, (bool))))) revert TokenMintingFailed();
    }
}
