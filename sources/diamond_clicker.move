module diamond_clicker::game {
    use std::signer;
    use std::vector;

    use aptos_framework::timestamp;

    #[test_only]
    use aptos_framework::account;

    /*
    Errors
    DO NOT EDIT
    */
    const ERROR_GAME_STORE_DOES_NOT_EXIST: u64 = 0;
    const ERROR_UPGRADE_DOES_NOT_EXIST: u64 = 1;
    const ERROR_NOT_ENOUGH_DIAMONDS_TO_UPGRADE: u64 = 2;

    /*
    Const
    DO NOT EDIT
    */
    const POWERUP_NAMES: vector<vector<u8>> = vector[b"Bruh", b"Aptomingos", b"Aptos Monkeys"];
    // cost, dpm (diamonds per minute)
    const POWERUP_VALUES: vector<vector<u64>> = vector[
        vector[5, 5],
        vector[25, 30],
        vector[250, 350],
    ];

    /*
    Structs
    DO NOT EDIT
    */
    struct Upgrade has key, store, copy, drop {
        name: vector<u8>,
        amount: u64
    }

    struct GameStore has key {
        diamonds: u64,
        upgrades: vector<Upgrade>,
        last_claimed_timestamp_seconds: u64,
    }

    /*
    Functions
    */

    public fun initialize_game(account: &signer) {
        let game_store = GameStore {
            diamonds : 0,
            upgrades: vector::empty<Upgrade>(),
            last_claimed_timestamp_seconds: 0
        };
        // move_to account with new GameStore
        move_to(account, game_store);
    }

    public entry fun click(account: &signer) acquires GameStore {
        // check if GameStore does not exist - if not, initialize_game

        // get signer's address
        let signer_address = signer::address_of(account);
        // initialise game
        if(exists<GameStore>(signer_address) == false) {
            initialize_game(account);
        };
        // assert that signer has creates a game store
        assert!(exists<GameStore>(signer_address), ERROR_GAME_STORE_DOES_NOT_EXIST);
        // get the game store resource
        let game_store = borrow_global_mut<GameStore>(signer_address);

        // increment game_store.diamonds by +1
        game_store.diamonds = game_store.diamonds + 1;
    }

    fun get_unclaimed_diamonds(account_address: address, current_timestamp_seconds: u64): u64 acquires GameStore {

        let diamonds_per_minute = get_diamonds_per_minute(account_address);

        // loop over game_store.upgrades - if the powerup exists then calculate the dpm and minutes_elapsed to add the amount to the unclaimed_diamonds
        
        // assert that signer has creates a game store
        assert!(exists<GameStore>(account_address), ERROR_GAME_STORE_DOES_NOT_EXIST);
        // get the game store resource
        let game_store = borrow_global_mut<GameStore>(account_address);
        //let i = 1;
        // let diamonds_per_minute = 0;
        // while(!vector::is_empty(&game_store.upgrades)){
        //     let u1 = *vector::borrow(&game_store.upgrades, vector::length(&game_store.upgrades) - i);
        //     i = i + 1;
        //     let powerup_value;
            
        //     if (vector::contains(&POWERUP_NAMES, &u1.name)){
        //         if(u1.name == b"Bruh") {
        //             powerup_value = *vector::borrow(&POWERUP_VALUES, 0);
        //         } else if (u1.name == b"Aptomingos") {
        //             powerup_value = *vector::borrow(&POWERUP_VALUES, 1);
        //         } else {
        //             powerup_value = *vector::borrow(&POWERUP_VALUES, 2);
        //         };

        //         let dpm = *vector::borrow(&powerup_value, 1);
        //         diamonds_per_minute = diamonds_per_minute + (dpm * u1.amount);

        //     };
        // };
        let minutes_elapsed = (current_timestamp_seconds - game_store.last_claimed_timestamp_seconds) / 60;
        let unclaimed_diamonds = diamonds_per_minute * minutes_elapsed;
        return unclaimed_diamonds
    }


    fun claim(account_address: address) acquires GameStore {
        let unclaimed_diamonds = get_unclaimed_diamonds(account_address, timestamp::now_seconds());
        // assert that signer has creates a game store
        assert!(exists<GameStore>(account_address), ERROR_GAME_STORE_DOES_NOT_EXIST);
        // get the game store resource
        let game_store = borrow_global_mut<GameStore>(account_address);
        
        // set game_store.diamonds to current diamonds + unclaimed_diamonds
        game_store.diamonds = game_store.diamonds + unclaimed_diamonds;
        // set last_claimed_timestamp_seconds to the current timestamp in seconds
        game_store.last_claimed_timestamp_seconds = timestamp::now_seconds();
    }

    public entry fun upgrade(account: &signer, upgrade_index: u64, upgrade_amount: u64) acquires GameStore {
        
        
        // get signer's address
        let signer_address = signer::address_of(account);

        // claim for account address
        claim(signer_address);

        // check that the game store exists
        assert!(exists<GameStore>(signer_address), ERROR_GAME_STORE_DOES_NOT_EXIST);

        // get the game store resource
        let game_store = borrow_global_mut<GameStore>(signer_address);

        // check the powerup_names length is greater than or equal to upgrade_index
        assert!(upgrade_index < vector::length(&POWERUP_NAMES), ERROR_UPGRADE_DOES_NOT_EXIST);

        

        // check that the user has enough coins to make the current upgrade
        let powerup_value = *vector::borrow(&POWERUP_VALUES, upgrade_index);
        let powerup_name = *vector::borrow(&POWERUP_NAMES, upgrade_index);
        let total_upgrade_cost = *vector::borrow(&powerup_value, 0);
        assert!(total_upgrade_cost <= game_store.diamonds, ERROR_NOT_ENOUGH_DIAMONDS_TO_UPGRADE);
        // loop through game_store upgrades - if the upgrade exists then increment but the upgrade_amount
        
        let upgrade_existed = false;
        //let u1 = vector::empty<&mut Upgrade>();
        let length = vector::length(&game_store.upgrades);
        let index = length;
        vector::enumerate_ref(&game_store.upgrades, |i, upgrade|{
            let upgrade :&Upgrade = upgrade;
            if(upgrade.name == powerup_name){
                upgrade_existed = true;
                index = i;
            }
        });
                                                    
        if(upgrade_existed) {
            let up = *vector::borrow(&game_store.upgrades, index);
            *vector::borrow_mut(&mut game_store.upgrades, index) = Upgrade {
                name: up.name,
                amount: up.amount + upgrade_amount 
            }
            //u1.amount = u1.amount + upgrade_amount;
        } 
        // if upgrade_existed does not exist then create it with the base upgrade_amount
        else {
          let upgrade = Upgrade {
            name: powerup_name,
            amount: upgrade_amount
          };
          vector::push_back(&mut game_store.upgrades, upgrade);
        };
        
        // set game_store.diamonds to current diamonds - total_upgrade_cost
        game_store.diamonds = game_store.diamonds - total_upgrade_cost;
    }
    

    #[view]
    public fun get_diamonds(account_address: address): u64 acquires GameStore {
        let unclaimed_diamonds = get_unclaimed_diamonds(account_address, timestamp::now_seconds());
        // assert that signer has creates a game store
        assert!(exists<GameStore>(account_address), ERROR_GAME_STORE_DOES_NOT_EXIST);
        // get the game store resource
        let game_store = borrow_global_mut<GameStore>(account_address);
        return game_store.diamonds + unclaimed_diamonds
    }

    #[view]
    public fun get_diamonds_per_minute(account_address: address): u64 acquires GameStore {
        // assert that signer has creates a game store
        assert!(exists<GameStore>(account_address), ERROR_GAME_STORE_DOES_NOT_EXIST);
        // get the game store resource
        let game_store = borrow_global<GameStore>(account_address);
        // loop over game_store.upgrades - calculate dpm * current_upgrade.amount to get the total diamonds_per_minute
        let i = 1;
        let diamonds_per_minute = 0;
        while(!vector::is_empty(&game_store.upgrades)){
            let u1 = *vector::borrow(&game_store.upgrades, vector::length(&game_store.upgrades) - i);
            i = i + 1;
            let powerup_value;
            
            if (vector::contains(&POWERUP_NAMES, &u1.name)){
                if(u1.name == b"Bruh") {
                    powerup_value = *vector::borrow(&POWERUP_VALUES, 0);
                } else if (u1.name == b"Aptomingos") {
                    powerup_value = *vector::borrow(&POWERUP_VALUES, 1);
                } else {
                    powerup_value = *vector::borrow(&POWERUP_VALUES, 2);
                };

                let dpm = *vector::borrow(&powerup_value, 1);
                diamonds_per_minute = diamonds_per_minute + (dpm * u1.amount);

            };
        
        };
        // return diamonds_per_minute of all the user's powerups
        return diamonds_per_minute
    }

    #[view]
    public fun get_powerups(account_address: address): vector<Upgrade> acquires GameStore {
        assert!(exists<GameStore>(account_address), ERROR_GAME_STORE_DOES_NOT_EXIST);
        // get the game store resource
        let game_store = borrow_global_mut<GameStore>(account_address);
        return game_store.upgrades
        //return 0
    }

    /*
    Tests
    DO NOT EDIT
    */
    inline fun test_click_loop(signer: &signer, amount: u64) acquires GameStore {
        let i = 0;
        while (amount > i) {
            click(signer);
            i = i + 1;
        }
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_click_without_initialize_game(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);
        let test_one_address = signer::address_of(test_one);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        click(test_one);

        let current_game_store = borrow_global<GameStore>(test_one_address);

        assert!(current_game_store.diamonds == 1, 0);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_click_with_initialize_game(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);
        let test_one_address = signer::address_of(test_one);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        click(test_one);

        let current_game_store = borrow_global<GameStore>(test_one_address);

        assert!(current_game_store.diamonds == 1, 0);

        click(test_one);

        let current_game_store = borrow_global<GameStore>(test_one_address);

        assert!(current_game_store.diamonds == 2, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    #[expected_failure(abort_code = 0, location = diamond_clicker::game)]
    fun test_upgrade_does_not_exist(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        upgrade(test_one, 0, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    #[expected_failure(abort_code = 2, location = diamond_clicker::game)]
    fun test_upgrade_does_not_have_enough_diamonds(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        click(test_one);
        upgrade(test_one, 0, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_upgrade_one(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        test_click_loop(test_one, 5);
        upgrade(test_one, 0, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_upgrade_two(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        test_click_loop(test_one, 25);

        upgrade(test_one, 1, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_upgrade_three(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        test_click_loop(test_one, 250);

        upgrade(test_one, 2, 1);
    }
}
