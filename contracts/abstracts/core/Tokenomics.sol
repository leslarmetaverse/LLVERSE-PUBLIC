// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract Tokenomics is IERC20, Ownable {
	using SafeMath for uint256;
    mapping (address => bool) private _isBot;

/* ---------------------------------- Token --------------------------------- */

	string internal constant NAME = "LESLARVERSE";
	string internal constant SYMBOL = "LLVERSE";

	uint8 internal constant DECIMALS = 9;
	uint256 internal constant ZEROES = 10 ** DECIMALS;

	uint256 private constant MAX = ~uint256(0);
	uint256 internal constant _tTotal = 1000000000000 * ZEROES;
	uint256 internal _rTotal = (MAX - (MAX % _tTotal));

	address public deadAddr = 0x000000000000000000000000000000000000dEaD;

/* ---------------------------------- Fees ---------------------------------- */

	uint256 internal _tFeeTotal;

	// Will be redistributed amongst holders
	uint256 public _reflectionFee = 25;
	// Used to cache fee when removing fee temporarily.
	uint256 internal _previousReflectionFee = _reflectionFee;
	// Will be used for taxify
	uint256 public _taxFee = 25;
	// Used to cache fee when removing fee temporarily.
	uint256 internal _previousTaxFee = _taxFee;
    // Will keep tabs on the amount which should be taken from wallet for taxes.
	uint256 public accumulatedForTax = 0;
	// Will be used for liquidity
	uint256 public _liquidityFee = 0;
	// Used to cache fee when removing fee temporarily.
	uint256 internal _previousLiquidityFee = _liquidityFee;
	// Will keep tabs on the amount which should be taken from wallet for liquidity.
	uint256 public accumulatedForLiquidity = 0;
	// Will be used for buyback
	uint256 public _buybackFee = 25;
	// Used to cache fee when removing fee temporarily.
	uint256 internal _previousBuybackFee = _buybackFee;
	// Will keep tabs on the amount which should be taken from wallet for buyback.
	uint256 public accumulatedForBuyback = 0;
	// Will be sold for BNB and used as a collateral funds.
	uint256 public _collateralFee = 25;
	// Used to cache fee when removing fee temporarily.
	uint256 internal _previousCollateralFee = _collateralFee;
	// Will keep tabs on the amount which should be taken from wallet for collateral.
	uint256 public accumulatedForCollateral = 0;

	/**
	 * @notice Allows setting reflection fee.
	 */
	function setReflectionFee(uint256 fee)
		external 
		onlyOwner
		sameValue(_reflectionFee, fee)
	{
		_reflectionFee = fee;
	}

	/**
	 * @notice Allows setting tax fee.
	 */
	function setTaxFee(uint256 fee)
		external 
		onlyOwner
		sameValue(_taxFee, fee)
	{
		_taxFee = fee;
	}

	/**
	 * @notice Allows setting reflection fee.
	 */
	function setLiquidityFee(uint256 fee)
		external 
		onlyOwner
		sameValue(_liquidityFee, fee)
	{
		_liquidityFee = fee;
	}

	/**
	 * @notice Allows setting buyback fee.
	 */
	function setBuybackFee(uint256 fee)
		external 
		onlyOwner
		sameValue(_buybackFee, fee)
	{
		_buybackFee = fee;
	}

	/**
	 * @notice Allows setting collateral fee.
	 */
	function setCollateralFee(uint256 fee)
		external 
		onlyOwner
		sameValue(_collateralFee, fee)
	{
		_collateralFee = fee;
	}

	/**
	 * @notice Allows temporarily set all feees to 0. 
	 * It can be restored later to the previous fees.
	 */
	function disableAllFeesTemporarily()
		external
		onlyOwner
	{
		removeAllFee();
	}

	/**
	 * @notice Restore all fees from previously set.
	 */
	function restoreAllFees()
		external
		onlyOwner
	{
		restoreAllFee();
	}

	/**
	 * @notice Temporarily stops all fees. Caches the fees into secondary variables,
	 * so it can be reinstated later.
	 */
	function removeAllFee() internal {
		if (_reflectionFee == 0 &&
			_taxFee == 0 &&
			_liquidityFee == 0 &&
			_buybackFee == 0 &&
			_collateralFee == 0
		) return;
		_previousReflectionFee = _reflectionFee;
		_previousTaxFee = _taxFee;
		_previousLiquidityFee = _liquidityFee;
		_previousBuybackFee = _buybackFee;
		_previousCollateralFee = _collateralFee;

		_reflectionFee = 0;
		_taxFee = 0;
		_liquidityFee = 0;
		_buybackFee = 0;
		_collateralFee = 0;
	}

	/**
	 * @notice Restores all fees removed previously, using cached variables.
	 */
	function restoreAllFee() internal {
		_taxFee = _previousTaxFee;
		_liquidityFee = _previousLiquidityFee;
		_buybackFee = _previousBuybackFee;
		_collateralFee = _previousCollateralFee;
		_reflectionFee = _previousReflectionFee;
	}

	function calculateReflectionFee(
		uint256 amount,
		uint8 multiplier
	) internal view returns(uint256) {
		return amount.mul(_reflectionFee).mul(multiplier).div(10 ** 2);
	}

	function calculateTaxFee(
		uint256 amount,
		uint8 multiplier
	) internal view returns(uint256) {
		return amount.mul(_taxFee).mul(multiplier).div(10 ** 2);
	}

	function calculateLiquidityFee(
		uint256 amount,
		uint8 multiplier
	) internal view returns(uint256) {
		return amount.mul(_liquidityFee).mul(multiplier).div(10 ** 2);
	}

	function calculateBuybackFee(
		uint256 amount,
		uint8 multiplier
	) internal view returns(uint256) {
		return amount.mul(_buybackFee).mul(multiplier).div(10 ** 2);
	}

	function calculateCollateralFee(
		uint256 amount,
		uint8 multiplier
	) internal view returns(uint256) {
		return amount.mul(_collateralFee).mul(multiplier).div(10 ** 2);
	}

/* --------------------------- Triggers and limits -------------------------- */
	
	
	// One contract accumulates 0.01% of total supply, trigger tax wallet sendout.
	uint256 public minToTax = _tTotal.mul(1).div(10000);
	// Once contract accumulates 0.01% of total supply, trigger liquify.
	uint256 public minToLiquify = _tTotal.mul(1).div(10000);
	// One contract accumulates 0.01% of total supply, trigger buyback.
	uint256 public minToBuyback = _tTotal.mul(1).div(10000);
	// One contract accumulates 0.01% of total supply, trigger collateral distribution.
	uint256 public minToCollateral = _tTotal.mul(1).div(10000);

	

	/**
	@notice External function allowing to set minimum amount of tokens which trigger
	* tax send out.
	*/
	function setMinToTax(uint256 minTokens) 
		external 
		onlyOwner 
		supplyBounds(minTokens)
	{
		minToTax = minTokens * 10 ** 5;
    }
	/**
	@notice External function allowing to set minimum amount of tokens which trigger
	* auto liquification.
	*/
	function setMinToLiquify(uint256 minTokens) 
		external 
		onlyOwner
		supplyBounds(minTokens)
	{
		minToLiquify = minTokens * 10 ** 5;
	}

	/**
	@notice External function allowing to set minimum amount of tokens which trigger
	* buyback.
	*/
	function setMinToBuyback(uint256 minTokens) 
		external 
		onlyOwner 
		supplyBounds(minTokens)
	{
		minToBuyback = minTokens * 10 ** 5;
	}

	/**
	@notice External function allowing to set minimum amount of tokens which trigger
	* collateral send out.
	*/
	function setMinToCollateral(uint256 minTokens) 
		external 
		onlyOwner 
		supplyBounds(minTokens)
	{
		minToCollateral = minTokens * 10 ** 5;
	}

/* --------------------------------- IERC20 --------------------------------- */
	function totalSupply() external pure override returns(uint256) {
		return _tTotal;
	}

	function totalFees() external view returns(uint256) { 
		return _tFeeTotal; 
	}

    /* ---------------------------- Anti Bot System --------------------------- */

    function setAntibot(address account, bool _bot) external onlyOwner{
        require(_isBot[account] != _bot, "Value already set");
        _isBot[account] = _bot;
    }

    function isBot(address account) public view returns(bool){
        return _isBot[account];
    }

/* -------------------------------- Rescue ------------------------------- */

    // Use this in case BNB are sent to the contract by mistake
    function rescueBNB(uint256 weiAmount) external onlyOwner{
        require(address(this).balance >= weiAmount, "insufficient BNB balance");
        payable(msg.sender).transfer(weiAmount);
    }

    function rescueBEP20Tokens(address tokenAddress) external onlyOwner{
        IERC20(tokenAddress).transfer(msg.sender, IERC20(tokenAddress).balanceOf(address(this)));
    }

/* -------------------------------- Modifiers ------------------------------- */

	modifier supplyBounds(uint256 minTokens) {
		require(minTokens * 10 ** 5 > 0, "Amount must be more than 0");
		require(minTokens * 10 ** 5 <= _tTotal, "Amount must be not bigger than total supply");
		_;
	}

	modifier sameValue(uint256 firstValue, uint256 secondValue) {
		require(firstValue != secondValue, "Already set to this value.");
		_;
	}
}