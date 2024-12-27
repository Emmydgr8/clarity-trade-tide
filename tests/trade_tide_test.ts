import {
    Clarinet,
    Tx,
    Chain,
    Account,
    types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can create new trading account",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('trade_tide', 'create-account', [], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk().expectBool(true);
        
        // Verify account info
        let accountInfo = chain.mineBlock([
            Tx.contractCall('trade_tide', 'get-account-info', [types.principal(wallet1.address)], wallet1.address)
        ]);
        
        let account = accountInfo.receipts[0].result.expectOk().expectTuple();
        assertEquals(account['balance'], types.uint(1000000));
        assertEquals(account['active'], true);
    }
});

Clarinet.test({
    name: "Can execute mock trades",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        // Create account first
        let setup = chain.mineBlock([
            Tx.contractCall('trade_tide', 'create-account', [], wallet1.address)
        ]);
        
        // Execute buy trade
        let trade = chain.mineBlock([
            Tx.contractCall('trade_tide', 'execute-trade', [
                types.ascii("AAPL"),
                types.uint(10),
                types.uint(15000), // $150.00 per share
                types.ascii("BUY")
            ], wallet1.address)
        ]);
        
        trade.receipts[0].result.expectOk().expectBool(true);
        
        // Verify portfolio
        let portfolio = chain.mineBlock([
            Tx.contractCall('trade_tide', 'get-portfolio', [types.principal(wallet1.address)], wallet1.address)
        ]);
        
        let portfolioInfo = portfolio.receipts[0].result.expectOk().expectTuple();
        assertEquals(portfolioInfo['trade-count'], types.uint(1));
    }
});

Clarinet.test({
    name: "Cannot trade without account",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        let trade = chain.mineBlock([
            Tx.contractCall('trade_tide', 'execute-trade', [
                types.ascii("AAPL"),
                types.uint(10),
                types.uint(15000),
                types.ascii("BUY")
            ], wallet1.address)
        ]);
        
        trade.receipts[0].result.expectErr().expectUint(104); // err-no-account
    }
});

Clarinet.test({
    name: "Cannot trade with insufficient funds",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        // Create account
        let setup = chain.mineBlock([
            Tx.contractCall('trade_tide', 'create-account', [], wallet1.address)
        ]);
        
        // Try to buy more than account balance
        let trade = chain.mineBlock([
            Tx.contractCall('trade_tide', 'execute-trade', [
                types.ascii("AAPL"),
                types.uint(1000000),
                types.uint(15000),
                types.ascii("BUY")
            ], wallet1.address)
        ]);
        
        trade.receipts[0].result.expectErr().expectUint(101); // err-insufficient-funds
    }
});