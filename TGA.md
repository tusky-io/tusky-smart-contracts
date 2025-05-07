# Tusky TGA with Seal

Tusky leverages Token-Gated Access (TGA) vaults using [Seal SDK](https://github.com/MystenLabs/seal).

When a user creates a TGA vault in Tusky, a new whitelist & TGA service are created within the smart contract.

Users can later access the service by either holding the required token or belonging to the whitelist.

## TGA

A TGA<T> is a Sui on-chain object defining following fields:

- `id` - unique whitelist id
- `vaultId` - connecting the on-chain TGA service to a Tusky vault (1:1 connection)

where <T> is a type of required token to access the service

## Whitelist

A Whitelist is a Sui on-chain object defining following fields:

- `id` - unique whitelist id
- `serviceId` - connecting to the on-chain TGA service (1:1 connection)
- `capacity` - maximum number of members
- `admin` - a flag indicating whether the whitelist is owner-only or admin-mode
- `list` - list of whitelisted wallet addresses for access-control

## Capability

A Capability is a Sui on-chain object that gives the owner the right to perform a specific action, in TGA scenario: to manipulate the Whitelist object.

Capability object defines following fields:

- `id` - unique capability id
- `whitelistId` - connecting the existing whitelist to the capability
- `capType` - a flag indicating whether the capability belongs to the owner or admin

## Whitelist modes

There are two types of whitelist:

### owner-only

To create owner-only whitelist: `${WHITELIST_PACKAGE_ID}::whitelist::create_whitelist`.

Only one Capability object is created relative to the whitelist.

The owner can transfer their Capability to a different wallet address at any time.

The owner can add/remove wallet addresses to/from the whitelist.

The only way to encrypt/decrypt the data is the client-side encryption (CSE).

### admin-mode

To create admin-mode whitelist: `${WHITELIST_PACKAGE_ID}::whitelist::create_admin_whitelist`.

When creating a whitelist, two Capability objects are also created:
- one for the whitelist owner (`CapType::Owner`)
- one for the whitelist admin (`CapType::Admin`)

The whitelist owner can at any point remove admin mode and become unique whitelist actor (by calling: `${WHITELIST_PACKAGE_ID}::whitelist::remove_admin_mode`).

Each Capability object is transferable so both owner & admin can transfer it to a different wallet addresses.

Both owner & admin can add/remove wallet addresses to/from the whitelist.

The admin has the ability to add themselves to the whitelist and thus encrypt/decrypt related data, which enables server-side encryption (SSE).

## Using TGA feature with Tusky SDK

## Creating a TGA vault

```js
import { Tusky } from "@tusky-io/ts-sdk";
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';

const keypair = Ed25519Keypair.deriveKeypair("wallet-mnemonic-of-the-whitelist-owner");
const tusky = await Tusky.init({ wallet: { keypair: keypair } });
await tusky.auth.signIn();

const vault = await tusky.vault.create("TGA vault", { 
  whitelist: { 
    token: { 
      type: "NFT", 
      address: "0x98af8b8fde88f3c4bdf0fcedcf9afee7d10f66d480b74fb5a3a2e23dc7f5a564::airdrop::WALAirdrop" 
    }, 
    memberRole: "viewer", 
    capacity: 10 
  } 
});
```

> **NOTE:** \
> smart contract call made in the background: `${WHITELIST_PACKAGE_ID}::whitelist::create_admin_whitelist`


## Joining a TGA vault

```js
import { Tusky } from "@tusky-io/ts-sdk";
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';

const keypair = Ed25519Keypair.deriveKeypair("wallet-mnemonic-holding-required-token");
const tusky = await Tusky.init({ wallet: { keypair: keypair } });
await tusky.auth.signIn();

const membership = await tusky.vault.join(vaultId);
```

> **NOTE:** \
> Tusky API verifies if the user wallet holds the required token and rejects the request otherwise \
> smart contract call made in the background: `${WHITELIST_PACKAGE_ID}::whitelist::add`


## Revoking access to the TGA vault

```js
import { Tusky } from "@tusky-io/ts-sdk";
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';

const keypair = Ed25519Keypair.deriveKeypair("wallet-mnemonic-of-the-whitelist-owner");
const tusky = await Tusky.init({ wallet: { keypair: keypair } });
await tusky.auth.signIn();

const members = await tusky.vault.members(vaultId);
const memberToRevoke = members.find((member) => member.role === "viewer");
await tusky.vault.revokeAccess(memberToRevoke.id);
```

> **NOTE:** \
> smart contract call made in the background: `${WHITELIST_PACKAGE_ID}::whitelist::remove`
