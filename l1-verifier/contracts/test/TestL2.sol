// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract TestL2 {
    uint256 latest;                         // Slot 0
    string name;                            // Slot 1
    mapping(uint256=>uint256) highscores;   // Slot 2
    mapping(uint256=>string) highscorers;   // Slot 3
    mapping(string=>string) realnames;      // Slot 4
    uint256 zero;                           // Slot 5
    bytes pointlessBytes;                   // Slot 6
    bytes paddedAddress;                    // Slot 7
    mapping(address=>string) addressIdentifiers;      // Slot 8
    string iam = "tomiscool"; //Slot 9
    mapping(string=>string) stringStrings;      // Slot 10

    constructor() {
        latest = 42;
        name = "Satoshi";
        highscores[0] = 1;
        highscores[latest] = 12345;
        highscorers[latest] = "Hal Finney";
        highscorers[1] = "Hubert Blaine Wolfeschlegelsteinhausenbergerdorff Sr.";
        realnames["Money Skeleton"] = "Vitalik Buterin";
        realnames["Satoshi"] = "Hal Finney";
        pointlessBytes = abi.encodePacked(uint8(0),uint8(0),uint8(42));
        paddedAddress = abi.encodePacked(hex"00000000000000001234567890123456789012345678901234567890");
        addressIdentifiers[address(0x1234567890123456789012345678901234567890)] = "tom";
        stringStrings["tom"] = "clowes";

        //tom => 0x746f6d
        //tomiscool => 0x746f6d6973636f6f6c
    }
}