pragma solidity >=0.6.6;

library StringComparator {
    function compareStrings (string memory a, string memory b) public pure
       returns (bool) {
        return keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b)));
    }
}
