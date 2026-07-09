# Ritual LLM Precompile Contract

A skeleton Solidity contract demonstrating how to interact with the Ritual LLM precompile (`0x0802`) on the Ritual chain.

## Overview

This repository contains a simple integration for the **short-running async** `0x0802` LLM precompile. The initial intent was to feel out the request/response cycle before building complex logic on top of it.

As detailed in my dev thread, calling a precompile synchronously and expecting a direct return (like `string memory response = ILLMPrecompile(LLM_PRECOMPILE).infer(req);`) **will not work** and will revert. Instead, the transaction leverages the builder's deferred execution model:
1. You encode a full 30-field ABI payload.
2. The initial transaction (commitment) evaluates with an empty output (`0x`).
3. The chain evaluates the LLM request asynchronously.
4. The builder replays the transaction (fulfilled replay) with the real output populated in the receipt (`spcCalls`).

## Key Features in `llm.sol`
- **`fundWallet()`**: Demonstrates that fee prepayment to `RitualWallet` is **not optional**. Without a deposit, your inference call will revert.
- **`askModel()`**: Encodes the 30-field LLM request payload.
- **Stack Too Deep Fix**: By passing a `LLMRequest` struct to `abi.encode()`, we bypass the Solidity stack limit while preserving the exact tuple encoding required by the Ritual ABI.
- **Empty Output Checking**: Prevents reverting the initial transaction commitment by verifying that `actualOutput.length > 0` before decoding.

## Deployment
Deployed on Ritual Testnet:
- **Contract Address:** `0xA1299b3D16Fdd0b693Bc1D26cc25C743c06a907F`

## License
MIT
