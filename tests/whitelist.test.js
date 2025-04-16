require("dotenv").config();
const { Ed25519Keypair } = require('@mysten/sui/keypairs/ed25519');
const { SuiClient, getFullnodeUrl } = require('@mysten/sui/client');
const { Transaction } = require('@mysten/sui/transactions');

const suiClient = new SuiClient({ url: getFullnodeUrl('testnet') });

const EXAMPLE_TOKEN_GATING_TYPE = "0xd84704c17fc870b8764832c535aa6b11f21a95cd6f5bb38a9b07d2cf42220c66::blob::Blob";

describe(`Testing owner-only whitelist`, () => {

  let whitelistId;
  let capId;

  const adminKeypair = Ed25519Keypair.fromSecretKey(process.env.ADMIN_PRIVATE_KEY);
  const ownerKeypair = Ed25519Keypair.fromSecretKey(process.env.OWNER_PRIVATE_KEY);
  const randomKeypair = new Ed25519Keypair();

  it("should create owner whitelist", async () => {
    const tx = new Transaction();

    const res = await executeTransaction(
      {
        target: `${process.env.WHITELIST_PACKAGE_ID}::whitelist::create_whitelist`,
        arguments: [
          tx.pure.string("vault-id-here"),
          tx.pure.string(EXAMPLE_TOKEN_GATING_TYPE),
          tx.pure.u64(10),
        ],
      },
      tx,
      ownerKeypair
    );

    whitelistId = (
      res?.objectChanges?.find(
        object => object.type === 'created' && object.objectType?.includes('whitelist::Whitelist'),
      )
    )?.objectId;
    expect(whitelistId).toBeTruthy();
    capId = (
      res?.objectChanges?.find(
        (object) =>
          object.type === 'created' &&
          object.objectType?.includes('whitelist::Cap') &&
          object.owner?.AddressOwner === ownerKeypair.toSuiAddress(),
      )
    )?.objectId;
    expect(capId).toBeTruthy();
  });

  it("should add user to the whitelist", async () => {
    const tx = new Transaction();

    await executeTransaction(
      {
        arguments: [
          tx.object(whitelistId), 
          tx.object(capId), 
          tx.pure.address(randomKeypair.toSuiAddress())
        ],
        target: `${process.env.WHITELIST_PACKAGE_ID}::whitelist::add`,
      },
      tx,
      ownerKeypair
    );
  });

  it("should remove the user from the whitelist", async () => {
    const tx = new Transaction();

    await executeTransaction(
      {
        arguments: [
          tx.object(whitelistId), 
          tx.object(capId), 
          tx.pure.address(randomKeypair.toSuiAddress())
        ],
        target: `${process.env.WHITELIST_PACKAGE_ID}::whitelist::remove`,
      },
      tx,
      ownerKeypair
    );
  });

  it("should fail adding user by admin keypair", async () => {
    await expect(async () => {
      const tx = new Transaction();

      await executeTransaction(
        {
          arguments: [
            tx.object(whitelistId), 
            tx.object(capId), 
            tx.pure.address(adminKeypair.toSuiAddress())
          ],
          target: `${process.env.WHITELIST_PACKAGE_ID}::whitelist::add`,
        },
        tx,
        adminKeypair
      );
    }).rejects.toThrow(Error);
  });
});

describe(`Testing admin-mode whitelist`, () => {

  let whitelistId;
  let ownerCapId;
  let adminCapId;

  const adminKeypair = Ed25519Keypair.fromSecretKey(process.env.ADMIN_PRIVATE_KEY);
  const ownerKeypair = Ed25519Keypair.fromSecretKey(process.env.OWNER_PRIVATE_KEY);
  const randomKeypair = new Ed25519Keypair();
  const randomKeypair2 = new Ed25519Keypair();

  it("should create admin whitelist", async () => {
    const tx = new Transaction();

    const res = await executeTransaction(
      {
        target: `${process.env.WHITELIST_PACKAGE_ID}::whitelist::create_admin_whitelist`,
        arguments: [
          tx.pure.address(ownerKeypair.toSuiAddress()),
          tx.pure.string("vault-id-here"),
          tx.pure.string(EXAMPLE_TOKEN_GATING_TYPE),
          tx.pure.u64(10),
        ],
      },
      tx,
      adminKeypair
    );

    whitelistId = (
      res?.objectChanges?.find(
        object => object.type === 'created' && object.objectType?.includes('whitelist::Whitelist'),
      )
    )?.objectId;
    expect(whitelistId).toBeTruthy();
    adminCapId = (
      res?.objectChanges?.find(
        (object) =>
          object.type === 'created' &&
          object.objectType?.includes('whitelist::Cap') &&
          object.owner?.AddressOwner === adminKeypair.toSuiAddress(),
      )
    )?.objectId;
    expect(adminCapId).toBeTruthy();
    ownerCapId = (
      res?.objectChanges?.find(
        (object) =>
          object.type === 'created' &&
          object.objectType?.includes('whitelist::Cap') &&
          object.owner?.AddressOwner === ownerKeypair.toSuiAddress(),
      )
    )?.objectId;
    expect(ownerCapId).toBeTruthy();
  });

  it("should add user to the whitelist by the owner", async () => {
    const tx = new Transaction();

    await executeTransaction(
      {
        arguments: [
          tx.object(whitelistId), 
          tx.object(ownerCapId), 
          tx.pure.address(randomKeypair.toSuiAddress())
        ],
        target: `${process.env.WHITELIST_PACKAGE_ID}::whitelist::add`,
      },
      tx,
      ownerKeypair
    );
  });

  it("should fail adding the same user twice", async () => {
    await expect(async () => {
      const tx = new Transaction();

      await executeTransaction(
        {
          arguments: [
            tx.object(whitelistId), 
            tx.object(ownerCapId), 
            tx.pure.address(randomKeypair.toSuiAddress())
          ],
          target: `${process.env.WHITELIST_PACKAGE_ID}::whitelist::add`,
        },
        tx,
        ownerKeypair
      );
    }).rejects.toThrow(WHITELIST_ERROR_MAP[1]);
  });

  it("should remove the user from the whitelist by the owner", async () => {
    const tx = new Transaction();

    await executeTransaction(
      {
        arguments: [
          tx.object(whitelistId), 
          tx.object(ownerCapId), 
          tx.pure.address(randomKeypair.toSuiAddress())
        ],
        target: `${process.env.WHITELIST_PACKAGE_ID}::whitelist::remove`,
      },
      tx,
      ownerKeypair
    );
  });

  it("should add user to the whitelist by the admin", async () => {
    const tx = new Transaction();

    await executeTransaction(
      {
        arguments: [
          tx.object(whitelistId), 
          tx.object(adminCapId), 
          tx.pure.address(randomKeypair2.toSuiAddress())
        ],
        target: `${process.env.WHITELIST_PACKAGE_ID}::whitelist::add`,
      },
      tx,
      adminKeypair
    );
  });

  it("should remove the user from the whitelist by the admin", async () => {
    const tx = new Transaction();

    await executeTransaction(
      {
        arguments: [
          tx.object(whitelistId), 
          tx.object(adminCapId), 
          tx.pure.address(randomKeypair2.toSuiAddress())
        ],
        target: `${process.env.WHITELIST_PACKAGE_ID}::whitelist::remove`,
      },
      tx,
      adminKeypair
    );
  });

  it("should remove admin mode by the owner", async () => {
    const tx = new Transaction();

    await executeTransaction(
      {
        arguments: [
          tx.object(whitelistId), 
          tx.object(ownerCapId), 
        ],
        target: `${process.env.WHITELIST_PACKAGE_ID}::whitelist::remove_admin_mode`,
      },
      tx,
      ownerKeypair
    );
  });

  it("should fail adding new user by the old admin", async () => {
    await expect(async () => {
      const tx = new Transaction();

      await executeTransaction(
        {
          arguments: [
            tx.object(whitelistId), 
            tx.object(adminCapId), 
            tx.pure.address(randomKeypair.toSuiAddress())
          ],
          target: `${process.env.WHITELIST_PACKAGE_ID}::whitelist::add`,
        },
        tx,
        adminKeypair
      );
    }).rejects.toThrow(WHITELIST_ERROR_MAP[3]);
  });
});

async function executeTransaction(
  moveCall,
  tx,
  signer
) {
  tx.moveCall({
    arguments: moveCall.arguments,
    target: moveCall.target,
  });
  tx.setGasBudget(10000000);
  tx.setSender(signer.toSuiAddress());
  const bytes = await tx.build({ client: suiClient });
  const { signature } = await signer.signTransaction(bytes);

  // dry run transaction
  let dry_run_result = await suiClient.dryRunTransactionBlock({
    transactionBlock: bytes,
  });

  if (dry_run_result.effects.status.status === 'failure') {
    console.log(dry_run_result);
    throw new Error(getWhitelistErrorMessage(dry_run_result.executionErrorSource));
  }

  // execute transaction
  let res = await suiClient.executeTransactionBlock({
    transactionBlock: bytes,
    signature: signature,
    options: {
      // Raw effects are required so the effects can be reported back to the wallet
      showRawEffects: true,
      // Select additional data to return
      showObjectChanges: true,
    },
  });
  console.log(res);
  await delay(2000);
  return res;
}

function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

const WHITELIST_ERROR_MAP = {
  12: /* EInvalidCap */ 'Only the contract owner/admin can perform this action.',
  77: /* ENoAccess */ 'The address does not belong to the whitelist.',
  1: /* EDuplicate */ 'The address is already in the whitelist.',
  2: /* EExceededCapacity */ 'The whitelist capacity exceeded.',
  3: /* EInvalidOwnerCap */ 'Only the contract owner can perform this action.',
  4: /* EWhitelistWithNoAdmin */ 'The whitelist does not have the admin mode.',
};

function getWhitelistErrorMessage(errorMessage) {
  const match = errorMessage?.match(/sub status\s+(\d+)/i);
  if (match && match[1]) {
    const code = parseInt(match[1], 10);
    return WHITELIST_ERROR_MAP[code] || `Smart contract error.`;
  }
  return 'Smart contract error.';
}