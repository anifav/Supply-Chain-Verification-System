# Supply Chain Verification System

A blockchain-based platform for tracking product journeys from raw materials to consumer, built on the Stacks blockchain using Clarity smart contracts.

## Features

- Product journey tracking from creation to consumer
- Stakeholder verification system with incentives
- Reputation-based participant scoring
- Penalty system for false information
- Transparent and immutable supply chain records

## Contract Functions

### Core Functions
- `register-participant`: Register as a supply chain participant
- `create-product`: Create a new product for tracking
- `add-stage`: Add a new stage to product journey
- `verify-stage`: Verify a product stage (requires staking)
- `stake-tokens`: Stake STX tokens for verification rights
- `claim-reward`: Claim rewards for honest verification

### Administrative Functions
- `finalize-stage`: Finalize a product stage after verification
- `update-minimum-stake`: Update minimum stake requirement
- `emergency-pause-product`: Emergency pause for products

## Smart Contract Architecture

The contract manages:
- **Products**: Tracked items with stages and verification status
- **Participants**: Registered users with reputation scores
- **Verifications**: Proof of honest reporting with rewards/penalties
- **Stages**: Individual steps in the supply chain journey

## Getting Started

1. Clone this repository
2. Install Clarinet
3. Run `clarinet check` to validate contracts
4. Deploy to testnet/mainnet as needed

## Technical Details

### Contract Constants
- Minimum stake: 1 STX
- Verification period: 24 hours (~144 blocks)
- Maximum verifiers per stage: 10
- Reward percentage: 50% of stake

### Error Codes
- u100: Owner only operation
- u101: Resource not found
- u102: Unauthorized access
- u103: Resource already exists
- u104: Invalid stage
- u105: Insufficient stake
- u106: Already verified
- u107: Verification period ended

## Deployment

To deploy this contract:
1. Configure your network settings in Clarinet.toml
2. Use `clarinet deploy` for deployment
3. Verify contract functionality with included test scenarios

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is open source and available under the MIT License.