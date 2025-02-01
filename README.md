# TradeTide

A blockchain-based platform for simulated stock market trading and investing practice with comprehensive portfolio analytics.

## Features
- Create practice trading accounts with simulated funds
- Execute mock trades using real market data
- Advanced portfolio tracking and analytics
  - Position tracking with average price calculation
  - Realized and unrealized P&L monitoring
  - Trade performance metrics (win rate, average position size)
  - Fee tracking and analysis
- Real-time portfolio valuation
- Historical trade analysis

## Contract Functions
- Account creation and management
- Mock trading functionality with position tracking
  - Buy and sell order execution
  - Fee calculation and tracking
  - P&L calculation (realized and unrealized)
- Portfolio analytics
  - Position management
  - Performance metrics calculation
  - Trading statistics

## Analytics Features
- Position-level tracking
  - Current quantity
  - Average entry price
  - Unrealized P&L
  - Position duration
- Portfolio-level metrics
  - Total value
  - Realized/unrealized gains
  - Win rate
  - Average position size
  - Trading costs analysis

## Getting Started
1. Clone the repository
2. Set up Clarinet environment
3. Run tests using `clarinet test`
4. Deploy contract to testnet for testing

## Contributing
Pull requests are welcome. Please ensure tests pass before submitting.

## Technical Details
The platform uses Clarity smart contracts on the Stacks blockchain to ensure transparent and accurate trade execution and portfolio tracking. All calculations are performed on-chain for maximum transparency and reliability.
