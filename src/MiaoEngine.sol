// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IMiaoEngine} from "./IMiaoEngine.sol";
import {MiaoToken} from "./MiaoToken.sol";
import {Validator} from "./Validator.sol";
import {IERC20} from "@openzeppelin/contracts/token/erc20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {OracleLib, AggregatorV3Interface} from "./libraries/OracleLib.sol";

contract MiaoEngine is IMiaoEngine, Validator {

    /* -------------------------------------------------------------------------- */
    /*                                  Constants                                 */
    /* -------------------------------------------------------------------------- */

    /// @dev The precision of number when calculating
    uint256 private constant PRECISION = 18;
    /// @dev 200% collateral ratio, eg. 10$ miao => 20$ collateral token
    uint256 private constant MINIMUM_COLLATERAL_RATIO = 2 * 10 ** PRECISION;

    /* -------------------------------------------------------------------------- */
    /*                              Storage Variables                             */
    /* -------------------------------------------------------------------------- */

    MiaoToken private s_miaoToken;
    EnumerableSet.AddressSet private s_supportedTokenAddressSet;
    mapping(address user => mapping(address tokenAddress => uint256 value)) private s_collaterals;
    mapping(address tokenAddress => address priceFeedAddress) private s_priceFeeds;
    mapping(address user => uint256 miaoTokenMinted) private s_miaoTokenMinted;

    /* -------------------------------------------------------------------------- */
    /*                                  Libraries                                 */
    /* -------------------------------------------------------------------------- */

    using EnumerableSet for EnumerableSet.AddressSet;
    using OracleLib for AggregatorV3Interface;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    event MiaoEngine__CollateralDeposited(
        address indexed user, address indexed collateralTokenAddress, uint256 indexed amountCollateral
    );
    event MiaoEngine__CollateralRedeemed(
        address indexed user, address indexed collateralTokenAddress, uint256 indexed amountCollateral
    );
    event MiaoEngine__MiaoTokenMinted(address indexed user, uint256 indexed amountToken);

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    error MiaoEngine__TokenAddressAndPriceFeedLengthNotMatch();
    error MiaoEngine__TokenNotSupported();
    error MiaoEngine__AmountToRedeemExceedsDeposited(uint256 amountDeposited);
    error MiaoEngine__DebtToCoverExceedsCollateralDeposited(uint256 amountDeposited);
    error MiaoEngine__TransferFailed();
    error MiaoEngine__InsufficientBalance(uint256 balance);
    error MiaoEngine__MiaoToBurnExceedsUserDebt(uint256 userDebt);
    error MiaoEngine__CollateralRatioIsBroken(uint256 collateralRatio);
    error MiaoEngine__CollateralRatioIsNotBroken(uint256 collateralRatio);

    /* -------------------------------------------------------------------------- */
    /*                                  Modifiers                                 */
    /* -------------------------------------------------------------------------- */

    modifier onlySupportedToken(address tokenAddress) {
        if (s_priceFeeds[tokenAddress] == address(0)) {
            revert MiaoEngine__TokenNotSupported();
        }
        _;
    }

    constructor(address miaoTokenAddress, address[] memory tokenAddresses, address[] memory priceFeedAddresses) {
        s_miaoToken = MiaoToken(miaoTokenAddress);
        _initializePriceFeeds(tokenAddresses, priceFeedAddresses);
    }

    /* -------------------------------------------------------------------------- */
    /*                         External / Public Functions                        */
    /* -------------------------------------------------------------------------- */

    function depositCollateralAndMintMiaoToken(
        address collateralTokenAddress,
        uint256 amountCollateral,
        uint256 amountMiaoToMint
    )
        external
        notZeroAddress(collateralTokenAddress)
        notZeroValue(amountCollateral)
        notZeroValue(amountMiaoToMint)
        onlySupportedToken(collateralTokenAddress)
    {
        _depositCollateral(collateralTokenAddress, amountCollateral);
        _mintMiaoToken(amountMiaoToMint);
    }

    function redeemCollateral(
        address collateralTokenAddress,
        address collateralFrom,
        uint256 amountCollateralToRedeem,
        uint256 amountMiaoToBurn
    )
        public
        notZeroAddress(collateralTokenAddress)
        notZeroValue(amountCollateralToRedeem)
        onlySupportedToken(collateralTokenAddress)
    {
        _burnMiaoToken(msg.sender, collateralFrom, amountMiaoToBurn);
        _redeemCollateral(collateralTokenAddress, amountCollateralToRedeem, collateralFrom, msg.sender);
        _revertIfCollateralRatioIsBroken(collateralFrom);
        if (msg.sender != collateralFrom) {
            _revertIfCollateralRatioIsBroken(msg.sender);
        }
    }

    function liquidate(address user, address collateralTokenAddress, uint256 debtToCover)
        external
        notZeroAddress(collateralTokenAddress)
        notZeroValue(debtToCover)
        onlySupportedToken(collateralTokenAddress)
    {
        _revertIfCollateralRatioIsNotBroken(user);
        uint256 amountCollateral = _getTokenAmountFromUsd(collateralTokenAddress, debtToCover);
        uint256 amountDeposited = s_collaterals[user][collateralTokenAddress];
        if (amountCollateral > amountDeposited) {
            revert MiaoEngine__DebtToCoverExceedsCollateralDeposited(amountDeposited);
        }
        uint256 amountMiaoToBurn = debtToCover;
        // Give 10% bonus to liquidator
        uint256 bonus = amountCollateral * (10 ** (PRECISION - 1)) / (10 ** PRECISION);
        if (amountCollateral + bonus > amountDeposited) {
            // If the collateral is not enough to cover the debt and bonus,
            // just give all the collateral to liquidator for now, this will
            // be improved in the future
            amountCollateral = amountDeposited;
        } else {
            amountCollateral += bonus;
        }
        redeemCollateral(collateralTokenAddress, user, amountCollateral, amountMiaoToBurn);
    }

    function getCollateralRatio(address user) public view returns (uint256) {
        uint256 miaoMinted = s_miaoTokenMinted[user];
        if (miaoMinted == 0) {
            return type(uint256).max;
        }
        uint256 totalCollateralValueInUsd;
        for (uint256 i = 0; i < s_supportedTokenAddressSet.length(); i++) {
            address tokenAddress = s_supportedTokenAddressSet.at(i);
            uint256 amountCollateral = s_collaterals[user][tokenAddress];
            totalCollateralValueInUsd += _getTokenValueInUsd(tokenAddress, amountCollateral);
        }
        return totalCollateralValueInUsd * (10 ** PRECISION) / miaoMinted;
    }

    /* -------------------------------------------------------------------------- */
    /*                              Private Functions                             */
    /* -------------------------------------------------------------------------- */

    function _initializePriceFeeds(address[] memory tokenAddresses, address[] memory priceFeedAddresses) private {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert MiaoEngine__TokenAddressAndPriceFeedLengthNotMatch();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_supportedTokenAddressSet.add(tokenAddresses[i]);
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
        }
    }

    /**
     * @dev Deposit collateral token
     * @param collateralTokenAddress The address of collateral token contract
     * @param amountCollateral The amount of collateral token
     */
    function _depositCollateral(address collateralTokenAddress, uint256 amountCollateral) private {
        s_collaterals[msg.sender][collateralTokenAddress] += amountCollateral;
        emit MiaoEngine__CollateralDeposited(msg.sender, collateralTokenAddress, amountCollateral);
        IERC20(collateralTokenAddress).transferFrom(msg.sender, address(this), amountCollateral);
    }

    /**
     * @dev Mint Miao token
     * @param amount Amount of token you want to mint, 18 decimals
     */
    function _mintMiaoToken(uint256 amount) private {
        s_miaoTokenMinted[msg.sender] += amount;
        _revertIfCollateralRatioIsBroken(msg.sender);
        emit MiaoEngine__MiaoTokenMinted(msg.sender, amount);
        s_miaoToken.mint(msg.sender, amount);
    }

    /**
     * @dev Get token value in usd
     * @param tokenAddress The contract address of token
     * @param amountToken The amount of token, 18 decimals
     * @notice The returning usd value has 18 decimals
     */
    function _getTokenValueInUsd(address tokenAddress, uint256 amountToken)
        public
        view
        onlySupportedToken(tokenAddress)
        returns (uint256)
    {
        return amountToken * _getTokenUsdPrice(tokenAddress) / (10 ** PRECISION);
    }

    /**
     * @dev Get the amount of token from usd
     * @param tokenAddress The contract address of token address
     * @param amountUsd The amount of usd，18 decimals，100$ => 100e18
     */
    function _getTokenAmountFromUsd(address tokenAddress, uint256 amountUsd)
        public
        view
        onlySupportedToken(tokenAddress)
        returns (uint256)
    {
        return (amountUsd * 10 ** PRECISION) / _getTokenUsdPrice(tokenAddress);
    }

    /**
     * @dev Get the usd price of token
     * @param tokenAddress The contract address of token
     * @notice The returning usd price has 18 decimals
     */
    function _getTokenUsdPrice(address tokenAddress) public view onlySupportedToken(tokenAddress) returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[tokenAddress]);
        // Normally 8 decimals
        (, int256 answer,,,) = priceFeed.getStaleCheckedLatestRoundData();
        // token / usd price，18 decimals
        return uint256(answer) * 10 ** (PRECISION - priceFeed.decimals());
    }

    /**
     * @dev Burn miao token
     * @param from The account where the miao token comes from
     * @param onBehalfOf The account of which you want to be on behalf of
     * @param amount Amount of token to burn
     */
    function _burnMiaoToken(address from, address onBehalfOf, uint256 amount)
        private
        notZeroAddress(from)
        notZeroValue(amount)
    {
        uint256 balance = s_miaoToken.balanceOf(from);
        if (balance < amount) {
            revert MiaoEngine__InsufficientBalance(balance);
        }
        uint256 userMiaoMinted = s_miaoTokenMinted[onBehalfOf];
        if (userMiaoMinted < amount) {
            revert MiaoEngine__MiaoToBurnExceedsUserDebt(userMiaoMinted);
        }
        s_miaoTokenMinted[onBehalfOf] -= amount;
        bool success = s_miaoToken.transferFrom(from, address(this), amount);
        if (!success) {
            revert MiaoEngine__TransferFailed();
        }
        s_miaoToken.burn(address(this), amount);
    }

    /**
     * @dev Redeem collateral
     * @param collateralTokenAddress The address of collateral token contract
     * @param amountCollateralToRedeem The amount of collateral to redeem, 18 decimals
     * @param collateralFrom The account address where the collateral token comes from
     * @param collateralTo The account address where the collateral token will be transfer to
     */
    function _redeemCollateral(
        address collateralTokenAddress,
        uint256 amountCollateralToRedeem,
        address collateralFrom,
        address collateralTo
    ) private {
        uint256 collateralDeposited = s_collaterals[collateralFrom][collateralTokenAddress];
        if (collateralDeposited < amountCollateralToRedeem) {
            revert MiaoEngine__AmountToRedeemExceedsDeposited(collateralDeposited);
        }
        s_collaterals[collateralFrom][collateralTokenAddress] -= amountCollateralToRedeem;
        emit MiaoEngine__CollateralRedeemed(collateralFrom, collateralTokenAddress, amountCollateralToRedeem);
        bool success = IERC20(collateralTokenAddress).transfer(collateralTo, amountCollateralToRedeem);
        if (!success) {
            revert MiaoEngine__TransferFailed();
        }
    }

    /**
     * Revert if collateral ratio is less than MINIMUM_COLLATERAL_RATIO
     * @param user The account address
     */
    function _revertIfCollateralRatioIsBroken(address user) private view {
        (bool isBroken, uint256 collateralRatio) = _checkCollateralRatio(user);
        if (isBroken) {
            revert MiaoEngine__CollateralRatioIsBroken(collateralRatio);
        }
    }

    /**
     * Revert if collateral ratio is more than or equal to MINIMUM_COLLATERAL_RATIO
     * @param user The account address
     */
    function _revertIfCollateralRatioIsNotBroken(address user) private view {
        (bool isBroken, uint256 collateralRatio) = _checkCollateralRatio(user);
        if (!isBroken) {
            revert MiaoEngine__CollateralRatioIsNotBroken(collateralRatio);
        }
    }

    function _checkCollateralRatio(address user) public view returns (bool isBroken, uint256 collateralRatio) {
        collateralRatio = getCollateralRatio(user);
        isBroken = collateralRatio < MINIMUM_COLLATERAL_RATIO;
        return (isBroken, collateralRatio);
    }

    /* -------------------------------------------------------------------------- */
    /*                           Getter / View Functions                          */
    /* -------------------------------------------------------------------------- */

    function getMinimumCollateralRatio() public pure returns (uint256) {
        return MINIMUM_COLLATERAL_RATIO;
    }

    function getCollateralAmount(address user, address collateralTokenAddress) public view returns (uint256) {
        return s_collaterals[user][collateralTokenAddress];
    }

    function getMiaoTokenMinted(address user) public view returns (uint256) {
        return s_miaoTokenMinted[user];
    }

    function getMiaoTokenAddress() public view returns (address) {
        return address(s_miaoToken);
    }

    function getCollateralTokenAddresses() public view returns (address[] memory) {
        return s_supportedTokenAddressSet.values();
    }

    function getTokenUsdPrice(address tokenAddress) external view returns (uint256) {
        return _getTokenUsdPrice(tokenAddress);
    }

    function getTokenValueInUsd(address tokenAddress, uint256 amountToken) external view returns (uint256) {
        return _getTokenValueInUsd(tokenAddress, amountToken);
    }

    function getTokenAmountFromUsd(address tokenAddress, uint256 amountUsd)
        external
        view
        returns (uint256 tokenValue)
    {
        return _getTokenAmountFromUsd(tokenAddress, amountUsd);
    }
}
