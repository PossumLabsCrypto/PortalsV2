// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {PortalV2MultiAsset} from "src/PortalV2MultiAsset.sol";
import {MintBurnToken} from "src/MintBurnToken.sol";
import {VirtualLP} from "src/VirtualLP.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWater} from "src/interfaces/IWater.sol";
import {IPortalV2MultiAsset} from "src/interfaces/IPortalV2MultiAsset.sol";
import {PortalNFT} from "src/PortalNFT.sol";

contract PortalV2MultiAssetTest is Test {
    // External token addresses
    address constant WETH_ADDRESS = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant PSM_ADDRESS = 0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5;

    address private constant USDC_WATER = 0x9045ae36f963b7184861BDce205ea8B08913B48c;
    address private constant WETH_WATER = 0x8A98929750e6709Af765F976c6bddb5BfFE6C06c;
    address private constant WBTC_WATER = 0x4e9e41Bbf099fE0ef960017861d181a9aF6DDa07;

    address private constant _ADDRESS_USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address private constant _ADDRESS_ETH = address(0);
    address private constant _ADDRESS_WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;

    // General constants
    uint256 private constant SECONDS_PER_YEAR = 31536000; // seconds in a 365 day year
    uint256 private constant OWNER_DURATION = 31536000; // 1 Year

    // Portal Constructor values
    uint256 constant _TARGET_CONSTANT_USDC = 133333333333333 * 1e36;
    uint256 constant _TARGET_CONSTANT_WETH = 44444444444 * 1e36;
    uint256 constant _TARGET_CONSTANT_WBTC = 2168021680 * 1e36;

    uint256 constant _FUNDING_PHASE_DURATION = 604800; // 7 days
    uint256 constant _FUNDING_MIN_AMOUNT = 2e26; // 200M PSM

    uint256 constant _DECIMALS = 18;
    uint256 constant _DECIMALS_USDC = 6;
    uint256 constant _DECIMALS_WBTC = 8;

    uint256 constant _AMOUNT_TO_CONVERT = 1e23; // 100k

    string _META_DATA_URI = "abcd";

    // time
    uint256 timestamp;
    uint256 fundingPhase;
    uint256 ownerExpiry;
    uint256 hundredYearsLater;

    // prank addresses
    address payable Alice = payable(0x46340b20830761efd32832A74d7169B29FEB9758);
    address payable Bob = payable(0xDD56CFdDB0002f4d7f8CC0563FD489971899cb79);
    address payable Karen = payable(0x3A30aaf1189E830b02416fb8C513373C659ed748);

    // Token Instances
    IERC20 psm = IERC20(PSM_ADDRESS);
    IERC20 usdc = IERC20(_ADDRESS_USDC);
    IERC20 weth = IERC20(WETH_ADDRESS);
    IERC20 wbtc = IERC20(_ADDRESS_WBTC);

    // Portals & LP
    PortalV2MultiAsset public portal_USDC;
    PortalV2MultiAsset public portal_ETH;
    PortalV2MultiAsset public portal_WBTC;
    VirtualLP public virtualLP;

    // Simulated USDC distributor
    address usdcSender = 0xF977814e90dA44bFA03b6295A0616a897441aceC;

    // Simulated WBTC distributor
    address wbtcSender = 0x47c031236e19d024b42f8AE6780E44A573170703;

    // PSM Treasury
    address psmSender = 0xAb845D09933f52af5642FC87Dd8FBbf553fd7B33;

    // starting token amounts
    uint256 usdcAmount = 1e12; // 1M USDC
    uint256 psmAmount = 1e25; // 10M PSM
    uint256 usdcSendAmount = 1e9; // 1k USDC
    uint256 wbtcAmount = 1e10; // 100 WBTC

    ////////////// SETUP ////////////////////////
    function setUp() public {
        vm.createSelectFork({urlOrAlias: "alchemy_arbitrum_api", blockNumber: 200000000});

        // Create Virtual LP instance
        virtualLP = new VirtualLP(psmSender, _AMOUNT_TO_CONVERT, _FUNDING_PHASE_DURATION, _FUNDING_MIN_AMOUNT);
        address _VIRTUAL_LP = address(virtualLP);

        // Create Portal instances
        portal_USDC = new PortalV2MultiAsset(
            _VIRTUAL_LP, _TARGET_CONSTANT_USDC, _ADDRESS_USDC, _DECIMALS_USDC, "USD Coin", "USDC", _META_DATA_URI
        );
        portal_ETH = new PortalV2MultiAsset(
            _VIRTUAL_LP, _TARGET_CONSTANT_WETH, _ADDRESS_ETH, _DECIMALS, "ETHER", "ETH", _META_DATA_URI
        );

        portal_WBTC = new PortalV2MultiAsset(
            _VIRTUAL_LP, _TARGET_CONSTANT_WBTC, _ADDRESS_WBTC, _DECIMALS_WBTC, "Bitcoin", "WBTC", _META_DATA_URI
        );

        // creation time
        timestamp = block.timestamp;
        fundingPhase = timestamp + _FUNDING_PHASE_DURATION;
        ownerExpiry = timestamp + OWNER_DURATION;
        hundredYearsLater = timestamp + 100 * SECONDS_PER_YEAR;

        // Deal tokens to addresses
        vm.deal(Alice, 1000 ether);
        vm.prank(psmSender);
        psm.transfer(Alice, psmAmount);
        vm.prank(usdcSender);
        usdc.transfer(Alice, usdcAmount);
        vm.prank(wbtcSender);
        wbtc.transfer(Alice, wbtcAmount);

        vm.deal(Bob, 1000 ether);
        vm.prank(psmSender);
        psm.transfer(Bob, psmAmount);
        vm.prank(usdcSender);
        usdc.transfer(Bob, usdcAmount);

        vm.deal(Karen, 1000 ether);
        vm.prank(psmSender);
        psm.transfer(Karen, psmAmount);
        vm.prank(usdcSender);
        usdc.transfer(Karen, usdcAmount);
    }

    ////////////// HELPER FUNCTIONS /////////////
    // create the bToken token
    function helper_create_bToken() public {
        virtualLP.create_bToken();
    }

    // fund the Virtual LP
    function helper_fundLP() public {
        vm.startPrank(psmSender);

        psm.approve(address(virtualLP), 1e55);
        virtualLP.contributeFunding(_FUNDING_MIN_AMOUNT);

        vm.stopPrank();
    }

    // Register USDC Portal
    function helper_registerPortalUSDC() public {
        vm.prank(psmSender);
        virtualLP.registerPortal(address(portal_USDC), _ADDRESS_USDC, USDC_WATER);
    }

    // Register ETH Portal
    function helper_registerPortalETH() public {
        vm.prank(psmSender);
        virtualLP.registerPortal(address(portal_ETH), _ADDRESS_ETH, WETH_WATER);
    }

    // Register WBTC Portal
    function helper_registerPortalWBTC() public {
        vm.prank(psmSender);
        virtualLP.registerPortal(address(portal_WBTC), _ADDRESS_WBTC, WBTC_WATER);
    }

    // activate the Virtual LP
    function helper_activateLP() public {
        vm.warp(fundingPhase);
        virtualLP.activateLP();
    }

    // fund and activate the LP and register both Portals
    function helper_prepareSystem() public {
        helper_create_bToken();
        helper_fundLP();
        helper_registerPortalETH();
        helper_registerPortalUSDC();
        helper_registerPortalWBTC();
        helper_activateLP();
    }

    // Deploy the NFT contract
    function helper_createNFT() public {
        portal_USDC.create_portalNFT();
    }

    // Deploy the ERC20 contract for mintable Portal Energy
    function helper_createPortalEnergyToken() public {
        portal_USDC.create_portalEnergyToken();
    }

    // Increase allowance of tokens used by the USDC Portal
    function helper_setApprovalsInLP_USDC() public {
        virtualLP.increaseAllowanceVault(address(portal_USDC));
    }

    // Increase allowance of tokens used by the ETH Portal
    function helper_setApprovalsInLP_ETH() public {
        virtualLP.increaseAllowanceVault(address(portal_ETH));
    }

    // Increase allowance of tokens used by the ETH Portal
    function helper_setApprovalsInLP_WBTC() public {
        virtualLP.increaseAllowanceVault(address(portal_WBTC));
    }

    // USDC
    function helper_stake100kUSDC() public {
        uint256 amount = 100000e6;
        helper_prepareSystem();
        helper_setApprovalsInLP_USDC();

        vm.startPrank(Alice);
        usdc.approve(address(portal_USDC), 1e55);
        portal_USDC.stake(amount);
        vm.stopPrank();
    }

    // ETH
    function helper_stake100ETH() public {
        uint256 amount = 100e18;
        helper_prepareSystem();
        helper_setApprovalsInLP_ETH();

        vm.startPrank(Alice);
        portal_ETH.stake{value: amount}(amount);
        vm.stopPrank();
    }

    // WBTC
    function helper_stake10WBTC() public {
        uint256 amount = 1e9;
        helper_prepareSystem();
        helper_setApprovalsInLP_WBTC();

        vm.startPrank(Alice);
        wbtc.approve(address(portal_WBTC), 1e55);
        portal_WBTC.stake(amount);
        vm.stopPrank();
    }

    function testSuccess_sellPortalEnergyUSDC() public {
        helper_stake100kUSDC();

        (,,,, uint256 peBalanceBefore,,) = portal_USDC.getUpdateAccount(Alice, 0, true);
        uint256 psmBalanceBefore_Bob = psm.balanceOf(Bob);

        vm.prank(Alice);
        portal_USDC.sellPortalEnergy(Bob, peBalanceBefore, 1, block.timestamp);

        uint256 reserve0 = _FUNDING_MIN_AMOUNT;
        uint256 reserve1 = _TARGET_CONSTANT_USDC / _FUNDING_MIN_AMOUNT;
        uint256 result = (peBalanceBefore * reserve0) / (peBalanceBefore + reserve1 + 1);

        (,,,, uint256 peBalanceAfter,,) = portal_USDC.getUpdateAccount(Alice, 0, true);
        uint256 psmBalanceAfter_Bob = psm.balanceOf(Bob);

        uint256 remainingPSM = psm.balanceOf(address(virtualLP));

        uint256 maxLock = portal_USDC.maxLockDuration();
        uint256 stakedTokens = 100000;
        uint256 tokenPrice = 1;
        uint256 stakedValue = stakedTokens * tokenPrice;
        uint256 usdUpfrontYield = result / 1000e18;
        uint256 upfrontYieldROI = (usdUpfrontYield * 10000) / stakedValue;
        uint256 upfrontYieldAPR = (upfrontYieldROI * SECONDS_PER_YEAR) / maxLock;
        console2.log("Remaining PSM in vLP:", remainingPSM / 1e18);

        console2.log("staked USD value:", stakedValue);
        console2.log("Sold PE by Alice:", peBalanceBefore / 1e18);
        console2.log("Bobs PSM balance gain:", result / 1e18);
        console2.log("upfront yield value in USD", usdUpfrontYield);
        console2.log("upfront yield ROI (x100)", upfrontYieldROI);
        console2.log("upfront yield APR (x100)", upfrontYieldAPR);
        console2.log("Remaining PSM in vLP:", psm.balanceOf(address(virtualLP)) / 1e18);

        assertEq(peBalanceAfter, 0);
        assertEq(psmBalanceBefore_Bob, psmAmount);
        assertEq(psmBalanceAfter_Bob, psmAmount + result);
        assertEq(_FUNDING_MIN_AMOUNT, remainingPSM + result);
    }

    function testSuccess_sellPortalEnergyETH() public {
        helper_stake100ETH();

        (,,,, uint256 peBalanceBefore,,) = portal_ETH.getUpdateAccount(Alice, 0, true);
        uint256 psmBalanceBefore_Bob = psm.balanceOf(Bob);

        vm.prank(Alice);
        portal_ETH.sellPortalEnergy(Bob, peBalanceBefore, 1, block.timestamp);

        uint256 reserve0 = _FUNDING_MIN_AMOUNT;
        uint256 reserve1 = _TARGET_CONSTANT_WETH / _FUNDING_MIN_AMOUNT;
        uint256 result = (peBalanceBefore * reserve0) / (peBalanceBefore + reserve1 + 1);

        (,,,, uint256 peBalanceAfter,,) = portal_ETH.getUpdateAccount(Alice, 0, true);
        uint256 psmBalanceAfter_Bob = psm.balanceOf(Bob);

        uint256 remainingPSM = psm.balanceOf(address(virtualLP));

        uint256 maxLock = portal_ETH.maxLockDuration();
        uint256 stakedTokens = 100;
        uint256 tokenPrice = 3000;
        uint256 stakedValue = stakedTokens * tokenPrice;
        uint256 usdUpfrontYield = result / 1000e18;
        uint256 upfrontYieldROI = (usdUpfrontYield * 10000) / stakedValue;
        uint256 upfrontYieldAPR = (upfrontYieldROI * SECONDS_PER_YEAR) / maxLock;

        console2.log("staked USD value:", stakedValue);
        console2.log("Sold PE by Alice:", peBalanceBefore / 1e18);
        console2.log("Bobs PSM balance gain:", result / 1e18);
        console2.log("upfront yield value in USD", usdUpfrontYield);
        console2.log("upfront yield ROI (x100)", upfrontYieldROI);
        console2.log("upfront yield APR (x100)", upfrontYieldAPR);
        console2.log("Remaining PSM in vLP:", remainingPSM / 1e18);

        assertEq(peBalanceAfter, 0);
        assertEq(psmBalanceBefore_Bob, psmAmount);
        assertEq(psmBalanceAfter_Bob, psmAmount + result);
        assertEq(_FUNDING_MIN_AMOUNT, remainingPSM + result);
    }

    function testSuccess_sellPortalEnergyWBTC() public {
        helper_stake10WBTC();

        (,,,, uint256 peBalanceBefore,,) = portal_WBTC.getUpdateAccount(Alice, 0, true);
        uint256 psmBalanceBefore_Bob = psm.balanceOf(Bob);

        vm.prank(Alice);
        portal_WBTC.sellPortalEnergy(Bob, peBalanceBefore, 1, block.timestamp);

        uint256 reserve0 = _FUNDING_MIN_AMOUNT;
        uint256 reserve1 = _TARGET_CONSTANT_WBTC / _FUNDING_MIN_AMOUNT;
        uint256 result = (peBalanceBefore * reserve0) / (peBalanceBefore + reserve1 + 1);

        (,,,, uint256 peBalanceAfter,,) = portal_WBTC.getUpdateAccount(Alice, 0, true);
        uint256 psmBalanceAfter_Bob = psm.balanceOf(Bob);

        uint256 remainingPSM = psm.balanceOf(address(virtualLP));

        uint256 maxLock = portal_WBTC.maxLockDuration();
        uint256 stakedTokens = 10;
        uint256 tokenPrice = 61500;
        uint256 stakedValue = stakedTokens * tokenPrice;
        uint256 usdUpfrontYield = result / 1000e18;
        uint256 upfrontYieldROI = (usdUpfrontYield * 10000) / stakedValue;
        uint256 upfrontYieldAPR = (upfrontYieldROI * SECONDS_PER_YEAR) / maxLock;

        console2.log("staked USD value:", stakedValue);
        console2.log("Sold PE by Alice:", peBalanceBefore / 1e18);
        console2.log("Bobs PSM balance gain:", result / 1e18);
        console2.log("upfront yield value in USD", usdUpfrontYield);
        console2.log("upfront yield ROI (x100)", upfrontYieldROI);
        console2.log("upfront yield APR (x100)", upfrontYieldAPR);
        console2.log("Remaining PSM in vLP:", remainingPSM / 1e18);

        assertEq(peBalanceAfter, 0);
        assertEq(psmBalanceBefore_Bob, psmAmount);
        assertEq(psmBalanceAfter_Bob, psmAmount + result);
        assertEq(_FUNDING_MIN_AMOUNT, remainingPSM + result);
    }
}
