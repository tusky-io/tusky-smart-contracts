module tga::whitelist;

use std::string::String;

const EInvalidCap : u64 = 12;
const ENoAccess : u64 = 77;
const EDuplicate : u64 = 1;
const EExceededCapacity : u64 = 2;
const EInvalidOwnerCap : u64 = 3;
const EWhitelistWithNoAdmin : u64 = 4;

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
public fun destroy_tga_for_testing<T>(tga: TGA<T>) {
    let TGA { id, .. } = tga;
    object::delete(id);
}

#[test_only]
public fun destroy_whitelist_for_testing(wl: Whitelist) {
    let Whitelist { id, .. } = wl;
    object::delete(id);
}

#[test]
fun test_admin_whitelist() {
    use sui::test_scenario;
    use sui::coin;
    use sui::sui::SUI;
    use std::string::utf8;

    // test addresses representing users
    let owner = @0xCAFE;
    let admin = @0xFACE;
    let user = @0xFAFE;

    let whitelist;
    let mut whitelist_val;

    let mut scenario_val = test_scenario::begin(admin);
    let scenario = &mut scenario_val;
    {
        // first transaction executed by admin to create an admin whitelist
        let (tga, wl, ownerCap, adminCap) = create_admin_whitelist_service<coin::Coin<SUI>>(utf8(b"xxxx"), owner, 10, scenario.ctx());
        transfer::transfer(adminCap, admin);
        transfer::transfer(ownerCap, owner);
        transfer::share_object(wl);
        transfer::share_object(tga);
    };

    test_scenario::next_tx(scenario, admin);
    {
        // transaction executed by the whitelist admin to add the new user to the whitelist
        whitelist_val = test_scenario::take_shared<Whitelist>(scenario);
        whitelist = &mut whitelist_val;
        let cap = test_scenario::take_from_sender<Cap>(scenario);
        add(whitelist, &cap, owner);
        test_scenario::return_to_sender(scenario, cap);
    };

    test_scenario::next_tx(scenario, owner);
    {
        // transaction executed by the whitelist owner to add the new user to the whitelist
        let cap = test_scenario::take_from_sender<Cap>(scenario);
        add(whitelist, &cap, user);
        test_scenario::return_to_sender(scenario, cap);
    };

    test_scenario::next_tx(scenario, owner);
    {
        // transaction executed by the whitelist owner to remove the admin mode
        let cap = test_scenario::take_from_sender<Cap>(scenario);
        remove_admin_mode(whitelist, &cap);
        test_scenario::return_to_sender(scenario, cap);
    };

    let tga = test_scenario::take_shared<tga::whitelist::TGA<sui::coin::Coin<sui::sui::SUI>>>(scenario);
    destroy_tga_for_testing<coin::Coin<SUI>>(tga);
    destroy_whitelist_for_testing(whitelist_val);
    test_scenario::end(scenario_val);
}

#[expected_failure(abort_code = EInvalidOwnerCap)]
#[test]
fun test_admin_whitelist_failing() {
    use sui::test_scenario;
    use sui::coin;
    use sui::sui::SUI;
    use std::string::utf8;

    // test addresses representing users
    let owner = @0xCAFE;
    let admin = @0xFACE;
    let user = @0xFAFE;

    let whitelist;
    let mut whitelist_val;

    let mut scenario_val = test_scenario::begin(admin);
    let scenario = &mut scenario_val;
    {
        // first transaction executed by admin to create an admin whitelist
        let (tga, wl, ownerCap, adminCap) = create_admin_whitelist_service<coin::Coin<SUI>>(utf8(b"xxxx"), owner, 10, scenario.ctx());
        transfer::transfer(adminCap, admin);
        transfer::transfer(ownerCap, owner);
        transfer::share_object(wl);
        transfer::share_object(tga);
    };

    test_scenario::next_tx(scenario, admin);
    {
        // transaction executed by the whitelist admin to add the new user to the whitelist
        whitelist_val = test_scenario::take_shared<Whitelist>(scenario);
        whitelist = &mut whitelist_val;
        let cap = test_scenario::take_from_sender<Cap>(scenario);
        add(whitelist, &cap, owner);
        test_scenario::return_to_sender(scenario, cap);
    };

    test_scenario::next_tx(scenario, owner);
    {
        // transaction executed by the whitelist owner to remove the admin mode
        let cap = test_scenario::take_from_sender<Cap>(scenario);
        remove_admin_mode(whitelist, &cap);
        test_scenario::return_to_sender(scenario, cap);
    };

    test_scenario::next_tx(scenario, admin);
    {
        // transaction executed by the whitelist admin to add the new user to the whitelist
        // should fail - no admin mode
        let cap = test_scenario::take_from_sender<Cap>(scenario);
        add(whitelist, &cap, user);
        test_scenario::return_to_sender(scenario, cap);
    };

    let tga = test_scenario::take_shared<tga::whitelist::TGA<sui::coin::Coin<sui::sui::SUI>>>(scenario);
    destroy_tga_for_testing<coin::Coin<SUI>>(tga);
    destroy_whitelist_for_testing(whitelist_val);
    test_scenario::end(scenario_val);
}

#[expected_failure(abort_code = EDuplicate)]
#[test]
fun test_admin_whitelist_failing_double() {
    use sui::test_scenario;
    use sui::coin;
    use sui::sui::SUI;
    use std::string::utf8;

    // test addresses representing users
    let owner = @0xCAFE;
    let admin = @0xFACE;

    let whitelist;
    let mut whitelist_val;

    let mut scenario_val = test_scenario::begin(admin);
    let scenario = &mut scenario_val;
    {
        // first transaction executed by admin to create an admin whitelist
        let (tga, wl, ownerCap, adminCap) = create_admin_whitelist_service<coin::Coin<SUI>>(utf8(b"xxxx"), owner, 10, scenario.ctx());
        transfer::transfer(adminCap, admin);
        transfer::transfer(ownerCap, owner);
        transfer::share_object(wl);
        transfer::share_object(tga);
    };

    test_scenario::next_tx(scenario, admin);
    {
        // transaction executed by the whitelist admin to add the new user to the whitelist
        whitelist_val = test_scenario::take_shared<Whitelist>(scenario);
        whitelist = &mut whitelist_val;
        let cap = test_scenario::take_from_sender<Cap>(scenario);
        add(whitelist, &cap, owner);
        test_scenario::return_to_sender(scenario, cap);
    };

    test_scenario::next_tx(scenario, admin);
    {
        // transaction executed by the whitelist admin to add the new user to the whitelist
        // should fail - user duplicate
        let cap = test_scenario::take_from_sender<Cap>(scenario);
        add(whitelist, &cap, owner);
        test_scenario::return_to_sender(scenario, cap);
    };

    let tga = test_scenario::take_shared<tga::whitelist::TGA<sui::coin::Coin<sui::sui::SUI>>>(scenario);
    destroy_tga_for_testing<coin::Coin<SUI>>(tga);
    destroy_whitelist_for_testing(whitelist_val);
    test_scenario::end(scenario_val);
}

#[test]
fun test_tga() {
    use sui::test_scenario;
    use sui::coin;
    use sui::sui::SUI;
    use std::string::utf8;

    // test addresses representing users
    let owner = @0xCAFE;
    let user = @0xFACE;

    let coin;

    let mut scenario_val = test_scenario::begin(owner);
    let scenario = &mut scenario_val;
    {
        // create TGA service by the owner
        let tga = create_tga_service<coin::Coin<SUI>>(utf8(b"vaultId"), scenario.ctx());
        transfer::share_object(tga);
    };
    test_scenario::next_tx(scenario, user);
    {
        // mint coin by the user
        let coin_val = coin::mint_for_testing<SUI>(10, scenario.ctx());

        transfer::public_transfer(coin_val, user);
    };

    test_scenario::next_tx(scenario, user);
    {
        coin = test_scenario::take_from_address<sui::coin::Coin<sui::sui::SUI>>(scenario, user);

        // should approve access request by using the minted coin by the user
        let tga_val = test_scenario::take_shared<TGA<sui::coin::Coin<sui::sui::SUI>>>(scenario);
        assert!(check_access<coin::Coin<SUI>>(object::id<TGA<sui::coin::Coin<sui::sui::SUI>>>(&tga_val).to_bytes(), &tga_val, &coin));
        test_scenario::return_shared(tga_val);
        test_scenario::return_to_address(user, coin);
    };
    test_scenario::end(scenario_val);
}