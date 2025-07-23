# Decentralized Accommodation Platform Smart Contract

A comprehensive peer-to-peer accommodation booking platform built on the Stacks blockchain, enabling direct transactions between hosts and guests without traditional intermediaries.

## Overview

This smart contract implements a decentralized alternative to traditional accommodation booking platforms, featuring property listings, booking management, payment processing, reviews, and dispute resolution - all managed through blockchain technology.

## Key Features

### **Property Management**
- Property listing creation and management
- Host staking requirements for quality assurance
- Property availability tracking
- Amenities and location information storage

### **Booking System** 
- Secure booking creation and confirmation
- Automated payment processing with escrow
- 24-hour cancellation window
- Maximum 7-night booking limitation

### **Financial Management**
- 5% platform fee on all bookings
- Automatic payment distribution to hosts
- Host staking system (minimum 1 STX)
- Platform fee collection and withdrawal

### **Review & Rating System**
- Post-booking review submission
- 1-5 star rating system
- Property rating aggregation
- Comment system for detailed feedback

### **Dispute Resolution**
- 7-day dispute window after checkout
- Admin-mediated dispute resolution
- Booking status tracking throughout disputes

### **User Profiles**
- Username and email registration
- Reputation scoring system
- Booking history tracking
- Verification status management

## Contract Constants

```clarity
PLATFORM_FEE: 5%           // Platform commission
CANCELLATION_WINDOW: 24h   // Free cancellation period
DISPUTE_WINDOW: 7d         // Time to initiate disputes
MIN_STAKE: 1 STX          // Minimum host stake requirement
```

## Core Functions

### Host Functions

#### `stake-as-host(amount)`
- **Purpose**: Stake STX tokens to become a verified host
- **Requirement**: Minimum 1 STX stake
- **Returns**: Staked amount

#### `create-property(...)`
- **Purpose**: List a new property for booking
- **Requirements**: Must be staked host
- **Parameters**: Title, description, location, price, max guests, amenities
- **Returns**: Property ID

#### `update-property-status(property-id, is-active)`
- **Purpose**: Activate/deactivate property listings
- **Authorization**: Property owner only

#### `confirm-booking(booking-id)`
- **Purpose**: Confirm pending guest bookings
- **Effect**: Transfers payment to host, updates booking status

### Guest Functions

#### `create-booking(property-id, check-in, check-out, total-guests)`
- **Purpose**: Book accommodation for specified dates
- **Requirements**: Property must be available, payment in full
- **Limitations**: Maximum 7-night bookings
- **Returns**: Booking ID

#### `cancel-booking(booking-id)`
- **Purpose**: Cancel booking within 24-hour window
- **Effect**: Full refund to guest, releases dates

### Review System

#### `submit-review(booking-id, rating, comment)`
- **Purpose**: Submit review after completed booking
- **Requirements**: Must be guest or host, booking completed
- **Rating**: 1-5 stars
- **Effect**: Updates property average rating

### Dispute Management

#### `initiate-dispute(booking-id, reason)`
- **Purpose**: Start dispute resolution process
- **Window**: Within 7 days of checkout
- **Authorization**: Guest or host

### Profile Management

#### `create-profile(username, email)`
- **Purpose**: Create user profile for platform interaction
- **Initial**: 100 reputation score, unverified status

## Admin Functions

#### `resolve-dispute(booking-id, resolution)`
- **Authorization**: Contract owner only
- **Purpose**: Resolve pending disputes

#### `withdraw-platform-fees(amount)`
- **Authorization**: Contract owner only
- **Purpose**: Withdraw accumulated platform fees

## Read-Only Functions

### Property Information
- `get-property(property-id)` - Retrieve property details
- `get-property-availability(property-id, date)` - Check date availability
- `get-property-rating(property-id)` - Get average rating
- `calculate-booking-cost(property-id, check-in, check-out)` - Price calculator

### Booking Information
- `get-booking(booking-id)` - Retrieve booking details
- `get-review(booking-id)` - Get booking review
- `get-dispute(booking-id)` - Get dispute information

### User Information
- `get-user-profile(user)` - Retrieve user profile
- `get-host-stake(host)` - Get host stake amount

### Platform Information
- `get-platform-balance()` - View platform fee balance

## Data Structures

### Property Structure
```clarity
{
  host: principal,
  title: string-ascii 100,
  description: string-ascii 500,
  location: string-ascii 100,
  price-per-night: uint,
  max-guests: uint,
  amenities: list 10 string-ascii 50,
  is-active: bool,
  total-bookings: uint,
  total-rating: uint,
  review-count: uint,
  created-at: uint
}
```

### Booking Structure
```clarity
{
  property-id: uint,
  guest: principal,
  host: principal,
  check-in: uint,
  check-out: uint,
  total-guests: uint,
  total-amount: uint,
  platform-fee: uint,
  status: string-ascii 20,
  created-at: uint,
  confirmed-at: optional uint,
  cancelled-at: optional uint
}
```

## Booking Flow

1. **Host Registration**: Stake minimum 1 STX and create property listing
2. **Guest Booking**: Select dates, pay full amount (held in escrow)
3. **Host Confirmation**: Host confirms booking, payment released
4. **Stay Completion**: Booking automatically marked as completed
5. **Review Period**: Both parties can submit reviews
6. **Dispute Window**: 7-day period for dispute initiation if needed

## Security Features

- **Escrow System**: Payments held in contract until confirmation
- **Staking Mechanism**: Hosts must stake STX for accountability
- **Time-locked Operations**: Cancellation and dispute windows
- **Authorization Checks**: Function-level access controls
- **Payment Validation**: Automatic fee calculations and transfers

## Error Codes

| Code | Description |
|------|-------------|
| 100 | Not authorized |
| 101 | Property not found |
| 102 | Booking not found |
| 103 | Invalid dates |
| 104 | Property not available |
| 105 | Insufficient payment |
| 106 | Booking already exists |
| 107 | Cancellation window expired |
| 108 | Already reviewed |
| 109 | Invalid rating |
| 110 | Dispute window expired |
| 111 | Insufficient stake |
| 112 | Property already exists |

## Deployment

1. Deploy contract to Stacks blockchain
2. Contract owner is set to deployer address
3. Initialize with appropriate STX balance for operations
4. Begin accepting host registrations and property listings

## Usage Examples

### Creating a Property Listing
```clarity
(contract-call? .accommodation-platform create-property 
  "Cozy Downtown Apartment"
  "Beautiful 2BR apartment in city center with modern amenities"
  "New York, NY"
  u100000000  ;; 100 STX per night
  u4          ;; Max 4 guests
  (list "WiFi" "Kitchen" "Parking" "AC"))
```

### Making a Booking
```clarity
(contract-call? .accommodation-platform create-booking
  u1          ;; Property ID
  u1640995200 ;; Check-in timestamp
  u1641254400 ;; Check-out timestamp (3 days later)
  u2)         ;; 2 guests
```