require("dotenv").config();
const { Ed25519Keypair } = require('@mysten/sui/keypairs/ed25519');
const { SuiClient, getFullnodeUrl } = require('@mysten/sui/client');
const { Transaction } = require('@mysten/sui/transactions');
const { fromHex } = require('@mysten/bcs');

const suiClient = new SuiClient({ url: getFullnodeUrl('testnet') });

const EXAMPLE_TOKEN_GATING_TYPE = "0x2::coin::Coin<0x8190b041122eb492bf63cb464476bd68c6b7e570a4079645a8b28732b6197a82::wal::WAL>";
const EXAMPLE_TOKEN_OBJECT_ID = "0x4c4fdf70c5261c0b3b9495fe2ac57e92f2016025a8db469279af65404433384d";
const EXAMPLE_WRONG_TOKEN_GATING_TYPE = "0x2::coin::Coin<0xa1ec7fc00a6f40db9693ad1415d0c193ad3906494428cf252621037bd7117e29::usdc::USDC>";
const EXAMPLE_WRONG_TOKEN_OBJECT_ID = "0x37d4f7c48d81d32d988ee5aa0d425309b8e946a8f9158f7e7de9eb85e9410cf0";

describe(`Testing owner-only whitelist`, () => {

  let whitelistId;
  let capId;
  let tgaId;

  const adminKeypair = Ed25519Keypair.fromSecretKey(process.env.ADMIN_PRIVATE_KEY);
  const ownerKeypair = Ed25519Keypair.fromSecretKey(process.env.OWNER_PRIVATE_KEY);
  const randomKeypair = new Ed25519Keypair();

  it("should create owner whitelist", async () => {
    const tx = new Transaction();

    const res = await executeTransaction(
      {
        target: `${process.env.WHITELIST_PACKAGE_ID}::whitelist::create_whitelist_entry`,
        typeArguments: [
          EXAMPLE_TOKEN_GATING_TYPE
        ],
        arguments: [
          tx.pure.string("vault-id-here"),
          tx.pure.u64(10),
        ],
      },
      tx,
      ownerKeypair
    );

    whitelistId = getWhitelistId(res?.objectChanges);
    expect(whitelistId).toBeTruthy();
    capId = getCapId(res?.objectChanges, ownerKeypair.toSuiAddress());
    expect(capId).toBeTruthy();
    tgaId = getTGAId(res?.objectChanges);
    expect(tgaId).toBeTruthy();
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

  it("should approve user with required token", async () => {
    const tx = new Transaction();

    await executeTransaction(
      {
        typeArguments: [
          EXAMPLE_TOKEN_GATING_TYPE
        ],
        arguments: [
          tx.pure.vector('u8', fromHex(tgaId)),
          tx.object(tgaId),
          tx.object(EXAMPLE_TOKEN_OBJECT_ID),
        ],
        target: `${process.env.WHITELIST_PACKAGE_ID}::whitelist::seal_approve`,
      },
      tx,
      adminKeypair
    );
  });

  it("should reject user not belonging to the whitelist", async () => {
    await expect(async () => {

      const tx = new Transaction();

      await executeTransaction(
        {
          arguments: [
            tx.pure.vector('u8', fromHex(whitelistId)),
            tx.object(whitelistId),
          ],
          target: `${process.env.WHITELIST_PACKAGE_ID}::whitelist::seal_approve_whitelist`,
        },
        tx,
        adminKeypair
      );
    }).rejects.toThrow(Error);
  });


  it("should add admin to the whitelist", async () => {
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
      ownerKeypair
    );
  });

  it("should approve user belonging to the whitelist", async () => {
    const tx = new Transaction();

    await executeTransaction(
      {
        arguments: [
          tx.pure.vector('u8', fromHex(whitelistId)),
          tx.object(whitelistId),
        ],
        target: `${process.env.WHITELIST_PACKAGE_ID}::whitelist::seal_approve_whitelist`,
      },
      tx,
      adminKeypair
    );
  });

  it("should reject user using someone elses token", async () => {
    await expect(async () => {
      const tx = new Transaction();

      await executeTransaction(
        {
          typeArguments: [
            EXAMPLE_TOKEN_GATING_TYPE
          ],
          arguments: [
            tx.pure.vector('u8', fromHex(tgaId)),
            tx.object(tgaId),
            tx.object(EXAMPLE_TOKEN_OBJECT_ID),
          ],
          target: `${process.env.WHITELIST_PACKAGE_ID}::whitelist::seal_approve`,
        },
        tx,
        ownerKeypair
      );
    }).rejects.toThrow(Error);
  });

  it("should reject user using a wrong token", async () => {
    await expect(async () => {
      const tx = new Transaction();

      await executeTransaction(
        {
          typeArguments: [
            EXAMPLE_TOKEN_GATING_TYPE
          ],
          arguments: [
            tx.pure.vector('u8', fromHex(tgaId)),
            tx.object(tgaId),
            tx.object(EXAMPLE_WRONG_TOKEN_OBJECT_ID),
          ],
          target: `${process.env.WHITELIST_PACKAGE_ID}::whitelist::seal_approve`,
        },
        tx,
        adminKeypair
      );
    }).rejects.toThrow(Error);
  });

  it("should reject user using a wrong token & token type", async () => {
    await expect(async () => {
      const tx = new Transaction();

      await executeTransaction(
        {
          typeArguments: [
            EXAMPLE_WRONG_TOKEN_GATING_TYPE
          ],
          arguments: [
            tx.pure.vector('u8', fromHex(tgaId)),
            tx.object(tgaId),
            tx.object(EXAMPLE_WRONG_TOKEN_OBJECT_ID),
          ],
          target: `${process.env.WHITELIST_PACKAGE_ID}::whitelist::seal_approve`,
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
        target: `${process.env.WHITELIST_PACKAGE_ID}::whitelist::create_admin_whitelist_entry`,
        typeArguments: [
          EXAMPLE_TOKEN_GATING_TYPE
        ],
        arguments: [
          tx.pure.string("vault-id-here"),
          tx.pure.address(ownerKeypair.toSuiAddress()),
          tx.pure.u64(10),
        ],
      },
      tx,
      adminKeypair
    );

    whitelistId = getWhitelistId(res?.objectChanges);
    expect(whitelistId).toBeTruthy();
    ownerCapId = getCapId(res?.objectChanges, ownerKeypair.toSuiAddress());
    expect(ownerCapId).toBeTruthy();
    adminCapId = getCapId(res?.objectChanges, adminKeypair.toSuiAddress());
    expect(adminCapId).toBeTruthy();
    tgaId = getTGAId(res?.objectChanges);
    expect(tgaId).toBeTruthy();
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
          typeArguments: [],
          target: `${process.env.WHITELIST_PACKAGE_ID}::whitelist::add`,
        },
        tx,
        adminKeypair
      );
    }).rejects.toThrow(WHITELIST_ERROR_MAP[3]);
  });
});

function getWhitelistId(objectChanges) {
  return (
    objectChanges?.find(
      object => object.type === 'created' && object.objectType?.includes('whitelist::Whitelist'),
    )
  )?.objectId;
}

function getTGAId(objectChanges) {
  return (
    objectChanges?.find(
      object => object.type === 'created' && object.objectType?.includes('whitelist::TGA'),
    )
  )?.objectId;
}

function getCapId(objectChanges, owner) {
  return (
    objectChanges?.find(
      (object) =>
        object.type === 'created' &&
        object.objectType?.includes('whitelist::Cap') &&
        object.owner?.AddressOwner === owner,
    )
  )?.objectId;
}

async function executeTransaction(
  moveCall,
  tx,
  signer
) {
  tx.moveCall({
    arguments: moveCall.arguments,
    target: moveCall.target,
    typeArguments: moveCall.typeArguments
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
    throw new Error(getWhitelistErrorMessage(dry_run_result.executionErrorSource || dry_run_result.effects.status.error));
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
  1: /* EInvalidCap */ 'Only the contract owner/admin can perform this action.',
  2: /* EInvalidOwnerCap */ 'Only the contract owner can perform this action.',
  3: /* ENoAccess */ 'The address does not belong to the whitelist.',
  4: /* EDuplicate */ 'The address is already in the whitelist.',
  5: /* EExceededCapacity */ 'The whitelist capacity exceeded.',
  6: /* EWhitelistWithNoAdmin */ 'The whitelist does not have the admin mode.',
};

function getWhitelistErrorMessage(errorMessage) {
  const match = errorMessage?.match(/sub status\s+(\d+)/i);
  if (match && match[1]) {
    const code = parseInt(match[1], 10);
    return WHITELIST_ERROR_MAP[code] || `Smart contract error.`;
  }
  return 'Smart contract error: ' + errorMessage;
}