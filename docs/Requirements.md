# Audit Techspec for Possum Portals V2

## Table of Contents
- [Audit Techspec for Possum Portals V2](#audit-techspec-for-possum-portals-v2)
  - [Table of Contents](#table-of-contents)
  - [Project Overview](#project-overview)
  - [Functional Requirements](#functional-requirements)
    - [1.1. Roles \& Authorizations](#11-roles--authorizations)
    - [1.2. Features](#12-features)
    - [1.3. Business Logic](#13-business-logic)
    - [1.4. Use Cases](#14-use-cases)
  - [Technical requirements](#technical-requirements)
    - [2.1. Architecture Overview](#21-architecture-overview)
    - [2.2. Contract Information](#22-contract-information)
      - [2.1. Deployment Instructions](#21-deployment-instructions)
  - [2.2. Architecture Overview](#22-architecture-overview)
  - [2.3. Contract Information](#23-contract-information)
    - [2.3.1. VirtualLP.sol](#231-virtuallpsol)
    - [2.3.2. PortalV2MultiAsset.sol](#232-portalv2multiassetsol)
    - [2.3.3. MintBurnToken.sol](#233-mintburntokensol)
    - [2.3.4. PortalNFT.sol](#234-portalnftsol)

## Project Overview
The primary purpose of Possum Portals (“Portals”) is to enable users to receive upfront, fixed-rate yield from DeFi staking opportunities instead of accruing yield over time at an unpredictable, variable rate. Further, Portals enable duration-independent speculation on expected future yield rates of the composed yield sources (external protocols). Lastly, the funding mechanism of Portals allows PSM holders to deploy their tokens to a productive use case by lending them to the Portal for a potential profit.

## Functional Requirements

### 1.1. Roles & Authorizations
The Portals contract `PortalV2MultiAsset.sol` does not give any authorizations. All critical parameters are supposed to be set at deployment and be immutable from there onwards.
The `vLP` contract `VirtualLP.sol` grants a temporary owner access to a team address which can register new Portals in the `vLP`. This is required to allow multiple Portals to share the capital of a single `vLP` and therefore increase capital efficiency. The ownership has a hard-coded duration after which anyone can remove the owner.
The `vLP` contract only allows registered addresses (Portals) to interact with its capital management related functions. This access control is mandatory to prevent malicious, non-registered addresses from draining all PSM and even access staked user funds. Since the Portal contracts are immutable, this access does not pose additional risk to users as long as the `vLP` owner only registers immutable Portals.
The ownership duration is set to 9 days, just enough time to verify that everything works as intended. (7 days of funding phase + 2 days of normal operation)
In summary, the following roles are present in the system:
- Owner of `vLP`: Can register new Portals
- Registered Portals: Can call protected functions in the `vLP`
- Portal Users: Stake tokens, receive upfront yield or trade Portal Energy to speculate on yield rates
- VirtualLP Users: lend PSM to the LP in exchange for potential profit, trigger arbitrage to extract the balance of an ERC20 token from the `vLP` in exchange for PSM.

### 1.2. Features
The `VirtualLP.sol` contract has the following features:
- Register new Portals (owner)
- Send PSM to a user (registered Portal)
- Deposit assets into the external protocol (registered Portal)
- Withdraw assets from the external protocol (registered Portal)
- Collect lending profits from the external protocol into the `vLP` (anyone)
- Increase the spending allowance to underlying lending vaults (anyone)
- Arbitrage, extract the balance of a specific token in exchange for PSM (anyone)
- Activate the `vLP`, i.e., end the funding phase (anyone)
- Contribute PSM to fund the starting balance of the `vLP` (anyone)
- Withdraw one’s own funding contribution before the funding phase ends (anyone)
- Redeem the bootstrapping token [“bToken”] for PSM (anyone)
- Create the bToken (anyone, only once)

The `PortalV2MultiAsset.sol` contract has the following features:
- Stake assets (anyone)
- Unstake assets (anyone)
- Create the Portal NFT contract (anyone, only once)
- Mint an NFT position (anyone who has an active stake)
- Redeem an NFT position (anyone)
- Buy & Sell Portal Energy internal balances (anyone)
- Create the Portal Energy Token (anyone, only once)
- Mint & burn Portal Energy Tokens for internal balance (anyone)
- Increase the maximum lock duration of stakes (anyone, time-dependent)

### 1.3. Business Logic
Upon release of Portals V2 on Arbitrum, users will be able to receive fixed yield, instantly (upfront) for staking USDC, USDC.e, ETH, ARB, WBTC, and LINK.
The staked assets are redirected to the lending vaults of Vaultka, which earn back the yield that is paid out to users upfront. To earn back the yield, assets are locked in Portals for a time specified by the user, up to a maximum duration. The longer assets are locked, the more yield a user can withdraw upfront.
Assets unlock linearly, meaning the user doesn’t need to wait the full lock duration to get access to some of the capital. However, withdrawing capital when there is “time debt” left, prolongs the lock duration on the remaining capital proportionally.

Locked assets can also be unlocked early by purchasing the required amount of Portal Energy (PE) to repay the time debt.
PE is the contract-internal unit of account for the time value of staked assets. It does not need to exist as a token to be used as intended, however, users have the ability to mint PE as ERC20 representation. PE tokens can be burned (redeemed) to equally increase a user’s internal PE balance.

Portals feature a “no-fee” policy. Users can transact without value extraction caused by a protocol fee. However, to protect the `vLP` from a certain kind of sandwich attack, buying PE from the `vLP` incurs a 1% penalty on the received PE. This penalty is “burned”, i.e., indirectly redistributed to all users of the Portal.

Not only can Portal users mint their PE balance as ERC20 tokens but they can also mint their entire staking position as a transferable NFT. This NFT contains the access to the staked capital of the user as well as their PE balance and the user loses direct access. The NFT also continues to earn PE over time. To get access to the represented staking position, the NFT must be redeemed in the Portal (burned).

Portals introduce the concept of time value of staked assets by treating staked time and staked amounts as fungible. The representation of this time value is Portal Energy (PE), a contract-internal unit of account. (time * amount = PE)
The virtual liquidity pool (`vLP`) of Portals sits at the heart of the business logic. It uses the constant product formula, x * y = k, to determine the amount of PSM paid out as upfront yield when users sell PE. The liquidity pool is considered “virtual” because there is only one token present in the contract (PSM). PE remains a contract-internal variable and is not directly tracked by the `vLP`. Instead, the constant product (k) is fixed at LP activation, allowing the indirect calculation of PE on every swap.

To pay upfront yield, PE is swapped for PSM in the `vLP`. On the flipside, yields earned by the staked assets are converted to PSM via a permissionless arbitrage system that refills the `vLP`.

The arbitrage system uses the economic interests of external actors to ensure a permissionless and competitive refilling of the `vLP` without the need for price oracles and therefore, the continuous availability of upfront yield for stakers. Arbitrageurs can provide a fixed amount of PSM tokens to withdraw the entire balance of a particular ERC20 in the `vLP`. Therefore, if the value of the balance – or claimable lending profit - of an ERC20 in the `vLP` is greater than the value of the fixed PSM amount, arbitrage bots will trigger all necessary transactions to make a risk-free profit.

Considering the well-known concept of time value of money, it can be expected that, upon further maturation of the DeFi market and increasing presence of rational actors, payouts of upfront yield rates will be lower than expected yield rates over the locking period. This ensures economic sustainability and nominal growth of Portals.
The `vLP` is pre-funded by individuals who can contribute PSM during the funding phase in exchange for bootstrapping tokens (`bTokens`).

`bTokens` represent a fixed interest, indefinite-maturity loan to the Portal and can be redeemed for PSM from the `rewardPool`. `bTokens` can only be redeemed if sufficient PSM are available in the `rewardPool`. There is an upper limit to the redemption value of `bTokens` defined by 1 `bToken` = 1 PSM. This ratio starts much lower, e.g., at 10 `bTokens` = 1 PSM, and funders receive an equivalent large amount of `bTokens` during the funding phase, i.e., 1 PSM => 10 `bTokens`. (Minting at breakeven value)

The `rewardPool` receives a share of the PSM arbitrage amount until all debt has been repaid (all `bTokens` are burned) or until the `rewardPool` is big enough to service all redemptions of remaining `bTokens` at the maximum possible profit.

### 1.4. Use Cases
Fundamentally, Portals allow users to increase their financial exposure to assets of their choice without any risk of liquidation. Unlike a loan, upfront yield doesn’t need to be paid back and doesn’t incur any type of fee or negative interest.
Upfront yield is received as PSM tokens that can be exchanged for any other token on DEXes. Hence, use cases span across all scenarios where additional capital is desired.
Some exemplary use cases:
- Speculating on memecoins without risking the initial capital
- Engaging in derivatives trading without risking the initial capital
- Hedging one’s portfolio without reducing the value of the portfolio
- Paying for real-world bills without selling the crypto portfolio

## Technical requirements

### 2.1. Architecture Overview
The project has been developed with Solidity language, using Foundry as a development environment.
OpenZeppelin libraries are used in the Project. Additional information can be found in their GitHub. (https://github.com/OpenZeppelin/openzeppelin-contracts)
The project structure follows the standard Foundry template. It contains contracts and tests in their respective folders. There are no scripts used by the project.

The folder `./src` contains the relevant contracts:
- `MintBurnToken.sol` -> a ERC20 contract with permit and burnable extension, mintable by owner
- `PortalNFT.sol` -> an NFT contract with custom additional code to allow the transfer of staked positions in the Portal.
- `PortalV2MultiAsset.sol` -> contains the main business logic related to upfront yield. This is the contract most users interact with.
- `VirtualLP.sol` -> The shared, virtual liquidity pool that facilitates the payout of upfront yield and the recovery of yield over time. Hosts the integration of the external protocol that generates the yield on staked user assets.

Further, interfaces to integrate with external contracts are provided in `./src/interfaces`.
A combined unit and integration test can be found in `./test`. To run the tests successfully, one has to make a fork of the Arbitrum main net, for example by typing into the terminal: 
`$forge test --fork-url https://arb-mainnet.g.alchemy.com/v2/[YOUR_API_KEY]`

Expanded fuzz testing and formal verification can be found in a separate, public repository: https://github.com/shieldify-security/Portal-V2

### 2.2. Contract Information

#### 2.1. Deployment Instructions
The following instructions assume that the protocol is deployed on Arbitrum main net and that the staking tokens (principal) already exist. If the protocol is deployed on a test network, the principal tokens must be deployed first. The code is compiled with solidity 0.8.19 and OpenZeppelin libraries of version 4.9.6 are used to meet the requirements of Arbitrum.

**Step 1: Deploy the contract VirtualLP from VirtualLP.sol.**
The constructor values intended for Arbitrum main net are:
- `_owner = 0xa0BFD02a7a47CBCA7230E03fbf04A196C3E771E3` (deployer EOA)
- `_AMOUNT_TO_CONVERT = 100000e18` (100k PSM tokens)
- `_FUNDING_PHASE_DURATION = 604800` (7 days)
- `_FUNDING_MIN_AMOUNT = 500000000e18` (500M PSM tokens)

**Step 2: Create bTokens**
Call the function `create_bToken()` in the recently deployed VirtualLP contract. This will deploy a standard ERC20 with the burnable extension and the correct name & symbol. The function can only be called once.

**Step 3: Deploy the individual Portals from PortalV2MultiAsset.sol**

There are 6 different Portals planned for main net release that will be connected to the same VirtualLP. 

The constructor value that remains constant for all Portals:
- `_VIRTUAL_LP` = address of the recently deployed VirtualLP contract

The individual constructor values:

**USDC Portal**
- `_CONSTANT_PRODUCT` = 
- `_PRINCIPAL_TOKEN_ADDRESS` = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831
- `_DECIMALS` = 6
- `_PRINCIPAL_NAME` = USD Coin
- `_PRINCIPAL_SYMBOL` = USDC
- `_META_DATA_URI` = ipfs://bafkreihjtvd2huidigr6jtpssfbuo6qktz6xek3vywkeqykshl5p5tx2gi

**USDC.e Portal**
- `_CONSTANT_PRODUCT` = 
- `_PRINCIPAL_TOKEN_ADDRESS` = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8
- `_DECIMALS` = 6
- `_PRINCIPAL_NAME` = Bridged USDC
- `_PRINCIPAL_SYMBOL` = USDC.e
- `_META_DATA_URI` = ipfs://bafkreidrjgxmh73goadpgmxw4364wlm5so7t73aexc6lxlkoji2i54mpny

**ETH Portal**
- `_CONSTANT_PRODUCT` = 
- `_PRINCIPAL_TOKEN_ADDRESS` = 0x0000000000000000000000000000000000000000
- `_DECIMALS` = 18
- `_PRINCIPAL_NAME` = Ether
- `_PRINCIPAL_SYMBOL` = ETH
- `_META_DATA_URI` = ipfs://bafkreieun4odrood5hku6aqtcisqeplyo5wzswunnye3tew65e3t7t5vcy

**WBTC Portal**
- `_CONSTANT_PRODUCT` =
- `_PRINCIPAL_TOKEN_ADDRESS` = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f
- `_DECIMALS` = 8
- `_PRINCIPAL_NAME` = Wrapped BTC
- `_PRINCIPAL_SYMBOL` = WBTC
- `_META_DATA_URI` = ipfs://bafkreien27jkip4ip6cbdl7hgujwod35z7wi36akzflmwlkutyg4rlv4qu

**ARB Portal**
- `_CONSTANT_PRODUCT` =
- `_PRINCIPAL_TOKEN_ADDRESS` = 0x912CE59144191C1204E64559FE8253a0e49E6548
- `_DECIMALS` = 18
- `_PRINCIPAL_NAME` = Arbitrum
- `_PRINCIPAL_SYMBOL` = ARB
- `_META_DATA_URI` = ipfs://bafkreidzkg7qdqstl3vp7atabc5nlb3vjjpleww74ztcl7emydr6sc4gri

**LINK Portal**
- `_CONSTANT_PRODUCT` =
- `_PRINCIPAL_TOKEN_ADDRESS` = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4
- `_DECIMALS` = 18
- `_PRINCIPAL_NAME` = ChainLink Token
- `_PRINCIPAL_SYMBOL` = LINK
- `_META_DATA_URI` = ipfs://bafkreiflvsypwj5dvutww4pdct3a6yu7wqemu4aac75ubmg5jumkhy47ia

**Step 4: Create Portal Position NFT**

In each deployed Portal, call the function `create_PortalNFT()`. This will deploy the PortalNFT contract with the information provided in the constructor of the Portal (name, symbol, meta data). The function can only be called once.

**Step 5: Create Portal Energy Tokens**

In each deployed Portal, call the function `create_portalEnergyToken()`. This will deploy the ERC20 token version of Portal Energy and enables users to mint their internal PE balance as a standard token.

**Step 6: Register deployed Portals in VirtualLP contract**

To enable upfront yield functionality of Portals, they must be connected to the VirtualLP contract. Specifically, they must be given permission to call the protected functions `PSM_sendToPortalUser()`, `depositToYieldSource()` and `withdrawFromYieldSource()` that manage the capital flows between users and the integrated yield source (Vaultka).

Only the owner of the VirtualLP can register Portals for security reasons. The owner can be revoked by anyone after the hardcoded ownership duration has expired. (Ownership is only required for setting up the VirtualLP)

## 2.2. Architecture Overview

The following chart provides a general view of the system and the interactions between the different components.
[Zoomable miro board](https://miro.com/app/board/uXjVKWfs7x4=/?share_link_id=724769526865)

![Diagram](https://github.com/PossumLabsCrypto/PortalsV2/blob/master/docs/Architecture.png)

## 2.3. Contract Information

This section contains detailed information about the contracts used in the project.

### 2.3.1. VirtualLP.sol

This contract receives ERC20 from the Portal contract that are staked by users and then stakes them into the external Vault contracts to generate yield. It also holds PSM tokens that are necessary to pay upfront yield to Portal users. This mechanism utilizes the constant product formula x * y = k to ensure that there is always some amount of PSM available to pay out as yield.

The contract undergoes a funding phase at whose end the contract becomes “active”, meaning that funding related functions cannot be called anymore but normal functionality like paying upfront yield or executing arbitrage become possible. The flow is separated into funding phase and active phase.

**Funding phase:**

1. **Contract deployment and preparation**: The contract is deployed, specifying the necessary parameters in the constructor as mentioned above. Afterwards the bToken is deployed by the VirtualLP which is a requirement to enable funding contributions. The Portal contracts are deployed and registered in the vLP by the owner.
2. **Funding**: Anyone can contribute PSM to increase the funding balance of the vLP. In exchange, funders receive bTokens. During the funding phase, bTokens can be burned to withdraw funding. This is not possible anymore after the vLP got activated.
3. **Activation**: After the funding time has passed or after the minimum funding amount was reached – whichever comes last – anyone can activate the vLP, transitioning the system into the active phase. The funding phase ends.

**Active phase:**

1. **Access**: The system becomes usable for all user groups. Upfront yield can be paid to stakers via `PSM_sendToPortalUser()`.
2. **External integration**: Registered Portals can call `depositToYieldSource()` and `withdrawToYieldSource()` to deposit or withdraw the staked capital of users. Withdrawing is subject to capital availability in the external lending vault.
3. **bToken redemption**: Funders are now able to redeem their bTokens for PSM via `burnBtokens()` if the reward pool has sufficient funds available. bTokens linearly increase in value over time, irrespective of the available PSM in the reward pool. The reward pool continues to grow but redeeming bTokens is a first come, first serve situation.
4. **Arbitrage**: Anyone can claim profit for the vLP generated in the external lending Vaults via `collectProfitOfPortal()`. These tokens, and any other tokens with a few exceptions can be exchanged for a fixed amount of PSM via `convert()`. This refills the vLP and allows continuous payout of upfront yield.
5. **Removing the owner**: Anyone can call `removeOnwer()`, transitioning the system to an immutable state.

There are some getter functions and utility functions that facilitate required steps for other functions:
- `getProfitOfPortal()` returns the current profit of a specific external lending vault that can be claimed by the vLP.
- `getBurnValuePSM()` returns the current redemption value of a specified amount of bTokens.
- `getBurnableBtokens()` returns the amount of bTokens that can be redeemed given the current amount of PSM in the reward pool.
- `increaseAllowanceVault()` increases the spending allowance of a specific tokens by its corresponding lending vault to the maximum uint256. This is required so that the vLP can deposit assets into the external protocol.

### 2.3.2. PortalV2MultiAsset.sol

Most of the Portal functionality can only work when the vLP is activated. This is ensured by the modifier `activeLP` on the functions `stake()`, `quoteBuyPortalEnergy()`, and `quoteSellPortalEnergy()`. This modifier is used sparsely because most other functions logically depend on the three functions mentioned above. For example, nobody can call `unstake()` successfully if there was no stake in the first place. However, there are a few functions mainly for preparation purposes that can be called.

1. **Preparation:**

- The constructor connects the Portal with the vLP by setting the correct address. It also sets the initial upfront yield rate indirectly by setting the constant product of PE/PSM. The principal token and its decimals are set as well as its name and symbol which are set manually to avoid contract malfunction when handling native ETH or weird ERC20 tokens. Lastly, the NFT metadata URI is set in the constructor.
- While the vLP is inactive, other preparation functions can be called like `create_PortalNFT()` which deploys an NFT contract with additional custom logic. Another important external function callable during this step is `create_portalEnergyToken()` which deploys an ERC20 contract that serves as transferrable representation of Portal Energy.

2. **Core functions:**

- Once the vLP got activated, users can `stake()` and `unstake()` the principal token. When staked, users earn Portal Energy over time, an internal unit of account that represents the time value of the staked assets and which can be exchanged for PSM in the vLP by calling `buy` or `sellPortalEnergy()`. Portal Energy can also be minted as ERC20 token via `mintPortalEnergyToken()`. These PE tokens can be redeemed to top up the internal PE balance of any user via `burnPortalEnergyToken()`.

3. **Periphery functions:**

- After some time, users can successfully call `updateMaxLockDuration()` to increase the maximum lock time of staked assets. This effectively increases the “time debt” (maxStakeDebt) of all users and equivalently increases the balance of Portal Energy to not affect the actual ongoing lock time of staked capital.
- Further, users can call `mintNFTposition()` to transfer their entire stake position’s state into a transferrable NFT. This NFT can be redeemed to retrieve the saved account information by whoever possesses the NFT and calls `redeemNFTposition()`.

**Important view functions:**

- `getUpdateAccount()` returns the simulated struct values of any user, updated to the current moment and given an amount to stake additionally or withdraw. For example, this is important to get the current amount of Portal Energy of a user.
- `quoteBuyPortalEnergy()` returns the amount of Portal Energy a user would receive given the specified amount of PSM input.
- `quoteSellPortalEnergy()` returns the amount of PSM tokens a user would receive given the specified amount of Portal Energy input.

### 2.3.3. MintBurnToken.sol

This contract is a simple ERC20 with an owner-controlled `mint()` function and the burnable extension.

### 2.3.4. PortalNFT.sol

This contract can save account information from a Portal user’s stake and also return this information upon redemption. It has a single metadata URI that is used for all ID mints because the relevant account data is saved inside the NFT itself instead of outsourcing this to metadata. The metadata is merely a generic description, name, and picture.

- The owner of this NFT contract is the Portal that deploys it. Only the owner can call `mint()` and `redeem()`.
- Portal stakes that got saved into an NFT continue to earn Portal Energy over time. To get the current account values of an NFT, anyone can call `getAccount()` and pass the token ID.
