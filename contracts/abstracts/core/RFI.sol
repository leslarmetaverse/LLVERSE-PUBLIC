// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../core/Tokenomics.sol";
import "../core/Pancake.sol";

abstract contract RFI is IERC20, Ownable, Tokenomics, Pancake {
	using SafeMath for uint256;
    uint256 public taxBuy = 3;
    uint256 public taxSell = 3;

	mapping(address => uint256) internal _rOwned;
	mapping(address => uint256) internal _tOwned;
	mapping(address => mapping(address => uint256)) private _allowances;

	struct TValues {
		uint256 tTransferAmount;
		uint256 tFee;
		uint256 trFee;
		uint256 tLiquidity;
		uint256 tBuyback;
		uint256 tCollateral;
	}

	struct RValues {
		uint256 rAmount;
		uint256 rTransferAmount;
		uint256 rFee;
	}

	constructor() {
		// Assigns all reflected tokens to the deployer on creation
		_rOwned[_msgSender()] = _rTotal;

		emit Transfer(address(0), _msgSender(), _tTotal);
	}

	//Set tax buy on percent
	function setTaxBuy(uint256 _percent)external onlyOwner{
		taxBuy = _percent;
	}
	//Set tax sale on percent
	function setTaxSell(uint256 _percent)external onlyOwner{
		taxSell = _percent;
	}

	/**
	 * @notice Calculates all values for "total" and "reflected" states.
	 * @param tAmount Token amount related to which, all values are calculated.
	 */
	function _getValues(
		uint256 tAmount,
        bool isSellType
	) private view returns(
		TValues memory tValues, RValues memory rValues
	) {
        uint256 taxAmount;
        if(isSellType){
            taxAmount = tAmount.mul(taxSell).div(10 ** 2); 
        }else{
            taxAmount = tAmount.mul(taxBuy).div(10 ** 2);
        }
		TValues memory tV = _getTValues(tAmount, taxAmount);
        // if(take){
        //     tAmount = tAmount.sub(taxAmount);
        // }
		RValues memory rV = _getRValues(
            tAmount,
			tV.trFee,
			tV.tFee,
			tV.tLiquidity,
			tV.tBuyback,
			tV.tCollateral,
			_getRate()
		);
		return (tV, rV);
	}

	/**
	 * @notice Calculates values for "total" states.
	 * @param tAmount Token amount related to which, total values are calculated.
	 */
	function _getTValues(
		uint256 tAmount,
        uint256 amountAfterTax
	) private view returns(TValues memory tValues) {
		TValues memory tV;
		tV.trFee = calculateReflectionFee(amountAfterTax, 1);
		tV.tFee = calculateTaxFee(amountAfterTax, 1);
		tV.tLiquidity = calculateLiquidityFee(amountAfterTax, 1);
		tV.tBuyback = calculateBuybackFee(amountAfterTax, 1);
		tV.tCollateral = calculateCollateralFee(amountAfterTax, 1);
		uint256 fees = tV.trFee
			.add(tV.tFee)
			.add(tV.tLiquidity)
			.add(tV.tBuyback)
			.add(tV.tCollateral);
		tV.tTransferAmount = tAmount.sub(fees);
		return tV;
	}

	/**
	 * @notice Calculates values for "reflected" states.
	 * @param tAmount Token amount related to which, reflected values are calculated.
	 * @param tFee Total fee related to which, reflected values are calculated.
	 * @param tLiquidity Total liquidity related to which, reflected values are calculated.
	 * @param currentRate Rate used to calculate reflected values.
	 /** */
	function _getRValues(
		uint256 tAmount,
		uint256 trFee,
		uint256 tFee,
		uint256 tLiquidity,
		uint256 tBuyback,
		uint256 tCollateral,
		uint256 currentRate
	) private pure returns(RValues memory rValues) {
		RValues memory rV;
		rV.rAmount = tAmount.mul(currentRate);
		rV.rFee = trFee.mul(currentRate);
		uint256 rFee = tFee.mul(currentRate);
		uint256 rLiquidity = tLiquidity.mul(currentRate);
		uint256 rBuyback = tBuyback.mul(currentRate);
		uint256 rCollateral = tCollateral.mul(currentRate);
		uint256 fees = rV.rFee + rFee + rLiquidity + rBuyback + rCollateral;
		rV.rTransferAmount = rV.rAmount.sub(fees);
		return rV;
	}

	/**
	 * @notice Calculates the rate of total suply to reflected supply.
	 */
	function _getRate() private view returns(uint256) {
		(uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
		return rSupply.div(tSupply);
	}

	function _reflectFee(
		uint256 rFee,
		uint256 tFee
	) private {
		_rTotal = _rTotal.sub(rFee);
		_tFeeTotal = _tFeeTotal.add(tFee);
	}

	/**
	 * @notice Returns totals for "total" supply and "reflected" supply.
	 * Two forks of the if statement return the same data, just for naming purpose
	 */
	function _getCurrentSupply() private view returns(uint256, uint256) {
		uint256 rSupply = _rTotal;
		uint256 tSupply = _tTotal;

		if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
		return (rSupply, tSupply);
	}

	function tokenFromReflection(
		uint256 rAmount
	) public view returns(uint256) {
		require(rAmount <= _rTotal, "Amount must be less than total reflections");
		uint256 currentRate = _getRate();
		return rAmount.div(currentRate);
	}

/* --------------------------------- Custom --------------------------------- */

	/**
	 * @notice ERC20 token transaction approval with allowance.
	 */
	function rfiApprove(
		address ownr,
		address spender,
		uint256 amount
	) internal {
		require(ownr != address(0), "ERC20: approve from the zero address");
		require(spender != address(0), "ERC20: approve to the zero address");

		_allowances[ownr][spender] = amount;
		emit Approval(ownr, spender, amount);
	}

	function _transfer(
		address from,
		address to,
		uint256 amount
	) internal {
        require(!isBot(msg.sender), "Bot account has been detected, contact admin for further information");
		require(from != address(0), "ERC20: transfer from the zero address");
		require(to != address(0), "ERC20: transfer to the zero address");
		require(amount > 0, "Transfer amount must be greater than zero");

		// Override this in the main contract to plug your features inside transactions.
		beforeTokenTransfer(from, to, amount);

		// Transfer amount, it will take tax, liquidity fee
		bool take = takeFee(from, to);
		_tokenTransfer(from, to, amount, take);
	}

	/**
	 * @notice Performs token transfer with fees.
	 * @param sender Address of the sender.
	 * @param recipient Address of the recipient.
	 * @param amount Amount of tokens to send.
	 * @param take Toggle on/off fees.
	 */
	function _tokenTransfer(
		address sender,
		address recipient,
		uint256 amount,
		bool take
	) private {
        //check trx type
        bool isSellType = getTransactionType(sender, recipient) == TransactionType.SELL;
		// Remove fees for this transaction if needed.
		if (!take)
			removeAllFee();
        
		// Calculate all reflection magic...
		(TValues memory tV, RValues memory rV) = _getValues(amount, isSellType);
		// Adjust reflection states
		_rOwned[sender] = _rOwned[sender].sub(rV.rAmount);
		_rOwned[recipient] = _rOwned[recipient].add(rV.rTransferAmount);
		// Calcuate fees. If above fees were removed, then these will obviously
		// not take any fees.
		_takeTax(tV.tFee);
		_takeLiquidityFee(tV.tLiquidity);
		_takeBuybackFee(tV.tBuyback);
		_takeCollateralFee(tV.tCollateral);
		_reflectFee(rV.rFee, tV.trFee);
		emit Transfer(sender, recipient, tV.tTransferAmount);
        
		// Reinstate fees if they were removed for this transaction.
		if (!take)
			restoreAllFee();
	}

	/**
	* @notice Override this function to intercept the transaction and perform 
	* additional checks or perform certain functions before allowing transaction
	* to complete. You can prevent transaction to complete here too.
	*/
	function beforeTokenTransfer(
		address from, 
		address to, 
		uint256 amount
	) virtual internal {


	}

	function takeFee(address from, address to) virtual internal returns(bool) {


		return true;
	}

/* ------------------------------- Custom fees ------------------------------ */
	/**
	* @notice Collects tokens from liquidity fee. Accordingly adjusts "reflected" 
	amounts. 
	*/
	function _takeLiquidityFee(
		uint256 tLiquidity
	) private {
		uint256 currentRate = _getRate();
		uint256 rLiquidity = tLiquidity.mul(currentRate);
		_rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
		// Keep tabs, so when processing is triggered, we know how much should we take.
		accumulatedForLiquidity = accumulatedForLiquidity.add(tLiquidity);
	}

	/**
	* @notice Collects tokens from buyback fee. Accordingly adjusts "reflected" 
	amounts. 
	*/
	function _takeBuybackFee(
		uint256 tBuyback
	) private {
		uint256 currentRate = _getRate();
		uint256 rBuyback = tBuyback.mul(currentRate);
		_rOwned[address(this)] = _rOwned[address(this)].add(rBuyback);
		// Keep tabs, so when processing is triggered, we know how much should we take.
		accumulatedForBuyback = accumulatedForBuyback.add(tBuyback);
	}

		/**
	* @notice Collects tokens from collateral fee. Accordingly adjusts "reflected" 
	amounts. 
	*/
	function _takeCollateralFee(
		uint256 tCollateral
	) private {
		uint256 currentRate = _getRate();
		uint256 rCollateral = tCollateral.mul(currentRate);
		_rOwned[address(this)] = _rOwned[address(this)].add(rCollateral);
		// Keep tabs, so when processing is triggered, we know how much should we take.
		accumulatedForCollateral = accumulatedForCollateral.add(tCollateral);
	}

    /* ------------------------------- Custom fees ------------------------------ */
	/**
	* @notice Collects tokens from tax fee. Accordingly adjusts "reflected" 
	amounts. 
	*/
	function _takeTax(
		uint256 tFee
	) private {
		uint256 currentRate = _getRate();
		uint256 rFee = tFee.mul(currentRate);
		_rOwned[address(this)] = _rOwned[address(this)].add(rFee);
		// Keep tabs, so when processing is triggered, we know how much should we take.
		accumulatedForTax = accumulatedForTax.add(tFee);
	}

/* --------------------------------- IERC20 --------------------------------- */

	function balanceOf(
		address account
	) public view override returns(uint256) {
		return tokenFromReflection(_rOwned[account]);
	}

	function transfer(
		address recipient,
		uint256 amount
	) public override returns(bool) {
		_transfer(_msgSender(), recipient, amount);
		return true;
	}

	function allowance(
		address ownr,
		address spender
	) public view override returns(uint256) {
		return _allowances[ownr][spender];
	}

	function approve(
		address spender,
		uint256 amount
	) public override returns(bool) {
		rfiApprove(_msgSender(), spender, amount);
		return true;
	}

	function transferFrom(
		address sender,
		address recipient,
		uint256 amount
	) public override returns(bool) {
		_transfer(sender, recipient, amount);
		rfiApprove(
			sender,
			_msgSender(),
			_allowances[sender][_msgSender()].sub(
				amount,
				"ERC20: transfer amount exceeds allowance"
			)
		);
		return true;
	}

	function increaseAllowance(
		address spender,
		uint256 addedValue
	) public virtual returns(bool) {
		rfiApprove(
			_msgSender(),
			spender,
			_allowances[_msgSender()][spender].add(addedValue)
		);
		return true;
	}

	function decreaseAllowance(
		address spender,
		uint256 subtractedValue
	) public virtual returns(bool) {
		rfiApprove(
			_msgSender(),
			spender,
			_allowances[_msgSender()][spender]
			.sub(subtractedValue, "ERC20: decreased allowance below zero")
		);
		return true;
	}

/* -------------------------------- Modifiers ------------------------------- */

	modifier onlyOwnerOrHolder {
		require(
			owner() == _msgSender() || balanceOf(_msgSender()) > 0, 
			"Only the owner and the holder can use this feature."
			);
		_;
	}

	modifier onlyHolder {
		require(
			balanceOf(_msgSender()) > 0, 
			"Only the holder can use this feature."
			);
		_;
	}
}