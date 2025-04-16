module test::whitelist;

use std::string::String;

const EInvalidCap : u64 = 12;
const ENoAccess : u64 = 77;
const EDuplicate : u64 = 1;
const EExceededCapacity : u64 = 2;
const EInvalidOwnerCap : u64 = 3;
const EWhitelistWithNoAdmin : u64 = 4;

public struct Whitelist has key {
    id: UID,
    name: String,
    vaultId: String,
    capacity: u64,
    gatingType: String,
    list: vector<address>,
    admin: bool,
}

public struct Cap has key {
    id: UID,
    whitelistId: ID,
    isOwner: bool,
}

public fun create_admin_whitelist(owner: address, vaultId: String, token: String, capacity: u64, ctx: &mut TxContext) {
    let wl = Whitelist {
        id: object::new(ctx),
        list: vector::empty(),
        capacity: capacity,
        vaultId: vaultId,
        name: vaultId,
        gatingType: token,
        admin: true
    };
    // create admin cap
    let adminCap = Cap {
        id: object::new(ctx),
        whitelistId: object::id(&wl),
        isOwner: false
    };
    transfer::transfer(adminCap, ctx.sender());

    // create owner cap
    let ownerCap = Cap {
        id: object::new(ctx),
        whitelistId: object::id(&wl),
        isOwner: true
    };
    transfer::transfer(ownerCap, owner);

    transfer::share_object(wl);
}

public fun create_whitelist(vaultId: String, token: String, capacity: u64, ctx: &mut TxContext) {
    let wl = Whitelist {
        id: object::new(ctx),
        list: vector::empty(),
        capacity: capacity,
        vaultId: vaultId,
        name: vaultId,
        gatingType: token,
        admin: false
    };
    // create owner cap
    let ownerCap = Cap {
        id: object::new(ctx),
        whitelistId: object::id(&wl),
        isOwner: true
    };
    transfer::transfer(ownerCap, ctx.sender());

    transfer::share_object(wl);
}

public fun add(wl: &mut Whitelist, cap: &Cap, account: address) {
    assert!(cap.whitelistId == object::id(wl), EInvalidCap);
    assert!((wl.admin == true) || (cap.isOwner == true), EInvalidOwnerCap);
    assert!(!wl.list.contains(&account), EDuplicate);
    assert!((wl.capacity == 0) || (wl.list.length() < wl.capacity), EExceededCapacity);
    wl.list.push_back(account);
}

public fun remove(wl: &mut Whitelist, cap: &Cap, account: address) {
    assert!(cap.whitelistId == object::id(wl), EInvalidCap);
    assert!((wl.admin == true) || (cap.isOwner == true), EInvalidOwnerCap);
    wl.list = wl.list.filter!(|x| x != account);
}

public fun remove_admin_mode(wl: &mut Whitelist, cap: &Cap) {
    assert!(cap.whitelistId == object::id(wl), EInvalidCap);
    assert!(wl.admin == true, EWhitelistWithNoAdmin);
    assert!(cap.isOwner == true, EInvalidOwnerCap);
    wl.admin = false;
}

public fun namespace(wl: &Whitelist): vector<u8> {
    wl.id.to_bytes()
}

/// All whitelisted addresses can access all IDs with the prefix of the whitelist
fun approve_internal(caller: address, id: vector<u8>, wl: &Whitelist): bool {
    // Check if the id has the right prefix
    let namespace = namespace(wl);
    let mut i = 0;
    if (namespace.length() > id.length()) {
        return false
    };
    while (i < namespace.length()) {
        if (namespace[i] != id[i]) {
            return false
        };
        i = i + 1;
    };

    // Check if user is in the whitelist
    wl.list.contains(&caller)
}

entry fun seal_approve(id: vector<u8>, wl: &Whitelist, ctx: &TxContext) {
    assert!(approve_internal(ctx.sender(), id, wl), ENoAccess);
}