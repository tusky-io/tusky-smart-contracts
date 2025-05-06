# Tusky smart contracts
A monorepo for all Tusky smart contracts on Sui

> **_DISCLAIMER_**
>
> Please note that all contracts are in beta on testnet at the moment.

## Current smart contracts

- [TGA](TGA.md)

## Contract deployment

To deploy new package on Sui

```bash
sui client switch --env testnet
sui move build
sui client publish --gas-budget 100000000
```

## Contract tests

### jest tests

Create a `.env` file in the root directory with the following variables:

```env
ADMIN_PRIVATE_KEY="testing-private-key-1"
OWNER_PRIVATE_KEY="testing-private-key-2"
WHITELIST_PACKAGE_ID="deployed-package-id"
```

Create a `.env` file in the root directory with the following variables:

```bash
npm install
npm test
```

### move tests

TODO: move to a separate module
