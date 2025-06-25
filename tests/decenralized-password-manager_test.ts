import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "User registration test",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        const user1 = accounts.get("wallet_1")!;
        
        let block = chain.mineBlock([
            Tx.contractCall("password-manager", "register-user", [], user1.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectOk(), true);
    },
});

Clarinet.test({
    name: "Store and retrieve password test",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = accounts.get("wallet_1")!;
        
        // Register user first
        let block = chain.mineBlock([
            Tx.contractCall("password-manager", "register-user", [], user1.address)
        ]);
        
        // Store password
        block = chain.mineBlock([
            Tx.contractCall("password-manager", "store-password", [
                types.ascii("test-password-id"),
                types.ascii("encrypted-password-data"),
                types.ascii("example.com"),
                types.ascii("testuser")
            ], user1.address)
        ]);
        
        assertEquals(block.receipts[0].result.expectOk(), true);
        
        // Retrieve password
        block = chain.mineBlock([
            Tx.contractCall("password-manager", "get-password", [
                types.ascii("test-password-id")
            ], user1.address)
        ]);
        
        const passwordData = block.receipts[0].result.expectOk().expectSome();
        assertEquals(passwordData['website'], "example.com");
    },
});