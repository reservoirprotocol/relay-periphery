pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";

contract ERC20Burnable is ERC20, Ownable {
    error ERC20BurnableTransferNotAllowed();

    constructor(
        string memory name,
        string memory symbol,
        address _owner
    ) ERC20(name, symbol) {
        _initializeOwner(_owner);
    }

    function burnFrom(address user, uint256 amount) public onlyOwner {
        _burn(user, amount);
    }

    function mint(address user, uint256 amount) public onlyOwner {
        _mint(user, amount);
    }

    function transfer(
        address /*to*/,
        uint256 /*value*/
    ) public pure override returns (bool) {
        revert ERC20BurnableTransferNotAllowed();
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override onlyOwner returns (bool) {
        super.transferFrom(from, to, value);

        return true;
    }
}
