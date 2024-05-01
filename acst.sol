// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;
import  "./Ownable2Step.sol";
import "./IERC20.sol";
contract ACST is IERC20, Ownable2Step {
    string public name = "American Cannabis Society";
    string public symbol = "ACST";
    uint256 public taxCollected = 6;
    // address public taxReceiver = 0x1133Dd030dE07E43Db3b1060FBe66Ec574fE074D;
    address public immutable taxReceiver;
    event TaxCollected(address indexed taxReceiver, uint256 amount);

    uint256 public totalSupply = 100_000_000_000 * 1e18;
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;
    
    constructor(address _taxReceiver) {
        require(_taxReceiver != address(0), "Invalid tax receiver address");
        taxReceiver = _taxReceiver;
        balances[msg.sender] = totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
    return balances[account];
}
    function setNewTax(uint8 newTax) external onlyOwner returns (uint256) {
        require(newTax < 100, "Tax percentage cannot exceed 100");
        require(newTax >= 0, "Tax percentage cannot be negative");
        taxCollected = newTax;
        return taxCollected;
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "ERC20: transfer to the zero address");
        uint256 senderBalance = balances[from];
        require(senderBalance >= amount, "ERC20: insufficient balance");

        balances[from] -= amount;
        balances[to] += amount;
        emit Transfer(from, to, amount);
    }
    function allowance(
        address owner,
        address spender
    ) external view override returns (uint256) {
        return allowances[owner][spender];
    }
    function approve(
        address spender,
        uint256 amount
    ) external override returns (bool) {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        _transferFrom(from, to, amount);
        return true;
    }

    function _transferFrom(address from, address to, uint256 amount) internal {
        require(to != address(0), "ERC20: transfer to the zero address");
        uint256 senderAllowance = allowances[from][msg.sender];
        require(senderAllowance >= amount, "ERC20: transfer amount exceeds allowance");

        uint256 fee = (amount / 100) * taxCollected;
        uint256 amountAfterFee = amount - fee;

        balances[from] -= amount;
        balances[to] += amountAfterFee;
        balances[taxReceiver] += fee;

        allowances[from][msg.sender] -= amount;
        emit Transfer(from, to, amountAfterFee);
        emit Transfer(from, taxReceiver, fee);
        emit TaxCollected(taxReceiver, fee); // Emitting a specific event for tax collection
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) external returns (bool) {
        uint256 newAllowance = allowances[msg.sender][spender] + addedValue;
        _approve(msg.sender, spender, newAllowance);
        return true;
    }
    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) external returns (bool) {
        uint256 currentAllowance = allowances[msg.sender][spender];
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        uint256 newAllowance = currentAllowance - subtractedValue;
        _approve(msg.sender, spender, newAllowance);
        return true;
    }
    
    function _approve(address owner, address spender, uint256 amount) internal {
        allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}
