# ForestGuard

A blockchain-powered platform for sustainable forestry management that ensures transparent timber tracking, combats illegal logging, and rewards eco-friendly practices — all on-chain, leveraging Clarity smart contracts on the Stacks blockchain.

---

## Overview

ForestGuard addresses real-world challenges in forestry, such as illegal logging, lack of supply chain transparency, and insufficient incentives for sustainable practices. By using blockchain, it enables verifiable tracking of timber from forest to market, carbon credit issuance for preserved areas, and community governance for forest management decisions. This promotes environmental accountability and rewards stakeholders for conservation efforts.

The platform consists of four main smart contracts that form a decentralized, transparent, and incentivized ecosystem for forest owners, loggers, buyers, and environmental organizations:

1. **Timber Tracking Contract** – Tracks timber provenance and certifies sustainable sourcing.
2. **Carbon Credit Contract** – Issues and trades carbon credits for preserved forest areas.
3. **Governance DAO Contract** – Allows stakeholders to vote on forest management proposals.
4. **Rewards Distribution Contract** – Distributes incentives to participants for eco-friendly actions.

---

## Features

- **Provenance tracking** for timber to prevent illegal logging  
- **Carbon credit minting** based on verified conservation data  
- **DAO governance** for community-driven forest policies  
- **Automated rewards** for sustainable practices like reforestation  
- **Oracle integration** for real-world data on forest health and activities  
- **Transparent audits** of all transactions and distributions  

---

## Smart Contracts

### Timber Tracking Contract
- Registers timber batches with unique IDs and metadata (origin, harvest date, sustainability certifications)
- Transfers ownership along the supply chain with immutable logs
- Verifies compliance via oracle-fed data on legal harvesting

### Carbon Credit Contract
- Mints fungible tokens representing carbon credits based on preserved acreage
- Enables trading, burning, or staking of credits
- Integrates with external verifiers for emission offset claims

### Governance DAO Contract
- Token-weighted voting on proposals (e.g., approving new harvesting zones or conservation plans)
- On-chain execution of approved decisions
- Quorum requirements and proposal submission mechanisms

### Rewards Distribution Contract
- Allocates tokens or credits to users for verified actions (e.g., planting trees, reporting illegal activities)
- Automated payouts from a shared treasury pool
- Anti-fraud checks using oracle data and multi-signature approvals

---

## Installation

1. Install [Clarinet CLI](https://docs.hiro.so/clarinet/getting-started)
2. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/forestguard.git
   ```
3. Run tests:
    ```bash
    npm test
    ```
4. Deploy contracts:
    ```bash
    clarinet deploy
    ```

## Usage

Each smart contract operates independently but integrates with others for a complete sustainable forestry ecosystem.
Refer to individual contract documentation for function calls, parameters, and usage examples.

## License

MIT License