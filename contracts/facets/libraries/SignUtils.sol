// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

library SignUtils {
    function constructMessageHash(
        address _tokenAddress,
        uint256 _tokenID,
        uint256 _price,
        uint88 _deadline,
        address _buyer
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _tokenAddress,
                    _tokenID,
                    _price,
                    _deadline,
                    _buyer
                )
            );
    }

    function isValid(
        bytes32 messageHash,
        bytes memory signature,
        address signer
    ) internal pure returns (bool) {
        bytes32 signedMsgHash = getSignedMessageHash(messageHash);
        return recoverSigner(signedMsgHash, signature) == signer;
    }

    function getSignedMessageHash(
        bytes32 messageHash
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    messageHash
                )
            );
    }

    function recoverSigner(
        bytes32 signedMsgHash,
        bytes memory signature
    ) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);

        return ecrecover(signedMsgHash, v, r, s);
    }

    function splitSignature(
        bytes memory sig
    ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "Signature must be 65 bytes");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        } // implicitly return (r, s, v)
    }
}
