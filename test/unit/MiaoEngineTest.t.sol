// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {MiaoEngine} from "../../src/MiaoEngine.sol";
import {MiaoToken} from "../../src/MiaoToken.sol";
import {Validator} from "../../src/Validator.sol";
import {DeployMiaoEngine} from "../../script/DeployMiaoEngine.s.sol";
import {Constants} from "../../script/util/Constants.sol";
import {DeployHelper} from "../../script/util/DeployHelper.sol";
import {ERC20Mock} from "../../test/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../../test/mocks/MockV3Aggregator.sol";
import {IERC20} from "@openzeppelin/contracts/token/erc20/IERC20.sol";

contract MiaoEngineTest is Test, Constants {
    uint256 private constant INITIAL_USER_BALANCE = 100 ether;
    uint256 private constant DEFAULT_AMOUNT_COLLATERAL = 2 ether;
    uint256 private constant DEFAULT_COLLATERAL_RATIO = 2 * (10 ** PRECISION);

    DeployMiaoEngine private deployer;
    DeployHelper.DeployConfig private deployConfig;
    MiaoEngine private miaoEngine;
    MiaoToken private miaoToken;
    address private user = makeAddr("user");

    address[] private tokenAddresses;
    address[] private priceFeedAddresses;

    event MiaoEngine__CollateralDeposited(
        address indexed user, address indexed collateralTokenAddress, uint256 indexed amountCollateral
    );
    event MiaoEngine__CollateralRedeemed(
        address indexed user, address indexed collateralTokenAddress, uint256 indexed amountCollateral
    );
    event MiaoEngine__MiaoTokenMinted(address indexed user, uint256 indexed amountToken);

    modifier depositedCollateral(address tokenAddress) {
        IERC20 collateralToken = IERC20(tokenAddress);
        vm.startPrank(user);
        collateralToken.approve(address(miaoEngine), INITIAL_USER_BALANCE);
        uint256 amountToMint = getAmountMiaoToMint(tokenAddress, DEFAULT_AMOUNT_COLLATERAL, DEFAULT_COLLATERAL_RATIO);
        miaoToken.approve(address(miaoEngine), amountToMint);
        miaoEngine.depositCollateralAndMintMiaoToken(tokenAddress, DEFAULT_AMOUNT_COLLATERAL, amountToMint);
        vm.stopPrank();
        _;
    }

    function setUp() external {
        deployer = new DeployMiaoEngine();
        (miaoEngine, deployConfig) = deployer.deploy();
        miaoToken = MiaoToken(miaoEngine.getMiaoTokenAddress());
        // Transfer some token to user
        IERC20 weth = IERC20(deployConfig.wethTokenAddress);
        vm.prank(address(deployer));
        weth.transfer(user, INITIAL_USER_BALANCE);
    }

    function testGetTokenUsdPrice() public view {
        assertEq(
            miaoEngine.getTokenUsdPrice(deployConfig.wethTokenAddress),
            adjustNumberByPrecision(WETH_USD_PRICE, PRICE_FEED_DECIMALS, PRECISION)
        );
        assertEq(
            miaoEngine.getTokenUsdPrice(deployConfig.wbtcTokenAddress),
            adjustNumberByPrecision(WBTC_USD_PRICE, PRICE_FEED_DECIMALS, PRECISION)
        );
    }

    function testGetTokenValueInUsd() public view {
        uint256 amountToken = 2 ether;
        assertEq(
            miaoEngine.getTokenValueInUsd(deployConfig.wethTokenAddress, amountToken),
            (amountToken * adjustNumberByPrecision(WETH_USD_PRICE, PRICE_FEED_DECIMALS, PRECISION)) / (10 ** PRECISION)
        );
        assertEq(
            miaoEngine.getTokenValueInUsd(deployConfig.wbtcTokenAddress, amountToken),
            (amountToken * adjustNumberByPrecision(WBTC_USD_PRICE, PRICE_FEED_DECIMALS, PRECISION)) / (10 ** PRECISION)
        );
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 amountEth = miaoEngine.getTokenAmountFromUsd(
            deployConfig.wethTokenAddress, 2 * adjustNumberByPrecision(WETH_USD_PRICE, PRICE_FEED_DECIMALS, PRECISION)
        );
        uint256 amountBtc = miaoEngine.getTokenAmountFromUsd(
            deployConfig.wbtcTokenAddress, 2 * adjustNumberByPrecision(WBTC_USD_PRICE, PRICE_FEED_DECIMALS, PRECISION)
        );
        assertEq(amountEth, adjustNumberByPrecision(2, 0, PRECISION));
        assertEq(amountBtc, adjustNumberByPrecision(2, 0, PRECISION));
    }

    function test_RevertWhen_TokenAddressAndPriceFeedAddressLengthNotMatch() public {
        ERC20Mock token = new ERC20Mock("TEST", "TEST", msg.sender, 10);
        // Token address length < price feed address length
        tokenAddresses = [address(0)];
        priceFeedAddresses = [address(0), address(1)];
        vm.expectRevert(MiaoEngine.MiaoEngine__TokenAddressAndPriceFeedLengthNotMatch.selector);
        new MiaoEngine(address(token), tokenAddresses, priceFeedAddresses);
        // Token address length > price feed address length
        tokenAddresses = [address(0), address(1)];
        priceFeedAddresses = [address(0)];
        vm.expectRevert(MiaoEngine.MiaoEngine__TokenAddressAndPriceFeedLengthNotMatch.selector);
        new MiaoEngine(address(token), tokenAddresses, priceFeedAddresses);
    }

    function test_RevertWhen_DepositCollateralParamIsInvalid() public {
        // Zero address
        vm.expectRevert(abi.encodeWithSelector(Validator.Validator__InvalidAddress.selector, address(0)));
        miaoEngine.depositCollateralAndMintMiaoToken(address(0), 1 ether, 1 ether);
        // Zero amount of collateral
        vm.expectRevert(abi.encodeWithSelector(Validator.Validator__ValueCanNotBeZero.selector, 0));
        miaoEngine.depositCollateralAndMintMiaoToken(address(1), 0 ether, 1 ether);
        // Zero amount of miao to mint
        vm.expectRevert(abi.encodeWithSelector(Validator.Validator__ValueCanNotBeZero.selector, 0));
        miaoEngine.depositCollateralAndMintMiaoToken(address(1), 1 ether, 0);
        // Unsupported token
        ERC20Mock token = new ERC20Mock("TEST", "TEST", msg.sender, 10);
        vm.expectRevert(abi.encodeWithSelector(MiaoEngine.MiaoEngine__TokenNotSupported.selector, address(token)));
        miaoEngine.depositCollateralAndMintMiaoToken(address(token), 1 ether, 1 ether);
    }

    function test_RevertWhen_CollateralRatioIsBroken() public {
        // This assumes the collateral ratio is 1, eg. 100$ collateral => 100$ miao
        uint256 amountCollateral = 1 ether;
        uint256 amountToMint = miaoEngine.getTokenValueInUsd(deployConfig.wethTokenAddress, amountCollateral);
        uint256 collateralRatio = 1 * 10 ** PRECISION;
        IERC20 weth = IERC20(deployConfig.wethTokenAddress);
        vm.prank(address(deployer));
        weth.transfer(user, amountCollateral);
        vm.startPrank(user);
        weth.approve(address(miaoEngine), amountCollateral);
        vm.expectRevert(
            abi.encodeWithSelector(MiaoEngine.MiaoEngine__CollateralRatioIsBroken.selector, collateralRatio)
        );
        miaoEngine.depositCollateralAndMintMiaoToken(address(weth), amountCollateral, amountToMint);
    }

    function testDepositWithEnoughCollateral() public {
        // Arrange data
        IERC20 weth = IERC20(deployConfig.wethTokenAddress);
        uint256 amountCollateral = 2 ether;
        uint256 collateralValueInUsd = miaoEngine.getTokenValueInUsd(address(weth), amountCollateral);
        uint256 amountToMint = (collateralValueInUsd * PRECISION) / miaoEngine.getMinimumCollateralRatio();
        vm.startPrank(user);
        weth.approve(address(miaoEngine), amountCollateral);
        // weth
        uint256 startingUserWethBalance = weth.balanceOf(user);
        uint256 startingEngineWethBalance = weth.balanceOf(address(miaoEngine));
        uint256 startingUserAmountCollateral = miaoEngine.getCollateralAmount(user, address(weth));
        // miao
        uint256 startingUserMiaoBalance = miaoToken.balanceOf(user);
        // Expected events
        vm.expectEmit(true, true, true, false);
        emit MiaoEngine__CollateralDeposited(user, address(weth), amountCollateral);
        vm.expectEmit(true, true, true, false);
        emit MiaoEngine__MiaoTokenMinted(user, amountToMint);
        // Act
        miaoEngine.depositCollateralAndMintMiaoToken(address(weth), amountCollateral, amountToMint);
        // Assert
        // Check weth
        uint256 endingUserWethBalance = weth.balanceOf(user);
        uint256 endingEngineWethBalance = weth.balanceOf(address(miaoEngine));
        uint256 endingUserAmountCollateral = miaoEngine.getCollateralAmount(user, address(weth));
        assertEq(endingUserWethBalance, startingUserWethBalance - amountCollateral);
        assertEq(endingEngineWethBalance, startingEngineWethBalance + amountCollateral);
        assertEq(endingUserAmountCollateral, startingUserAmountCollateral + amountCollateral);
        // Check miao
        uint256 endingUserMiaoBalance = miaoToken.balanceOf(user);
        assertEq(endingUserMiaoBalance, startingUserMiaoBalance + amountToMint);
    }

    function test_RevertWhen_RedeemAmountExceedsDeposited() public depositedCollateral(deployConfig.wethTokenAddress) {
        vm.startPrank(user);
        uint256 amountDeposited = miaoEngine.getCollateralAmount(user, deployConfig.wethTokenAddress);
        uint256 amountToMint =
            getAmountMiaoToMint(deployConfig.wethTokenAddress, DEFAULT_AMOUNT_COLLATERAL, DEFAULT_COLLATERAL_RATIO);
        vm.expectRevert(
            abi.encodeWithSelector(MiaoEngine.MiaoEngine__AmountToRedeemExceedsDeposited.selector, amountDeposited)
        );
        miaoEngine.redeemCollateral(
            deployConfig.wethTokenAddress, user, DEFAULT_AMOUNT_COLLATERAL + 1 ether, amountToMint
        );
    }

    function test_RevertWhen_AmountMiaoToBurnExceedsUserBalance()
        public
        depositedCollateral(deployConfig.wethTokenAddress)
    {
        // Burn all tokens from user
        vm.startPrank(address(miaoEngine));
        miaoToken.burn(user, miaoToken.balanceOf(user));
        vm.stopPrank();
        // Try to redeem, expect to revert
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(MiaoEngine.MiaoEngine__InsufficientBalance.selector, miaoToken.balanceOf(user))
        );
        miaoEngine.redeemCollateral(deployConfig.wethTokenAddress, user, DEFAULT_AMOUNT_COLLATERAL, INITIAL_BALANCE);
    }

    function test_RevertWhen_RedeemBreaksCollateralRatio() public depositedCollateral(deployConfig.wethTokenAddress) {
        uint256 amountCollateralToRedeem = DEFAULT_AMOUNT_COLLATERAL / 2;
        console2.log("amountCollateralToRedeem:", amountCollateralToRedeem);
        uint256 amountCollateralLeft =
            miaoEngine.getCollateralAmount(user, deployConfig.wethTokenAddress) - amountCollateralToRedeem;
        console2.log("amountCollateralLeft:", amountCollateralLeft);
        // Maximum amount of miao the user can hold after collateral is redeemed
        uint256 maximumAmountMiaoToHold =
            getAmountMiaoToMint(deployConfig.wethTokenAddress, amountCollateralLeft, DEFAULT_COLLATERAL_RATIO);
        console2.log("maximumAmountMiaoToHold:", maximumAmountMiaoToHold);
        // The minimum amount of miao that it is supposed to burn to maintain the collateral ratio
        uint256 minimumAmountMiaoToBurn = miaoEngine.getMiaoTokenMinted(user) - maximumAmountMiaoToHold;
        console2.log("minimumAmountMiaoToBurn:", minimumAmountMiaoToBurn);
        // Burn half of the minimum amount of miao
        uint256 amountMiaoToBurn = minimumAmountMiaoToBurn / 2;
        console2.log("amountMiaoToBurn:", amountMiaoToBurn);
        // Calculate expected collateral ratio after redeem
        uint256 amountMiaoLeft = miaoEngine.getMiaoTokenMinted(user) - amountMiaoToBurn;
        console2.log("amountMiaoLeft:", amountMiaoLeft);
        uint256 amountCollateralLeftInUsd =
            miaoEngine.getTokenValueInUsd(deployConfig.wethTokenAddress, amountCollateralLeft);
        console2.log("amountCollateralLeftInUsd:", amountCollateralLeftInUsd);
        uint256 expectedCollateralRatioAfterRedeem = (amountCollateralLeftInUsd * (10 ** PRECISION)) / amountMiaoLeft;
        console2.log("expectedCollateralRatioAfterRedeem:", expectedCollateralRatioAfterRedeem);
        vm.startPrank(user);
        miaoToken.approve(address(miaoEngine), amountMiaoToBurn);
        vm.expectRevert(
            abi.encodeWithSelector(
                MiaoEngine.MiaoEngine__CollateralRatioIsBroken.selector, expectedCollateralRatioAfterRedeem
            )
        );
        miaoEngine.redeemCollateral(deployConfig.wethTokenAddress, user, amountCollateralToRedeem, amountMiaoToBurn);
    }

    function testRedeemCollateral() public depositedCollateral(deployConfig.wethTokenAddress) {
        IERC20 weth = IERC20(deployConfig.wethTokenAddress);
        // Starting balance
        uint256 startingUserWethBalance = weth.balanceOf(user);
        uint256 startingUserMiaoBalance = miaoToken.balanceOf(user);
        uint256 startingEngineWethBalance = weth.balanceOf(address(miaoEngine));

        // Starting data
        uint256 startingAmountDeposited = miaoEngine.getCollateralAmount(user, address(weth));
        uint256 startingAmountMinted = miaoEngine.getMiaoTokenMinted(user);

        // Prepare redeem data
        uint256 amountCollateralToRedeem = DEFAULT_AMOUNT_COLLATERAL / 2;
        console2.log("amountCollateralToRedeem:", amountCollateralToRedeem);
        uint256 amountCollateralLeft =
            miaoEngine.getCollateralAmount(user, deployConfig.wethTokenAddress) - amountCollateralToRedeem;
        console2.log("amountCollateralLeft:", amountCollateralLeft);
        // Maximum amount of miao the user can hold after collateral is redeemed
        uint256 maximumAmountMiaoToHold =
            getAmountMiaoToMint(deployConfig.wethTokenAddress, amountCollateralLeft, DEFAULT_COLLATERAL_RATIO);
        console2.log("maximumAmountMiaoToHold:", maximumAmountMiaoToHold);
        // The minimum amount of miao that it is supposed to burn to maintain the collateral ratio
        uint256 minimumAmountMiaoToBurn = miaoEngine.getMiaoTokenMinted(user) - maximumAmountMiaoToHold;
        console2.log("minimumAmountMiaoToBurn:", minimumAmountMiaoToBurn);
        // Calculate expected collateral ratio after redeem
        uint256 amountMiaoLeft = miaoEngine.getMiaoTokenMinted(user) - minimumAmountMiaoToBurn;
        console2.log("amountMiaoLeft:", amountMiaoLeft);
        uint256 amountCollateralLeftInUsd =
            miaoEngine.getTokenValueInUsd(deployConfig.wethTokenAddress, amountCollateralLeft);
        console2.log("amountCollateralLeftInUsd:", amountCollateralLeftInUsd);
        uint256 expectedCollateralRatioAfterRedeem = (amountCollateralLeftInUsd * (10 ** PRECISION)) / amountMiaoLeft;
        console2.log("expectedCollateralRatioAfterRedeem:", expectedCollateralRatioAfterRedeem);
        vm.startPrank(user);
        miaoToken.approve(address(miaoEngine), minimumAmountMiaoToBurn);

        // Redeem
        miaoEngine.redeemCollateral(
            deployConfig.wethTokenAddress, user, amountCollateralToRedeem, minimumAmountMiaoToBurn
        );

        // Ending balance
        uint256 endingUserWethBalance = weth.balanceOf(user);
        uint256 endingUserMiaoBalance = miaoToken.balanceOf(user);
        uint256 endingEngineWethBalance = weth.balanceOf(address(miaoEngine));

        // Ending data
        uint256 endingAmountDeposited = miaoEngine.getCollateralAmount(user, address(weth));
        uint256 endingAmountMinted = miaoEngine.getMiaoTokenMinted(user);

        // Check balance
        assertEq(endingUserWethBalance, startingUserWethBalance + amountCollateralToRedeem);
        assertEq(endingUserMiaoBalance, startingUserMiaoBalance - minimumAmountMiaoToBurn);
        assertEq(endingEngineWethBalance, startingEngineWethBalance - amountCollateralToRedeem);

        // Check data
        assertEq(endingAmountDeposited, startingAmountDeposited - amountCollateralToRedeem);
        assertEq(endingAmountMinted, startingAmountMinted - minimumAmountMiaoToBurn);
    }

    function test_RevertWhen_LiquidateWhenUserCollateralRatioIsNotBroken()
        public
        depositedCollateral(deployConfig.wethTokenAddress)
    {
        // Mint some token to liquidator
        address liquidator = makeAddr("liquidator");
        vm.prank(address(miaoEngine));
        miaoToken.mint(liquidator, INITIAL_BALANCE);
        vm.startPrank(liquidator);
        miaoToken.approve(address(miaoEngine), INITIAL_BALANCE);
        // Liquidate user's collateral, this will revert no matter how much debt we are going to cover
        vm.expectRevert(
            abi.encodeWithSelector(
                MiaoEngine.MiaoEngine__CollateralRatioIsNotBroken.selector, miaoEngine.getCollateralRatio(user)
            )
        );
        miaoEngine.liquidate(user, deployConfig.wethTokenAddress, 1000 ether);
    }

    function testLiquidate() public depositedCollateral(deployConfig.wethTokenAddress) {
        IERC20 weth = IERC20(deployConfig.wethTokenAddress);
        address liquidator = makeAddr("liquidator");
        // Mint some token to liquidator
        vm.prank(address(miaoEngine));
        miaoToken.mint(liquidator, INITIAL_BALANCE);

        // Starting balance
        uint256 startingLiquidatorWethBalance = weth.balanceOf(liquidator);
        uint256 startingLiquidatorMiaoBalance = miaoToken.balanceOf(liquidator);
        uint256 startingEngineWethBalance = weth.balanceOf(address(miaoEngine));

        // Starting data
        uint256 startingUserAmountDeposited = miaoEngine.getCollateralAmount(user, address(weth));
        uint256 startingLiquidatorAmountDeposited = miaoEngine.getCollateralAmount(liquidator, address(weth));
        uint256 startingUserAmountMinted = miaoEngine.getMiaoTokenMinted(user);

        vm.startPrank(liquidator);
        miaoToken.approve(address(miaoEngine), startingUserAmountMinted);
        // Adjust weth / usd price to 1000$, this will break the collateral ratio, and collateral
        // cant't cover (debt + bonus), liquidator will get all the collaterals without bonus
        MockV3Aggregator wethPriceFeed = MockV3Aggregator(deployConfig.wethPriceFeedAddress);
        wethPriceFeed.updateAnswer(int256(1000 * (10 ** PRICE_FEED_DECIMALS)));

        // Liquidate
        miaoEngine.liquidate(user, address(weth), startingUserAmountMinted);

        // Ending balance
        uint256 endingLiquidatorWethBalance = weth.balanceOf(liquidator);
        uint256 endingLiquidatorMiaoBalance = miaoToken.balanceOf(liquidator);
        uint256 endingEngineWethBalance = weth.balanceOf(address(miaoEngine));

        // Ending data
        uint256 endingUserAmountDeposited = miaoEngine.getCollateralAmount(user, address(weth));
        uint256 endingLiquidatorAmountDeposited = miaoEngine.getCollateralAmount(liquidator, address(weth));
        uint256 endingUserAmountMinted = miaoEngine.getMiaoTokenMinted(user);

        // Check balance
        assertEq(endingLiquidatorWethBalance, startingLiquidatorWethBalance + startingUserAmountDeposited);
        assertEq(endingLiquidatorMiaoBalance, startingLiquidatorMiaoBalance - startingUserAmountMinted);
        assertEq(endingEngineWethBalance, startingEngineWethBalance - startingUserAmountDeposited);

        // Check data
        assertEq(endingUserAmountDeposited, 0);
        assertEq(endingLiquidatorAmountDeposited, startingLiquidatorAmountDeposited);
        assertEq(endingUserAmountMinted, 0);
    }

    function getAmountMiaoToMint(address collateralTokenAddress, uint256 amountCollateral, uint256 collateralRatio)
        private
        view
        returns (uint256)
    {
        uint256 tokenValueInUsd = miaoEngine.getTokenValueInUsd(collateralTokenAddress, amountCollateral);
        return (tokenValueInUsd * (10 ** PRECISION)) / collateralRatio;
    }

    function adjustNumberByPrecision(uint256 number, uint256 decimals, uint256 precision)
        private
        pure
        returns (uint256)
    {
        return number * 10 ** (precision - decimals);
    }
}
