[Previous test content remains with additional tests...]

Clarinet.test({
    name: "Prevents excessive position sizes",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        let setup = chain.mineBlock([
            Tx.contractCall('trade_tide', 'create-account', [], wallet1.address)
        ]);
        
        let largeTrade = chain.mineBlock([
            Tx.contractCall('trade_tide', 'execute-trade', [
                types.ascii("AAPL"),
                types.uint(1000000),
                types.uint(15000),
                types.ascii("BUY")
            ], wallet1.address)
        ]);
        
        largeTrade.receipts[0].result.expectErr(106); // err-excessive-position
    }
});
