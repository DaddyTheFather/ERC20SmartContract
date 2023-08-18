// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";


contract MyToken is ERC20, Ownable {
    uint256 public buyFee = 15; // Percentage
    uint256 public sellFee = 15; // Percentage
    uint256 public finalBuyFee = 2; // Percentage
    uint256 public finalSellFee = 2; // Percentage
    uint256 public transFee = 15; // Percentage
    address public marketingWallet;
    address public uniswapV2RouterAddress;
    address public uniswapV2Pair;
    bool public tradingOpen = false;

    mapping (address => bool) public feeReceivers;

    constructor() ERC20("MyToken", "MYTK") {
        _mint(msg.sender, 10_000_000 * 10**18);
    }

    function setUniswapV2RouterAddress(address _uniswapV2RouterAddress) public onlyOwner {
        require(uniswapV2RouterAddress == address(0), "Router address already set");
        uniswapV2RouterAddress = _uniswapV2RouterAddress;
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(uniswapV2RouterAddress);
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
    }

    function setMarketingWallet(address _marketingWallet) public onlyOwner {
        marketingWallet = _marketingWallet;
    }

    function setTransFee(uint256 _transFee) public onlyOwner {
        transFee = _transFee;
    }

    function setFeeReceivers(address[] memory _receivers, bool[] memory _statuses) public onlyOwner {
        require(_receivers.length == _statuses.length, "Arrays must be of equal length");
        for (uint i = 0; i < _receivers.length; i++) {
            feeReceivers[_receivers[i]] = _statuses[i];
        }
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) public payable onlyOwner {
        require(address(uniswapV2RouterAddress) != address(0), "Router address not set");
        require(msg.value == ethAmount, "ETH amount mismatch");

        _approve(address(this), address(uniswapV2RouterAddress), tokenAmount);

        IUniswapV2Router02(uniswapV2RouterAddress).addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            owner(),
            block.timestamp
        );
    }

    function openTrading() public onlyOwner {
        require(!tradingOpen, "Trading already open");
        tradingOpen = true;
    }

    function clearStuckBalance(uint256 percentage) public onlyOwner {
        require(percentage <= 100, "Percentage too high");
        uint256 amountToSend = address(this).balance * percentage / 100;
        payable(marketingWallet).transfer(amountToSend);
    }

    function renounceOwnership() public override onlyOwner {
        buyFee = finalBuyFee;
        sellFee = finalSellFee;
        super.renounceOwnership();
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override {
        require(tradingOpen, "Trading is not open yet");

        uint256 feeAmount = amount * transFee / 100;
        uint256 netAmount = amount - feeAmount;
        payable(marketingWallet).transfer(feeAmount);

        super._transfer(sender, recipient, netAmount);
    }

    // To receive Ether
    receive() external payable {}
}
