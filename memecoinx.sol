// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
}


interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

contract MEMECOINX is Context, IERC20, Ownable2Step {
    using SafeMath for uint256;

    string private name = "MEMECOINX";
    string private symbol = "MCX";
    uint8 private  _decimals = 18;
    uint256 public _totalSupply = 1000000000 * 10**uint256(_decimals);

    uint256 private _taxFeeBrand = 5; // 5% tax fee
    uint256 private _taxFeeAdvertising = 1; // 1% tax fee
    uint256 private _taxFeeLP = 1; // 1% tax fee   

    uint256 private _totalTaxFee = _taxFeeBrand.add(_taxFeeAdvertising).add(_taxFeeLP); 

    bool public maxBuyLimitEnabled = true; // Flag to enable/disable max buy limit

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event TaxFeesUpdated(uint256 brandTaxFee, uint256 advertisingTaxFee, uint256 LPTaxFee);
    event MaxBuyLimitEnabled(bool enabled);

    constructor() Ownable(msg.sender){
    _balances[msg.sender] = _totalSupply;
    // uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    // uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
    // _balances[_msgSender()] = _totalSupply;
    emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        // Check if the max buy limit is enabled and enforce the limit if applicable
        if (maxBuyLimitEnabled && recipient != owner() && sender == uniswapV2Pair) {
            uint256 maxBuyLimit = _totalSupply.mul(2).div(100); // 2% of the total supply
            require(_balances[recipient].add(amount) <= maxBuyLimit, "ERC20: exceeding max buy limit");
        }

        uint256 taxAmount = 0;
        uint256 transferAmount = amount;

        // Check if the sender is not the owner, then apply tax
        if (sender != owner()) {
            taxAmount = amount.mul(_totalTaxFee).div(100);
            transferAmount = amount.sub(taxAmount);
        }

        // Transfer tokens excluding tax to the recipient
        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(transferAmount);
        emit Transfer(sender, recipient, transferAmount);

        if (taxAmount > 0) {
            _balances[owner()] = _balances[owner()].add(taxAmount);
            emit Transfer(sender, owner(), taxAmount);
        }
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function disableMaxBuyLimit() public onlyOwner {
        maxBuyLimitEnabled = false;
        emit MaxBuyLimitEnabled(false);
    }
}

