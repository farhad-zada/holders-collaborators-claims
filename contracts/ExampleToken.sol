// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ExampleToken is ERC20 {
    constructor() ERC20("ExampleToken", "EXT") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}
