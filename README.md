# ritual-build

A 30-day public build log on Ritual Chain — daily commits, real failures included. This repo tracks the flagship app: a chained pipeline that fetches external data, parses it, runs it through the LLM precompile, and writes the verified result onchain.

Build log posts: [@Oreganoflakess on X]

---

## Architecture overview

Ritual Chain runs on what it calls TEE-EOVMT (EVM with Off-chain Verifiable Machine Tasks) — two execution paths over one shared state:

- **Replicated execution** — standard, deterministic EVM. Transfers, storage reads, normal contract calls. Every validator re-runs it and agrees on the result, same as any EVM chain.
- **TEE-verified execution** — for anything non-deterministic: LLM inference, HTTP calls, classical ML. These run through executors inside TEEs (trusted execution environments), and each response is cryptographically attested to the exact request that triggered it. A contract trusts the hardware attestation, not a server operator.

Sitting on top of both paths is a three-layer model that took most of week 1 of this build log to actually internalize:

1. **Your dApp** — frontend + contracts, nothing Ritual-specific here.
2. **Precompile layer** — 16 precompiled contracts covering LLM, HTTP, classical ML (ONNX), agents, multimodal, Ed25519 verification, and secrets. This is where "AI-native" actually lives in the stack.
3. **Chain orchestration layer** — genesis system contracts (AsyncJobTracker, RitualWallet, Scheduler, and others) that make layer 2 usable: funding precompile calls, resolving non-deterministic work asynchronously, running things on a schedule.

The mental model that made the rest of the docs click: **attestation** is the one word doing all the trust work. Cryptographically tying a specific input to a specific output is the entire reason any of this is verifiable instead of "trust me, the model said so."

---

## Chained pipeline walkthrough

The core contract in this repo (`contracts/FetchAndSynthesize.sol`) composes two precompiles into one pipeline:

```
fetch external data → parse/clean → LLM synthesis → write onchain
```

### Day 12 — first attempt, and the bug

The first version passed the raw HTTP response directly into the LLM precompile as the prompt, with no processing in between:

```solidity
// BROKEN — day 12
ILLMPrecompile.LLMRequest memory llmReq = ILLMPrecompile.LLMRequest({
    model: "default",
    prompt: raw, // raw JSON straight into the prompt
    maxTokens: 256
});
```

It compiled, deployed, and executed — but the model was reasoning over half-formed JSON sitting in the middle of what was supposed to be a natural-language prompt. Technically verifiable, practically useless output. This is documented as `fetchAndSynthesizeRaw()` and kept in history rather than deleted, since the failure mode is worth showing alongside the fix.

### Day 13 — the fix

The fix wraps the raw data with explicit instruction framing before it's ever used as a prompt, instead of dumping it in unlabeled:

```solidity
// FIXED — day 13
function _buildCleanPrompt(string memory instruction, string memory rawData)
    internal
    pure
    returns (string memory)
{
    return string(
        abi.encodePacked(
            instruction,
            "\n\nRelevant data:\n",
            rawData
        )
    );
}
```

Small change in code, immediate difference in output quality. The lesson: **verifiable ≠ well-formatted**. The chain guarantees the HTTP response is real and untampered — it says nothing about whether that response is shaped for the next precompile to use well. Precompile composition isn't free in design terms; you still need to think about data shape between calls the same way you would in any normal pipeline.

The working version is `fetchAndSynthesize()` in the current contract.

### Why this matters beyond one bug

Both `fetch()` and `infer()` resolve through **AsyncJobTracker** under the hood — non-deterministic, long-running work doesn't block the deterministic execution path. It gets tracked and resolved asynchronously, then lands back onchain. This is the mechanism that makes composed pipelines like this one practical rather than theoretical.

---

## Setup

```bash
git clone https://github.com/NealPanchal/ritual-build.git
cd ritual-build
npm install
```

Configure your Ritual testnet RPC and a funded deployer key in `.env`:

```
RITUAL_TESTNET_RPC=<your-rpc-url>
PRIVATE_KEY=<your-testnet-key>
```

Deploy:

```bash
npx hardhat run scripts/deploy.js --network ritual-testnet
```

**Before calling any precompile-facing function, fund RitualWallet first:**

```solidity
fundWallet{value: 0.01 ether}(1 days); // dev lock duration
```

Skipping this step is the single most common failure mode in this repo's own history — see Pitfalls below.

---

## Pitfalls

Documented as they're hit, not just the happy path. If you're new to Ritual, read this before you write your first contract — it would have saved several evenings.

### 1. Fund RitualWallet before any precompile call
Precompile calls (LLM, HTTP, etc.) are paid from a **prepaid balance**, not pulled ad hoc from the caller's wallet at call time. Calling a precompile before `deposit()` reverts. This caused the very first revert in this build log (day 8) — normal EVM dev doesn't have a "fund before you call" step baked into the mental model, so it's an easy assumption to carry over incorrectly.

```solidity
// Do this first, always:
fundWallet(lockDuration);
// Only then:
askModel(prompt, maxTokens);
```

### 2. Lock duration is monotonic
`deposit(lockDuration)` can only **extend** the lock, never shorten it. A placeholder value thrown in during testing becomes a real constraint you're stuck with. Pick deliberately — this repo uses `1 days` for dev and `30 days` as a production starting point, not as fixed recommendations, just documented defaults.

### 3. Precompile call ordering matters — it's part of the security model, not just style
Because precompile calls are TEE-routed, *when* you call something affects what's actually attested. Calling a data-transformation step (e.g. redaction) after a value is already written to storage means the transformation accomplished nothing, even if the call itself succeeded. Order matters more here than in typical EVM dev.

### 4. Verifiable ≠ well-formatted
The chain attests that a precompile response is real and untampered. It does not parse, clean, or structure that response for you. Treat data shape between chained precompile calls like any normal software pipeline — parse before you pass data downstream, not after. (Day 12 bug, day 13 fix, documented above.)

---

## Status

Day 21 of a 30-day build log. Week 3 complete:
- ritual-dapp-skills scaffolding compared against hand-built pipeline (day 16)
- Scheduler precompile running a recurring, unattended inference job (day 17)
- Full recursive agent pattern working end to end — parent agent goal ->
  coding agent build -> deployed, funded child contract (day 20)

Next: week 4 — identity primitives (WebAuthn/Ed25519) and the secrets/
privacy stack (DKMS, ECIES, redaction, X402).

Corrections welcome — open an issue or reply on X if anything here is
wrong or out of date.
