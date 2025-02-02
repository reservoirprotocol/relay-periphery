# Relay

Relay is a protocol for executing cross-chain and same-chain swaps and calls.

## Execution Paths

### ERC20 Approval + Call `transferAndMulticall` on ApprovalProxy

For executing ERC20 <> ETH or ERC20 swaps, a user can execute the following calls:

```
IERC20(token).approve(address(approvalProxy), amt)
approvalProxy.transferAndMulticall(tokens, amounts, calls, refundTo)
```

The ApprovalProxy will transfer `amount` of each `token` in the input arrays from the user to the RelayRouter. The Router will then execute the specified `calls` with the user's input tokens. If the Router receives ETH as an output, it will transfer the ETH to the `refundTo` address.

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
