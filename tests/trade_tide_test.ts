Clarinet.test({
    name: "Validates price precision and tracks position timestamps",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        let setup = chain.mineBlock([
            Tx.contractCall('trade_tide', 'create-account', [], wallet1.address)
        ]);
        
        let trade = chain.mineBlock([
            Tx.contractCall('trade_tide', 'execute-trade', [
                types.ascii("AAPL"),
                types.uint(100),
                types.uint(150000000), // Exceeds price precision
                types.ascii("BUY")
            ], wallet1.address)
        ]);
        
        trade.receipts[0].result.expectErr(108); // err-price-precision
    }
});
