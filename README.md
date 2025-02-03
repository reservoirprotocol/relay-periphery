# Relay

Relay is a protocol for executing cross-chain and same-chain swaps and calls.

## Token Swaps

The ApprovalProxy and RelayRouter enable users to execute token swaps (ERC20 <> ETH or ERC20 <> ERC20). There are three ways to execute swaps:

### 1. Standard Approval Flow

```solidity
// 1. First approve the ApprovalProxy to spend your tokens
IERC20(tokenAddress).approve(approvalProxyAddress, amount);

// 2. Then call transferAndMulticall with:
approvalProxy.transferAndMulticall(
    tokens,       // Array of tokens to transfer
    amounts,      // Array of amounts to transfer for each token
    calls,        // Array of calls to execute (e.g., swap operations)
    refundTo,     // Address to receive any leftover ETH from the swap
    nftRecipient  // Address to set as NFT recipient (if calls includes NFT mint)
);
```

1. ApprovalProxy transfers the specified tokens from the user to RelayRouter
2. RelayRouter executes the specified calls (e.g., swap operations)
3. Any ETH received from the operations is sent to the `refundTo` address
4. If `calls` includes an NFT mint or transfer, `nftRecipient` MUST be specified to transfer the token to `nftRecipient` in the corresponding `onReceived` hook
5. Any remaining tokens can be retrieved using cleanup functions on the RelayRouter

### 2. ERC2612 Permit Flow (No Pre-approval Required)

For tokens that support ERC2612 permit, you can skip the separate approval step:

```solidity
approvalProxy.permitTransferAndMulticall(
    permits,      // Array of permit data (signed approvals)
    calls,        // Array of calls to execute
    refundTo,     // Address to receive any leftover ETH
    nftRecipient  // Address to set as NFT recipient (if calls includes NFT mint)
);
```

1. ApprovalProxy calls `permit` on the ERC20 tokens
2. RelayRouter executes the specified calls (e.g., swap operations)
3. Any ETH received from the operations is sent to the `refundTo` address
4. If `calls` includes an NFT mint or transfer, `nftRecipient` MUST be specified to transfer the token to `nftRecipient` in the corresponding `onReceived` hook
5. Any remaining tokens can be retrieved using cleanup functions on the RelayRouter

### 3. Permit2 Flow

The ApprovalProxy also supports Permit2 for executing swaps

```solidity
// 1. First approve Permit2 contract to spend your tokens (one-time setup per token)
IERC20(tokenAddress).approve(PERMIT2_ADDRESS, type(uint256).max);

// 2. Generate and sign a Permit2 message off-chain
// The signature authorizes the RelayRouter to transfer specific amounts of tokens

// 3. Call permitMulticall with:
approvalProxy.permit2TransferAndMulticall(
    user,             // Address of the token owner
    permit,           // Permit2 batch transfer details (token addresses and amounts)
    calls,            // Array of calls to execute (e.g., swap operations)
    refundTo,         // Address to receive any leftover ETH
    nftRecipient,     // Address to set as NFT recipient (if calls includes NFT mint)
    permitSignature   // Signed Permit2 message authorizing the transfers
);
```

1. User approves Permit2 and signs an offchain message authorizing token transfers
2. RelayRouter verifies the signature and uses Permit2 to transfer tokens from the user
3. RelayRouter executes the specified calls (e.g., swap operations)
4. If `calls` includes an NFT mint or transfer, `nftRecipient` MUST be specified to transfer the token to `nftRecipient` in the corresponding `onReceived` hook
5. Any remaining tokens or ETH can be handled via cleanup functions

## CreditMaster

CreditMaster is a contract for holding user and solver funds in escrow to secure Relay orders. CreditMaster can be deployed to any chain where users would like to send input tokens for a cross-chain or same-chain order.

CreditMaster does not keep track of individual account balances – instead balances across all chains are tracked by an offchain Allocator that generates signatures when users and solvers would like to withdraw their funds. For example, once a user deposits ETH on Chain A to be bridged to Chain B, a solver can prove to the Allocator that they filled the user's order on Chain B in order to increase the solver's ETH balance on Chain A.

## Tests

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
