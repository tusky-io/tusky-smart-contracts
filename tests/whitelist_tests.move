#[test_only]
module tga::whitelist_tests;
use tga::whitelist::{Self, Cap, TGA, Whitelist, EInvalidOwnerCap, EDuplicate, ENoAccess};

#[test]
fun test_whitelist_success_path() {
    use sui::test_scenario;
    use sui::coin;
    use sui::sui::SUI;
    use std::string::utf8;

    // test addresses representing users
    let owner = @0x1;
    let user = @0x2;

    let whitelist;
    let mut whitelist_val;

    let mut scenario_val = test_scenario::begin(owner);
    let scenario = &mut scenario_val;
    {
        // first transaction executed by owner to create an admin whitelist
        let (tga, wl, ownerCap) = whitelist::create_whitelist_service<coin::Coin<SUI>>(utf8(b"vault-id-here"), 10, scenario.ctx());
        whitelist::transfer_cap(ownerCap, owner);
        whitelist::share_whitelist(wl);
        whitelist::share_tga(tga);
    };

    test_scenario::next_tx(scenario, owner);
    {
        // transaction executed by the whitelist owner to add the new user to the whitelist
        whitelist_val = test_scenario::take_shared<Whitelist>(scenario);
        whitelist = &mut whitelist_val;
        let cap = test_scenario::take_from_sender<Cap>(scenario);
        whitelist::add(whitelist, &cap, user);
        test_scenario::return_to_sender(scenario, cap);
    };

    test_scenario::next_tx(scenario, user);
    {
        // transaction executed by the user to request access
        whitelist::seal_approve_whitelist(object::id<Whitelist>(whitelist).to_bytes(), whitelist, scenario.ctx());
    };

    let tga = test_scenario::take_shared<tga::whitelist::TGA<sui::coin::Coin<sui::sui::SUI>>>(scenario);
    whitelist::destroy_tga_for_testing<coin::Coin<SUI>>(tga);
    whitelist::destroy_whitelist_for_testing(whitelist_val);
    test_scenario::end(scenario_val);
}

#[expected_failure(abort_code = ENoAccess)]
#[test]
fun test_whitelist_fail_no_access() {
    use sui::test_scenario;
    use sui::coin;
    use sui::sui::SUI;
    use std::string::utf8;

    // test addresses representing users
    let owner = @0x1;
    let user = @0x2;

    let whitelist;
    let whitelist_val;

    let mut scenario_val = test_scenario::begin(owner);
    let scenario = &mut scenario_val;
    {
        // first transaction executed by owner to create an admin whitelist
        let (tga, wl, ownerCap) = whitelist::create_whitelist_service<coin::Coin<SUI>>(utf8(b"vault-id-here"), 10, scenario.ctx());
        whitelist::transfer_cap(ownerCap, owner);
        whitelist::share_whitelist(wl);
        whitelist::share_tga(tga);
    };

    test_scenario::next_tx(scenario, user);
    {
        // transaction executed by the user to request access
        // should fail - no access
        whitelist_val = test_scenario::take_shared<Whitelist>(scenario);
        whitelist = &whitelist_val;
        whitelist::seal_approve_whitelist(object::id<Whitelist>(&whitelist_val).to_bytes(), whitelist, scenario.ctx());
        test_scenario::return_shared(whitelist_val);
    };

    let tga = test_scenario::take_shared<tga::whitelist::TGA<sui::coin::Coin<sui::sui::SUI>>>(scenario);
    whitelist::destroy_tga_for_testing<coin::Coin<SUI>>(tga);
    test_scenario::end(scenario_val);
}

#[expected_failure(abort_code = EDuplicate)]
#[test]
fun test_whitelist_fail_duplicate() {
    use sui::test_scenario;
    use sui::coin;
    use sui::sui::SUI;
    use std::string::utf8;

    // test addresses representing users
    let owner = @0x1;
    let user = @0x2;

    let whitelist;
    let mut whitelist_val;

    let mut scenario_val = test_scenario::begin(owner);
    let scenario = &mut scenario_val;
    {
        // first transaction executed by owner to create an admin whitelist
        let (tga, wl, ownerCap) = whitelist::create_whitelist_service<coin::Coin<SUI>>(utf8(b"vault-id-here"), 10, scenario.ctx());
        whitelist::transfer_cap(ownerCap, owner);
        whitelist::share_whitelist(wl);
        whitelist::share_tga(tga);
    };

        test_scenario::next_tx(scenario, owner);
    {
        // transaction executed by the whitelist owner to add the new user to the whitelist
        whitelist_val = test_scenario::take_shared<Whitelist>(scenario);
        whitelist = &mut whitelist_val;
        let cap = test_scenario::take_from_sender<Cap>(scenario);
        whitelist::add(whitelist, &cap, user);
        test_scenario::return_to_sender(scenario, cap);
    };

    test_scenario::next_tx(scenario, owner);
    {
        // transaction executed by the whitelist owner to add the new user to the whitelist
        // should fail - user duplicate
        let cap = test_scenario::take_from_sender<Cap>(scenario);
        whitelist::add(whitelist, &cap, user);
        test_scenario::return_to_sender(scenario, cap);
    };

    let tga = test_scenario::take_shared<tga::whitelist::TGA<sui::coin::Coin<sui::sui::SUI>>>(scenario);
    whitelist::destroy_tga_for_testing<coin::Coin<SUI>>(tga);
    whitelist::destroy_whitelist_for_testing(whitelist_val);
    test_scenario::end(scenario_val);
}

#[test]
fun test_admin_whitelist_success_path() {
    use sui::test_scenario;
    use sui::coin;
    use sui::sui::SUI;
    use std::string::utf8;

    // test addresses representing users
    let owner = @0x1;
    let admin = @0x2;
    let user = @0x3;

    let whitelist;
    let mut whitelist_val;

    let mut scenario_val = test_scenario::begin(admin);
    let scenario = &mut scenario_val;
    {
        // first transaction executed by admin to create an admin whitelist
        let (tga, wl, ownerCap, adminCap) = whitelist::create_admin_whitelist_service<coin::Coin<SUI>>(utf8(b"vault-id-here"), owner, 10, scenario.ctx());
        whitelist::transfer_cap(adminCap, admin);
        whitelist::transfer_cap(ownerCap, owner);
        whitelist::share_whitelist(wl);
        whitelist::share_tga(tga);
    };

    test_scenario::next_tx(scenario, admin);
    {
        // transaction executed by the whitelist admin to add the new user to the whitelist
        whitelist_val = test_scenario::take_shared<Whitelist>(scenario);
        whitelist = &mut whitelist_val;
        let cap = test_scenario::take_from_sender<Cap>(scenario);
        whitelist::add(whitelist, &cap, owner);
        test_scenario::return_to_sender(scenario, cap);
    };

    test_scenario::next_tx(scenario, owner);
    {
        // transaction executed by the whitelist owner to add the new user to the whitelist
        let cap = test_scenario::take_from_sender<Cap>(scenario);
        whitelist::add(whitelist, &cap, user);
        test_scenario::return_to_sender(scenario, cap);
    };

    test_scenario::next_tx(scenario, user);
    {
        // transaction executed by the user to request access
        whitelist::seal_approve_whitelist(object::id<Whitelist>(whitelist).to_bytes(), whitelist, scenario.ctx());
    };

    test_scenario::next_tx(scenario, owner);
    {
        // transaction executed by the whitelist owner to remove the admin mode
        let cap = test_scenario::take_from_sender<Cap>(scenario);
        whitelist::remove_admin_mode(whitelist, &cap);
        test_scenario::return_to_sender(scenario, cap);
    };

    let tga = test_scenario::take_shared<tga::whitelist::TGA<sui::coin::Coin<sui::sui::SUI>>>(scenario);
    whitelist::destroy_tga_for_testing<coin::Coin<SUI>>(tga);
    whitelist::destroy_whitelist_for_testing(whitelist_val);
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
    let owner = @0x1;
    let admin = @0x2;
    let user = @0x3;

    let whitelist;
    let mut whitelist_val;

    let mut scenario_val = test_scenario::begin(admin);
    let scenario = &mut scenario_val;
    {
        // first transaction executed by admin to create an admin whitelist
        let (tga, wl, ownerCap, adminCap) = whitelist::create_admin_whitelist_service<coin::Coin<SUI>>(utf8(b"vault-id-here"), owner, 10, scenario.ctx());
        whitelist::transfer_cap(adminCap, admin);
        whitelist::transfer_cap(ownerCap, owner);
        whitelist::share_whitelist(wl);
        whitelist::share_tga(tga);
    };

    test_scenario::next_tx(scenario, admin);
    {
        // transaction executed by the whitelist admin to add the new user to the whitelist
        whitelist_val = test_scenario::take_shared<Whitelist>(scenario);
        whitelist = &mut whitelist_val;
        let cap = test_scenario::take_from_sender<Cap>(scenario);
        whitelist::add(whitelist, &cap, owner);
        test_scenario::return_to_sender(scenario, cap);
    };

    test_scenario::next_tx(scenario, owner);
    {
        // transaction executed by the whitelist owner to remove the admin mode
        let cap = test_scenario::take_from_sender<Cap>(scenario);
        whitelist::remove_admin_mode(whitelist, &cap);
        test_scenario::return_to_sender(scenario, cap);
    };

    test_scenario::next_tx(scenario, admin);
    {
        // transaction executed by the whitelist admin to add the new user to the whitelist
        // should fail - no admin mode
        let cap = test_scenario::take_from_sender<Cap>(scenario);
        whitelist::add(whitelist, &cap, user);
        test_scenario::return_to_sender(scenario, cap);
    };

    let tga = test_scenario::take_shared<tga::whitelist::TGA<sui::coin::Coin<sui::sui::SUI>>>(scenario);
    whitelist::destroy_tga_for_testing<coin::Coin<SUI>>(tga);
    whitelist::destroy_whitelist_for_testing(whitelist_val);
    test_scenario::end(scenario_val);
}

#[test]
fun test_tga() {
    use sui::test_scenario;
    use sui::coin;
    use sui::sui::SUI;
    use std::string::utf8;

    // test addresses representing users
    let owner = @0x1;
    let user = @0x2;

    let coin;

    let mut scenario_val = test_scenario::begin(owner);
    let scenario = &mut scenario_val;
    {
        // create TGA service by the owner
        let tga = whitelist::create_tga_service<coin::Coin<SUI>>(utf8(b"vault-id-here"), scenario.ctx());
        whitelist::share_tga(tga);
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
        whitelist::seal_approve<sui::coin::Coin<sui::sui::SUI>>(object::id<TGA<sui::coin::Coin<sui::sui::SUI>>>(&tga_val).to_bytes(), &tga_val, &coin);
        test_scenario::return_shared(tga_val);
        test_scenario::return_to_address(user, coin);
    };
    test_scenario::end(scenario_val);
}