// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IMiaoEngine {
    /**
     * @dev Deposit collateral token and mint miao token
     * @param collateralTokenAddress The address of collateral token contract
     * @param amountCollateral The amount of collateral token
     * @param amountMiaoToMint The amount of miao token to mint
     * @notice This will revert if the MINIMUM_COLLATERAL_RATIO is not met
     */
    function depositCollateralAndMintMiaoToken(
        address collateralTokenAddress,
        uint256 amountCollateral,
        uint256 amountMiaoToMint
    ) external;

    /**
     * @dev Redeem collateral and burn miao token
     * @param collateralTokenAddress The address of collateral token contract
     * @param collateralFrom The account address where the collateral token comes from
     * @param amountCollateralToRedeem The amount of collateral token
     * @param amountMiaoToBurn The amount of miao token to burn
     */
    function redeemCollateral(
        address collateralTokenAddress,
        address collateralFrom,
        uint256 amountCollateralToRedeem,
        uint256 amountMiaoToBurn
    ) external;

    /**
     * @dev Liquidate user's collateral when collateral ratio is less than MININUM_COLLATERAL_RATIO
     * @param user The account address of user whose collateral ratio is less than MININUM_COLLATERAL_RATIO
     * @param collateralTokenAddress The address of collateral token contract
     * @param debtToCover The amount of debt (miao token) to cover
     */
    function liquidate(address user, address collateralTokenAddress, uint256 debtToCover) external;

    /**
     * @dev Get user's collateral ratio
     * @param user The account address of user
     */
    function getCollateralRatio(address user) external returns (uint256);
}
