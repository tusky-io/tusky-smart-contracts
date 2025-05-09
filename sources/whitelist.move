module tga::whitelist;

use std::string::String;

const EInvalidCap : u64 = 1;
const EInvalidOwnerCap : u64 = 2;
const ENoAccess : u64 = 3;
const EDuplicate : u64 = 4;
const EExceededCapacity : u64 = 5;
const EWhitelistWithNoAdmin : u64 = 6;

public struct TGA<phantom T> has key {
    id: UID,
    vaultId: String,
}

public struct Whitelist has key {
    id: UID,
    serviceId: ID,
    admin: bool,
    capacity: u64,
    list: vector<address>,
}

public enum CapType has store, drop, copy {
    Admin,
    Owner
}

public struct Cap has key {
    id: UID,
    whitelistId: ID,
    capType: CapType,
}

public fun create_tga_service<T>(vaultId: String, ctx: &mut TxContext): TGA<T> {
    TGA<T> {
        id: object::new(ctx),
        vaultId: vaultId,
    }
}

public fun create_admin_whitelist_service<T>(vaultId: String, owner: address, capacity: u64, ctx: &mut TxContext): (TGA<T>, Whitelist, Cap, Cap) {
   let tga = TGA<T> {
        id: object::new(ctx),
        vaultId: vaultId,
    };
    let wl = Whitelist {
        id: object::new(ctx),
        serviceId: object::id(&tga),
        list: vector::empty(),
        capacity: capacity,
        admin: true
    };
    let ownerCap = Cap {
        id: object::new(ctx),
        whitelistId: object::id(&wl),
        capType: CapType::Owner
    };
    let adminCap = Cap {
        id: object::new(ctx),
        whitelistId: object::id(&wl),
        capType: CapType::Admin
    };
    (tga, wl, ownerCap, adminCap)
}

entry fun create_whitelist_entry<T>(vaultId: String, capacity: u64, ctx: &mut TxContext) {
    let (tga, wl, ownerCap) = create_whitelist_service<T>(vaultId, capacity, ctx);
    transfer::share_object(wl);
    transfer::share_object(tga);
    transfer::transfer(ownerCap, ctx.sender());
}

entry fun create_admin_whitelist_entry<T>(vaultId: String, owner: address, capacity: u64, ctx: &mut TxContext) {
    let (tga, wl, ownerCap, adminCap) = create_admin_whitelist_service<T>(vaultId, owner, capacity, ctx);
    transfer::share_object(wl);
    transfer::share_object(tga);
    transfer::transfer(ownerCap, owner);
    transfer::transfer(adminCap, ctx.sender());
}

public fun create_whitelist_service<T>(vaultId: String, capacity: u64, ctx: &mut TxContext): (TGA<T>, Whitelist, Cap) {
   let tga = TGA<T> {
        id: object::new(ctx),
        vaultId: vaultId,
    };
    let wl = Whitelist {
        id: object::new(ctx),
        serviceId: object::id(&tga),
        list: vector::empty(),
        capacity: capacity,
        admin: false
    };
    let cap = Cap {
        id: object::new(ctx),
        whitelistId: object::id(&wl),
        capType: CapType::Owner
    };
    (tga, wl, cap)
}

public fun add(wl: &mut Whitelist, cap: &Cap, account: address) {
    assert!(cap.whitelistId == object::id(wl), EInvalidCap);
    assert!((wl.admin == true) || (cap.capType == CapType::Owner), EInvalidOwnerCap);
    assert!(!wl.list.contains(&account), EDuplicate);
    assert!((wl.capacity == 0) || (wl.list.length() < wl.capacity), EExceededCapacity);
    wl.list.push_back(account);
}

public fun remove(wl: &mut Whitelist, cap: &Cap, account: address) {
    assert!(cap.whitelistId == object::id(wl), EInvalidCap);
    assert!((wl.admin == true) || (cap.capType == CapType::Owner), EInvalidOwnerCap);
    wl.list = wl.list.filter!(|x| x != account);
}

public fun remove_admin_mode(wl: &mut Whitelist, cap: &Cap) {
    assert!(cap.whitelistId == object::id(wl), EInvalidCap);
    assert!(wl.admin == true, EWhitelistWithNoAdmin);
    assert!(cap.capType == CapType::Owner, EInvalidOwnerCap);
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

public fun seal_approve<T>(id: vector<u8>, service: &TGA<T>, _token: &T) {
    assert!(check_access(id, service, _token), ENoAccess);
}

entry fun seal_approve_whitelist(id: vector<u8>, wl: &Whitelist,  ctx: &TxContext) {
    assert!(approve_internal(ctx.sender(), id, wl), ENoAccess);
}

/// All addresses can access all IDs with the prefix of the service
fun check_access<T>(id: vector<u8>, service: &TGA<T>, _token: &T): bool {
    // Check if the id has the right prefix
    let namespace = service.id.to_bytes();
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
    true
}

#[test_only]
public fun transfer_cap(cap: Cap, recipient: address) {
    transfer::transfer(cap, recipient);
}

#[test_only]
public fun share_whitelist(whitelist: Whitelist) {
    transfer::share_object(whitelist);
}

#[test_only]
public fun share_tga<T>(tga: TGA<T>) {
    transfer::share_object(tga);
}

#[test_only]
public fun destroy_tga_for_testing<T>(tga: TGA<T>) {
    let TGA { id, .. } = tga;
    object::delete(id);
}

#[test_only]
public fun destroy_whitelist_for_testing(wl: Whitelist) {
    let Whitelist { id, .. } = wl;
    object::delete(id);
}