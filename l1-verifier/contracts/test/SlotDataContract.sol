// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract SlotDataContract {
    uint256 latest = 49;                                // Slot 0
    string name;                                        // Slot 1
    mapping(uint256=>uint256) highscores;               // Slot 2
    mapping(uint256=>string) highscorers;               // Slot 3
    mapping(string=>string) realnames;                  // Slot 4
    uint256 zero;                                       // Slot 5
    bytes pointlessBytes;                               // Slot 6
    bytes paddedAddress;                                // Slot 7
    mapping(address=>string) addressIdentifiers;        // Slot 8
    string iam = "tomiscool";                           // Slot 9
    mapping(string=>string) stringStrings;              // Slot 10
    address anotherAddress;                             // Slot 11

    constructor(address _anotherAddress) {

        //latest = 42;
        name = "Satoshi";
        highscores[0] = 1;
        highscores[latest] = 12345;
        highscorers[latest] = "Hal Finney";
        highscorers[1] = "Hubert Blaine Wolfeschlegelsteinhausenbergerdorff Sr.";
        realnames["Money Skeleton"] = "Vitalik Buterin";
        realnames["Satoshi"] = "Hal Finney";
        pointlessBytes = abi.encodePacked(uint8(0),uint8(0),uint8(49));
        paddedAddress = abi.encodePacked(hex"00000000000000008e674B194c868ea762E488a835695608cC170A6c");
        addressIdentifiers[address(0x8e674B194c868ea762E488a835695608cC170A6c)] = "tom";
        stringStrings["tom"] = "clowes";
        anotherAddress = _anotherAddress;

        //tom => 0x746f6d
        //tomiscool => 0x746f6d6973636f6f6c
    }
}