pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
    // ------------------------------------------ //
    // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
    // ------------------------------------------ //
    using SafeMath for uint256;
    uint256 public totalSupply;
    uint256 public decimals = 18;
    string public name = "Test token";
    string public symbol = "TEST";
    mapping(address => uint256) public balanceOf;

    // ------------------------------------------ //
    // ----- END: DO NOT EDIT THIS SECTION ------ //
    // ------------------------------------------ //
    mapping(address => uint256) private holderToIndex;
    mapping(address => mapping(address => uint256)) public allowances;
    address[] public holders;
    mapping(address => uint256) public withdrawableDividends;

    // IERC20

    function allowance(
        address owner,
        address spender
    ) external view override returns (uint256) {
        return allowances[owner][spender];
    }

    function transfer(
        address to,
        uint256 value
    ) external override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(
        address spender,
        uint256 value
    ) external override returns (bool) {
        allowances[msg.sender][spender] = value;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override returns (bool) {
        require(
            allowances[from][msg.sender] >= value,
            "ERC20: transfer amount exceeds allowance"
        );

        _transfer(from, to, value);
        allowances[from][msg.sender] = allowances[from][msg.sender].sub(value);

        return true;
    }

    // IMintableToken

    function mint() external payable override {
        require(msg.value > 0, "Must send some ether to mint tokens");

        if (balanceOf[msg.sender] == 0) {
            _addHolder(msg.sender);
        }
        balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
        totalSupply = totalSupply.add(msg.value);
    }

    function burn(address payable dest) external override {
        uint256 amount = balanceOf[msg.sender];
        require(amount > 0, "No tokens to burn");

        balanceOf[msg.sender] = 0;
        totalSupply = totalSupply.sub(amount);
        _removeHolder(msg.sender);

        // Refund ETH
        (bool success, ) = dest.call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    // IDividends

    function getNumTokenHolders() external view override returns (uint256) {
        return holders.length;
    }

    function getTokenHolder(
        uint256 index
    ) external view override returns (address) {
        require(index <= holders.length && index > 0, "Index out of bounds");
        return holders[index.sub(1)];
    }

    function recordDividend() external payable override {
        require(msg.value > 0, "Dividend must be > 0");
        require(totalSupply > 0, "No tokens to distribute to");

        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];
            uint256 balance = balanceOf[holder];

            if (balance > 0) {
                uint256 share = balance.mul(msg.value).div(totalSupply);
                withdrawableDividends[holder] = withdrawableDividends[holder]
                    .add(share);
            }
        }
    }

    function getWithdrawableDividend(
        address payee
    ) external view override returns (uint256) {
        return withdrawableDividends[payee];
    }

    function withdrawDividend(address payable dest) external override {
        uint256 amount = withdrawableDividends[msg.sender];
        require(amount > 0, "No dividend to withdraw");

        withdrawableDividends[msg.sender] = 0;

        (bool success, ) = dest.call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    function _addHolder(address user) internal {
        if (holderToIndex[user] == 0) {
            holders.push(user);
            holderToIndex[user] = holders.length;
        }
    }

    function _removeHolder(address user) internal {
        if (holderToIndex[user] != 0) {
            uint256 indexToRemove = holderToIndex[user].sub(1);
            uint256 lastIndex = holders.length.sub(1);

            if (lastIndex != indexToRemove) {
                address lastUser = holders[lastIndex];
                holders[indexToRemove] = lastUser;
                holderToIndex[lastUser] = indexToRemove.add(1);
            }

            holders.pop();
            delete holderToIndex[user];
        }
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(
            balanceOf[sender] >= amount,
            "ERC20: transfer amount exceeds balance"
        );

        balanceOf[sender] = balanceOf[sender].sub(amount);
        if (balanceOf[sender] == 0) {
            _removeHolder(sender);
        }

        if (balanceOf[recipient] == 0 && amount > 0) {
            _addHolder(recipient);
        }
        balanceOf[recipient] = balanceOf[recipient].add(amount);
    }
}
