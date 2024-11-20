# EventCred: Cross-Platform POAP Smart Contract

## Table of Contents
- [Overview](#overview)
- [Features](#features)
- [Contract Structure](#contract-structure)
- [Key Functions](#key-functions)
- [Data Structures](#data-structures)
- [Setup and Deployment](#setup-and-deployment)
- [Usage Examples](#usage-examples)
- [Security Considerations](#security-considerations)
- [Contributing](#contributing)
- [License](#license)

## Overview

EventCred is a robust Proof of Attendance Protocol (POAP) smart contract implemented in Clarity for the Stacks blockchain. It enables event organizers to create and manage events, allows participants to register and receive unique badges, and implements a cross-platform reward system.

## Features

- **Event Creation and Management**: Organizers can create events with customizable parameters.
- **Cross-Platform Rewards**: Supports multiple platforms with alliance multipliers for enhanced rewards.
- **NFT Badges**: Attendees receive unique NFT badges as proof of attendance.
- **Reward Point System**: Participants earn and can redeem reward points.
- **Scalability**: Supports multiple events and large numbers of participants.

## Contract Structure

The contract is organized into several key components:

1. **Non-Fungible Tokens (NFTs)**
   - `event-badge`: Represents attendance at an event
   - `reward-token`: Represents redeemable rewards

2. **Data Maps**
   - `events`: Stores event details
   - `participant-badges`: Tracks badges owned by participants
   - `participant-rewards`: Manages reward points and cross-platform multipliers
   - `event-participants`: Lists participants for each event
   - `platform-alliances`: Stores alliance multipliers for different platforms

3. **Public Functions**
   - Event creation and management
   - Participant registration
   - Reward redemption

4. **Private Helper Functions**
   - Various utilities for calculations and data management

5. **Read-Only Functions**
   - Provide access to stored data

## Key Functions

### Administrative Functions

1. `create-platform-alliance`: Sets up alliances between platforms with multipliers.
2. `create-event`: Creates a new event with specified parameters.

### User Functions

1. `register-for-event`: Allows users to register for an event and receive a badge.
2. `redeem-rewards`: Enables users to redeem their accumulated reward points.

### Read-Only Functions

1. `get-participant-badges`: Retrieves badges owned by a participant.
2. `get-participant-rewards`: Retrieves reward information for a participant.
3. `get-event-details`: Retrieves details of a specific event.
4. `get-platform-alliance`: Retrieves alliance information for a platform.

## Data Structures

### Event
- `event-id`: Unique identifier for the event
- `name`: Name of the event (max 50 characters)
- `date`: Date of the event (as block height)
- `max-participants`: Maximum number of participants allowed
- `current-participants`: Current number of registered participants
- `reward-points`: Base reward points for the event
- `platform-tags`: List of platform tags associated with the event

### Participant Rewards
- `total-points`: Total reward points earned
- `redeemed-points`: Points that have been redeemed
- `cross-platform-multipliers`: List of multipliers from different platforms

## Setup and Deployment

1. Ensure you have the Clarity CLI installed.
2. Clone this repository: `git clone https://github.com/your-repo/eventcred.git`
3. Navigate to the project directory: `cd eventcred`
4. Deploy the contract using the Stacks CLI:
   ```
   stx deploy_contract eventcred.clar
   ```

## Usage Examples

### Creating a Platform Alliance
```clarity
(contract-call? .eventcred create-platform-alliance "platform1" u2)
```

### Creating an Event
```clarity
(contract-call? .eventcred create-event "My Event" u100000 u1000 u100 (list "platform1" "platform2"))
```

### Registering for an Event
```clarity
(contract-call? .eventcred register-for-event u1)
```

### Redeeming Rewards
```clarity
(contract-call? .eventcred redeem-rewards u50)
```

## Security Considerations

- The contract implements input validation to prevent invalid data entry.
- Access control is implemented for administrative functions.
- Arithmetic operations are checked to prevent overflows.

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request with your proposed changes.

