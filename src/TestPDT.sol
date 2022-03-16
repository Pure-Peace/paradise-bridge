// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestPDT is ERC20 {
    constructor() ERC20("TestPDT", "TPDT") {
        _mint(msg.sender, 10000000000000000000000000);
    }
}
