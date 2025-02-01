import {
    Clarinet,
    Tx,
    Chain,
    Account,
    types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can create new trading account with enhanced portfolio tracking",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('trade_tide', 'create-account', [], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk().expectBool(true);
        
        let portfolio = chain.mineBlock([
            Tx.contractCall('trade_tide', 'get-portfolio', [types.principal(wallet1.address)], wallet1.address)
        ]);
        
        let portfolioInfo = portfolio.receipts[0].result.expectOk().expectTuple();
        assertEquals(portfolioInfo['total-value'], types.uint(1000000));
        assertEquals(portfolioInfo['realized-gains'], types.int(0));
        assertEquals(portfolioInfo['unrealized-gains'], types.int(0));
        assertEquals(portfolioInfo['win-rate'], types.uint(0));
    }
});

Clarinet.test({
    name: "Can execute trades with position tracking",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        // Create account
        let setup = chain.mineBlock([
            Tx.contractCall('trade_tide', 'create-account', [], wallet1.address)
        ]);
        
        // Execute buy trade
        let buyTrade = chain.mineBlock([
            Tx.contractCall('trade_tide', 'execute-trade', [
                types.ascii("AAPL"),
                types.uint(10),
                types.uint(15000),
                types.ascii("BUY")
            ], wallet1.address)
        ]);
        
        buyTrade.receipts[0].result.expectOk().expectBool(true);
        
        // Check position
        let position = chain.mineBlock([
            Tx.contractCall('trade_tide', 'get-position', [
                types.principal(wallet1.address),
                types.ascii("AAPL")
            ], wallet1.address)
        ]);
        
        let positionInfo = position.receipts[0].result.expectSome().expectTuple();
        assertEquals(positionInfo['quantity'], types.uint(10));
        assertEquals(positionInfo['avg-price'], types.uint(15000));
        
        // Execute sell trade
        let sellTrade = chain.mineBlock([
            Tx.contractCall('trade_tide', 'execute-trade', [
                types.ascii("AAPL"),
                types.uint(5),
                types.uint(16000),
                types.ascii("SELL")
            ], wallet1.address)
        ]);
        
        sellTrade.receipts[0].result.expectOk().expectBool(true);
        
        // Verify updated position
        let updatedPosition = chain.mineBlock([
            Tx.contractCall('trade_tide', 'get-position', [
                types.principal(wallet1.address),
                types.ascii("AAPL")
            ], wallet1.address)
        ]);
        
        let updatedPositionInfo = updatedPosition.receipts[0].result.expectSome().expectTuple();
        assertEquals(updatedPositionInfo['quantity'], types.uint(5));
    }
});

Clarinet.test({
    name: "Tracks fees and P&L correctly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        // Create account
        let setup = chain.mineBlock([
            Tx.contractCall('trade_tide', 'create-account', [], wallet1.address)
        ]);
        
        // Execute trade
        let trade = chain.mineBlock([
            Tx.contractCall('trade_tide', 'execute-trade', [
                types.ascii("AAPL"),
                types.uint(10),
                types.uint(15000),
                types.ascii("BUY")
            ], wallet1.address)
        ]);
        
        // Check portfolio metrics
        let portfolio = chain.mineBlock([
            Tx.contractCall('trade_tide', 'get-portfolio', [
                types.principal(wallet1.address)
            ], wallet1.address)
        ]);
        
        let portfolioInfo = portfolio.receipts[0].result.expectOk().expectTuple();
        assertEquals(portfolioInfo['total-fees'], types.uint(150)); // 0.1% of trade value
    }
});
