# FaaS (Farm as a Service) [![Open in Gitpod][gitpod-badge]][gitpod] [![Github Actions][gha-badge]][gha] [![Github Actions][gha-badge-lint]][gha] [![Hardhat][hardhat-badge]][hardhat]

[gitpod]: https://gitpod.io/#https://github.com/elkfinance/faas
[gitpod-badge]: https://img.shields.io/badge/Gitpod-Open%20in%20Gitpod-FFB45B?logo=gitpod
[gha]: https://github.com/elkfinance/faas/actions
[gha-badge]: https://github.com/elkfinance/faas/actions/workflows/contracts.yml/badge.svg
[gha-badge-lint]: https://github.com/elkfinance/faas/actions/workflows/code-quality-checks.yml/badge.svg
[hardhat]: https://hardhat.org/
[hardhat-badge]: https://img.shields.io/badge/Built%20with-Hardhat-FFDB1C.svg

FaaS (Farm as a Service) is a smart contract-based project that allows users to create their own FarmingRewards
contracts to distribute rewards to liquidity providers. This repository contains the Solidity contracts, tests, and
necessary scripts for the FaaS system.

This project was built with hardhat.

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Running Tests](#running-tests)
- [Usage](#usage)
- [Authors](#authors)
- [License](#license)

## Features

- Create FarmingRewards contracts for distributing rewards to liquidity providers
- Permissioned FarmingRewards contracts for added security and control
- Fee collection for creating new FarmingRewards contracts
- Integration with ElkFinance's ecosystem

## Architecture

FaaS is composed of several components, including staking/farming contracts that reward liquidity providers, staking
strategies that implement a universal interface to different kinds of staking tokens, staking/farming managers that make
it easy for users to interact with different farms, and factory contracts that facilitate the creation of new farms.

- IStakingRewards -> StakingRewards, which comes in different flavors:
  - StakingRewardsWithILP: support impermanent loss coverage payments for v2 LPs
  - ElkSingeStakingRewards: the final contract for single staking
  - ElkV2FarmingRewards: the final contract for farming with v2 LP
  - ElkV3FarmingRewards: the final contract for farming with v3 LP
- IStakingStrategy -> StakingStrategy, which includes the following subcontracts:
  - ERC20StakingStrategy: supports staking arbitrary ERC20 tokens
  - ERC20StakingStrategy: supports staking arbitrary ERC20 tokens and deposit/withdrawal fees
  - ERC721StakingStrategy: supports staking arbitrary ERC721 tokens
  - ElkV2StakingStrategy: supports staking v2 LPs
  - ElkV3StakingStrategy: supports staking v3 LPs
- Managers:
  - IStakeManager -> StakeManager: manages single stake
  - IElkV2FarmManager -> ElkV2FarmManager: manages v2 farms
  - IElkV3FarmManager -> ElkV3FarmManager: manages v3 farms
- Factories:
  - IStakeFactory -> StakeFactory: creates single stake
  - IElkV2FarmFactory -> ElkV2FarmFactory: creates v2 farms
  - IElkV3FarmFactory -> ElkV3FarmFactory: creates v3 farms

## Getting Started

Follow these instructions to set up the FaaS repository on your local machine.

### Prerequisites

- Node.js and npm (Node Package Manager) installed on your system. You can download Node.js from https://nodejs.org/.

### Installation

1. Clone the repository to your local machine:

```sh
git clone https://github.com/elkfinance/faas
```

2. Navigate to the project folder:

```sh
cd faas
```

3. Install the project dependencies:

```sh
npm install
```

### Running Tests

1. Run the tests:

```sh
npm run test
```

## Usage

The FaaS system is comprised of two main contracts: "ElkFarmFactory" (located at ./contracts/ElkFarmFactory.sol) and
"FarmingRewards" (located at ./contracts/FarmingRewards.sol). The ElkFarmFactory contract is the main contract that
users interact with to create new FarmingRewards contracts. The FarmingRewards contract is the contract that distributes
rewards to liquidity providers.

## Authors

- Seth <seth@elklabs.org>
- Baal <baal@elklabs.org>
- Elijah <elijah@elklabs.org>
- Snake <snake@elklabs.org>
- Real-Hansolo <real-hansolo@elklabs.org>

## License

See included LICENSE.
