// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title WebAuthnLoginTest
/// @notice Day 22 — first pass at a passkey-based login flow using the
///         enshrined WebAuthn (P-256) precompile. Verifies a passkey
///         signature directly in a contract call, no separate auth
///         service in the loop.
/// @dev Repo: github.com/NealPanchal/ritual-build
///      CONFIRM exact precompile address + ABI against ritual-dapp-ed25519
///      / ritual-dapp-precompiles before relying on this. 0x0009 referenced
///      in docs for Ed25519; WebAuthn/P-256 address not yet confirmed —
///      using a placeholder below.

interface IWebAuthnPrecompile {
    /// @notice Verifies a WebAuthn (P-256) passkey signature.
    /// @param authenticatorData Raw authenticator data from the passkey assertion.
    /// @param clientDataJSON Client data JSON from the WebAuthn assertion.
    /// @param signature The P-256 signature over the challenge.
    /// @param publicKeyX X coordinate of the registered P-256 public key.
    /// @param publicKeyY Y coordinate of the registered P-256 public key.
    /// @return valid Whether the signature verifies against the given key.
    function verify(
        bytes calldata authenticatorData,
        bytes calldata clientDataJSON,
        bytes calldata signature,
        uint256 publicKeyX,
        uint256 publicKeyY
    ) external view returns (bool valid);
}

contract WebAuthnLoginTest {
    address constant WEBAUTHN_PRECOMPILE = 0x0000000000000000000000000000000000000009; // CONFIRM

    address public owner;

    // Registered passkey for the happy-path test — single key only.
    // NOT stress-tested yet: key rotation, multiple devices per identity.
    uint256 public registeredPubKeyX;
    uint256 public registeredPubKeyY;
    bool public keyRegistered;

    mapping(address => bool) public loggedIn;

    event PasskeyRegistered(uint256 pubKeyX, uint256 pubKeyY);
    event LoginAttempt(address indexed caller, bool success);

    constructor() {
        owner = msg.sender;
    }

    /// @notice Registers a single passkey. Deliberately simple for the
    ///         happy-path test — no rotation or multi-device support yet.
    function registerPasskey(uint256 pubKeyX, uint256 pubKeyY) external {
        require(msg.sender == owner, "not owner");
        registeredPubKeyX = pubKeyX;
        registeredPubKeyY = pubKeyY;
        keyRegistered = true;
        emit PasskeyRegistered(pubKeyX, pubKeyY);
    }

    /// @notice Verifies a passkey signature directly in the contract call,
    ///         no separate off-chain auth service in the loop.
    function loginWithPasskey(
        bytes calldata authenticatorData,
        bytes calldata clientDataJSON,
        bytes calldata signature
    ) external {
        require(keyRegistered, "no passkey registered");

        bool valid = IWebAuthnPrecompile(WEBAUTHN_PRECOMPILE).verify(
            authenticatorData,
            clientDataJSON,
            signature,
            registeredPubKeyX,
            registeredPubKeyY
        );

        loggedIn[msg.sender] = valid;
        emit LoginAttempt(msg.sender, valid);

        require(valid, "passkey verification failed");
    }

    // TODO (tomorrow): key rotation support, multiple devices per identity,
    // handling of malformed/replayed signature attempts.
}
