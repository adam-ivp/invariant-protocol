// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

/// @title IVPToken
/// @notice Fixed supply. Earned by running proofs.
///         Burned by slashing and premium buybacks.
///         No governance. No upgrades. Immutable.
contract IVPToken {

    string public constant name     = "Invariant Protocol";
    string public constant symbol   = "IVP";
    uint8  public constant decimals = 18;

    uint256 public constant TOTAL_SUPPLY      = 1_000_000_000e18;
    uint256 public constant PROVER_ALLOCATION =   400_000_000e18;
    uint256 public constant TREASURY          =   200_000_000e18;
    uint256 public constant TEAM              =   200_000_000e18;
    uint256 public constant PARTNERS          =   150_000_000e18;
    uint256 public constant PUBLIC_SALE       =    50_000_000e18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public totalSupply;
    uint256 public totalBurned;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    constructor(address _provers, address _treasury, address _team, address _partners, address _sale) {
        _mint(_provers,  PROVER_ALLOCATION);
        _mint(_treasury, TREASURY);
        _mint(_team,     TEAM);
        _mint(_partners, PARTNERS);
        _mint(_sale,     PUBLIC_SALE);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        _transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function burn(uint256 amount) external {
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        totalBurned += amount;
        emit Transfer(msg.sender, address(0), amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        balanceOf[from] -= amount;
        balanceOf[to]   += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        balanceOf[to] += amount;
        totalSupply   += amount;
        emit Transfer(address(0), to, amount);
    }
}
