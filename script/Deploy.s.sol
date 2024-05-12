// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {PortalV2MultiAsset} from "src/PortalV2MultiAsset.sol";
import {VirtualLP} from "src/VirtualLP.sol";

contract Deploy is Script {
    function setUp() public {}

    function run()
        public
        returns (
            address vLP_address,
            address portalAddress_USDC,
            address portalAddress_USDCE,
            address portalAddress_ETH,
            address portalAddress_WBTC,
            address portalAddress_ARB,
            address portalAddress_LINK
        )
    {
        // Principal token addresses
        address USDC_ADDRESS = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // pid 5
        address USDCE_ADDRESS = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; // pid 4
        address ETH_ADDRESS = 0x0000000000000000000000000000000000000000; // pid 10
        address WBTC_ADDRESS = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f; // pid 12
        address ARB_ADDRESS = 0x912CE59144191C1204E64559FE8253a0e49E6548; // pid 11
        address LINK_ADDRESS = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4; // pid 16

        // Vault addresses
        // address USDC_WATER = 0x9045ae36f963b7184861BDce205ea8B08913B48c;
        // address USDCE_WATER = 0x806e8538FC05774Ea83d9428F778E423F6492475;
        // address ETH_WATER = 0x8A98929750e6709Af765F976c6bddb5BfFE6C06c;
        // address WBTC_WATER = 0x4e9e41Bbf099fE0ef960017861d181a9aF6DDa07;
        // address ARB_WATER = 0x175995159ca4F833794C88f7873B3e7fB12Bb1b6;
        // address LINK_WATER = 0xFF614Dd6fC857e4daDa196d75DaC51D522a2ccf7;

        // Constant Products
        uint256 USDC_product = 133333333333333 * 1e36;
        uint256 ETH_product = 44444444444 * 1e36;
        uint256 WBTC_product = 2168021680 * 1e36;
        uint256 ARB_product = 133333333333333 * 1e36;
        uint256 LINK_product = 9523809523809 * 1e36;

        vm.startBroadcast();
        // Step 1: Deploy the VirtualLP with constructor values
        VirtualLP vLP = new VirtualLP(0xa0BFD02a7a47CBCA7230E03fbf04A196C3E771E3, 1e24, 604800, 2e26);

        // Step 2: create the bToken of the VirtualLP
        vLP.create_bToken();

        // Step 3: Deploy all Portals with respective constructor values
        vLP_address = address(vLP);

        PortalV2MultiAsset USDC_portal = new PortalV2MultiAsset(
            vLP_address,
            USDC_product,
            USDC_ADDRESS,
            6,
            "USD Coin",
            "USDC",
            "ipfs://bafkreihjtvd2huidigr6jtpssfbuo6qktz6xek3vywkeqykshl5p5tx2gi"
        );
        PortalV2MultiAsset USDCE_portal = new PortalV2MultiAsset(
            vLP_address,
            USDC_product,
            USDCE_ADDRESS,
            6,
            "Bridged USDC",
            "USDC.e",
            "ipfs://bafkreidrjgxmh73goadpgmxw4364wlm5so7t73aexc6lxlkoji2i54mpny"
        );
        PortalV2MultiAsset ETH_portal = new PortalV2MultiAsset(
            vLP_address,
            ETH_product,
            ETH_ADDRESS,
            18,
            "Ether",
            "ETH",
            "ipfs://bafkreieun4odrood5hku6aqtcisqeplyo5wzswunnye3tew65e3t7t5vcy"
        );
        PortalV2MultiAsset WBTC_portal = new PortalV2MultiAsset(
            vLP_address,
            WBTC_product,
            WBTC_ADDRESS,
            8,
            "Wrapped BTC",
            "WBTC",
            "ipfs://bafkreien27jkip4ip6cbdl7hgujwod35z7wi36akzflmwlkutyg4rlv4qu"
        );
        PortalV2MultiAsset ARB_portal = new PortalV2MultiAsset(
            vLP_address,
            ARB_product,
            ARB_ADDRESS,
            18,
            "Arbitrum",
            "ARB",
            "ipfs://bafkreidzkg7qdqstl3vp7atabc5nlb3vjjpleww74ztcl7emydr6sc4gri"
        );
        PortalV2MultiAsset LINK_portal = new PortalV2MultiAsset(
            vLP_address,
            LINK_product,
            LINK_ADDRESS,
            18,
            "ChainLink Token",
            "LINK",
            "ipfs://bafkreiflvsypwj5dvutww4pdct3a6yu7wqemu4aac75ubmg5jumkhy47ia"
        );

        // get the Portal addresses to return
        portalAddress_USDC = address(USDC_portal);
        portalAddress_USDCE = address(USDCE_portal);
        portalAddress_ETH = address(ETH_portal);
        portalAddress_WBTC = address(WBTC_portal);
        portalAddress_ARB = address(ARB_portal);
        portalAddress_LINK = address(LINK_portal);

        // Step 4: Create the Portal Position NFT contract of each Portal
        USDC_portal.create_portalNFT();
        USDCE_portal.create_portalNFT();
        ETH_portal.create_portalNFT();
        WBTC_portal.create_portalNFT();
        ARB_portal.create_portalNFT();
        LINK_portal.create_portalNFT();

        // Step 5: Create the Portal Energy ERC20 contract of each Portal
        USDC_portal.create_portalEnergyToken();
        USDCE_portal.create_portalEnergyToken();
        ETH_portal.create_portalEnergyToken();
        WBTC_portal.create_portalEnergyToken();
        ARB_portal.create_portalEnergyToken();
        LINK_portal.create_portalEnergyToken();

        // Step 6: Register deployed Portals in VirtualLP contract
        // This must be performed from the manager EOA (separate step, manual)
        // vLP.registerPortal(portalAddress_USDC, USDC_ADDRESS, USDC_WATER);
        // vLP.registerPortal(portalAddress_USDCE, USDCE_ADDRESS, USDCE_WATER);
        // vLP.registerPortal(portalAddress_ETH, ETH_ADDRESS, ETH_WATER);
        // vLP.registerPortal(portalAddress_WBTC, WBTC_ADDRESS, WBTC_WATER);
        // vLP.registerPortal(portalAddress_ARB, ARB_ADDRESS, ARB_WATER);
        // vLP.registerPortal(portalAddress_LINK, LINK_ADDRESS, LINK_WATER);

        vm.stopBroadcast();
    }
}
