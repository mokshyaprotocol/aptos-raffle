//! Contract for raffle 
//! Created by Mokshya Protocol
module raffle::raffle
{
    use std::signer;
    use std::string::{String,append};
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::managed_coin;
    use aptos_token::token::{Self,balance_of,direct_transfer};
    use aptos_std::type_info;
    use aptos_std::table::{Self, Table};
    use std::bcs::to_bytes;
    use std::vector;
    use std::bcs;
    use std::hash;
    use aptos_std::from_bcs;

    struct GameMap has key
    {
        //initiated while creating the module contains the 
        //appended name of collection and token  
        //raffle game_address
        raffles: Table<String, address>, 
    }
    struct Raffle has key 
    {
        raffle_creator:address,
        token_info:RaffleTokenInfo,
        start_time:u64,
        end_time:u64,
        num_tickets:u64,
        ticket_prize:u64,
        winning_ticket:u64,
        coin_type:address, 
        treasury_cap:account::SignerCapability,
        ticket_sold:u64, //number of ticket sold
        winner:address,
    }
    struct RaffleTokenInfo has copy,drop,store
    {
        token_creator:address,
        collection:String,
        token_name:String,
        property_version:u64,
    }
    struct Player has key 
    {
        raffles: Table<RaffleTokenInfo, vector<u64>>,
    }
    //Errors
    const ENO_NOT_MODULE_DEPLOYER:u64=0;
    const ENO_RAFFLE_ALREADY_CREATED:u64=1;
    const ENO_NO_TOKEN:u64=2;
    const ENO_STARTTIME_LARGER:u64=3;
    const ENO_START_TIME_PASSED:u64=4;
    const ENO_RAFFLE_DOESNT_EXISTS:u64=4;
    const ENO_INSUFFICIENT_TICKETS:u64=5;
    const ENO_COINTYPE_MISMATCH:u64=6;
    const ENO_NOT_STARTED:u64=7;
    const ENO_ALREADY_ENDED:u64=8;
    const ENO_NOT_ENDED:u64=9;
    const ENO_CREATOR_MISMATCH:u64=10;
    const ENO_NOT_PLAYER:u64=11;
    const ENO_ALREADY_CLAIMED:u64=12;
    const ENO_NOT_WINNER:u64=13;

    /*Functions for Users to interact with SC*/
    //Function for creating raffle
    //called_while_deploying_contract
    fun init_module(module_owner:&signer) 
    {
        let module_owner_address = signer::address_of(module_owner);
        assert!(module_owner_address==@raffle,ENO_NOT_MODULE_DEPLOYER);
        if (!exists<GameMap>(module_owner_address))
        {
        move_to(module_owner,
                GameMap{
                    raffles:table::new<String,address>(),
                });
        };
        
    } 
    public entry fun start_raffle<CoinType>(
        creator:&signer,
        token_creator:address,
        collection:String,
        token_name:String,
        property_version:u64,
        start_time:u64,
        end_time:u64,
        num_tickets:u64,
        ticket_prize:u64,
    ) acquires GameMap
    {
        let creator_addr = signer::address_of(creator);
        let token_id = token::create_token_id_raw(token_creator, collection, token_name, property_version);
        //verifying the token owner has the token
        assert!(balance_of(creator_addr,token_id)>=1,ENO_NO_TOKEN);
        //resource account created
        //getting the seeds
        let seed = collection;
        let tmp_seed = token_name;
        append(&mut seed,tmp_seed);
        let (raffle_treasury, raffle_treasury_cap) = account::create_resource_account(creator,to_bytes(&seed)); //resource account to store funds and data
        let raffle_treasury_signer_from_cap = account::create_signer_with_capability(&raffle_treasury_cap);
        let raffle_address = signer::address_of(&raffle_treasury);
        assert!(!exists<Raffle>(raffle_address),ENO_RAFFLE_ALREADY_CREATED);
        //transfer the token to the treasury
        managed_coin::register<CoinType>(&raffle_treasury_signer_from_cap); 
        direct_transfer(creator,&raffle_treasury_signer_from_cap,token_id,1);
        //Time Verification
        assert!(end_time>start_time,ENO_STARTTIME_LARGER);
        let now = aptos_framework::timestamp::now_seconds();
        assert!(start_time>now,ENO_START_TIME_PASSED);
        // //save raffle game 
        let raffle_map = &mut borrow_global_mut<GameMap>(@raffle).raffles;
        table::add(raffle_map, seed, raffle_address);
        //save the data
        move_to<Raffle>(&raffle_treasury_signer_from_cap, Raffle{
        raffle_creator:creator_addr,
        token_info:RaffleTokenInfo{ token_creator,collection,token_name,property_version},
        start_time,
        end_time,
        num_tickets,
        ticket_prize,
        winning_ticket:0,
        coin_type:coin_address<CoinType>(),  
        treasury_cap:raffle_treasury_cap,
        ticket_sold:0,
        winner:@raffle,
        });
    }
    public entry fun play_raffle<CoinType>(
        player:&signer,
        collection:String,
        token_name:String,
        num_tickets:u64,
    ) acquires GameMap,Raffle,Player
    {
        let player_addr = signer::address_of(player);
        //raffle game address derivation
        let seed = collection;
        let tmp_seed = token_name;
        append(&mut seed,tmp_seed);
        let raffle_map = &borrow_global<GameMap>(@raffle).raffles;
        assert!(
            table::contains(raffle_map, seed),ENO_RAFFLE_DOESNT_EXISTS
        );
        let raffle_treasury_address=*table::borrow(raffle_map,seed);
        assert!(exists<Raffle>(raffle_treasury_address),ENO_RAFFLE_DOESNT_EXISTS);
        let raffle_data = borrow_global_mut<Raffle>(raffle_treasury_address);
        //time verification
        let now = aptos_framework::timestamp::now_seconds();
        assert!(now > raffle_data.start_time,ENO_NOT_STARTED);
        assert!(now < raffle_data.end_time,ENO_ALREADY_ENDED);
        if (!exists<Player>(player_addr))
        {
        move_to(player,
                Player{
                    raffles:table::new(),
                });
        };
        let player_data=&mut borrow_global_mut<Player>(player_addr).raffles;
        if (!table::contains(player_data,raffle_data.token_info))
        {
            table::add(player_data, raffle_data.token_info, vector<u64>[]);
        };
        let ticket_remaining=raffle_data.num_tickets-raffle_data.ticket_sold;
        let new_ticket_num=raffle_data.ticket_sold+num_tickets;
        assert!(ticket_remaining>=num_tickets,ENO_INSUFFICIENT_TICKETS);
        let ticket_set=table::borrow_mut(player_data,raffle_data.token_info);
        while(raffle_data.ticket_sold < new_ticket_num)
        {
            raffle_data.ticket_sold=raffle_data.ticket_sold+1;
            vector::push_back(ticket_set,raffle_data.ticket_sold);
        };
        let amount = num_tickets*raffle_data.ticket_prize;
        assert!(coin_address<CoinType>()==raffle_data.coin_type,ENO_COINTYPE_MISMATCH);
        coin::transfer<CoinType>(player,raffle_treasury_address,amount);
    }
    public entry fun declare_winner<CoinType>(
        creator:&signer,
        collection:String,
        token_name:String,
    )acquires GameMap,Raffle
    {
        let creator_addr = signer::address_of(creator);
        //raffle game address derivation
        let seed = collection;
        let tmp_seed = token_name;
        append(&mut seed,tmp_seed);
        let raffle_map = &borrow_global<GameMap>(@raffle).raffles;
        assert!(
            table::contains(raffle_map, seed),ENO_RAFFLE_DOESNT_EXISTS
        );
        let raffle_treasury_address=*table::borrow(raffle_map,seed);
        assert!(exists<Raffle>(raffle_treasury_address),ENO_RAFFLE_DOESNT_EXISTS);
        let raffle_data = borrow_global_mut<Raffle>(raffle_treasury_address);
        //owner verification is necessory here otherwise anyone can draw ticket
        assert!(raffle_data.raffle_creator==creator_addr,ENO_CREATOR_MISMATCH);
        //time verification
        let now = aptos_framework::timestamp::now_seconds();
        assert!(now>raffle_data.end_time,ENO_NOT_ENDED);
        let token_id = token::create_token_id_raw(raffle_data.token_info.token_creator, collection, token_name, raffle_data.token_info.property_version);
        //verifying the raffle has the token
        assert!(balance_of(raffle_treasury_address,token_id)>=1,ENO_NO_TOKEN);
        let raffle_signer_from_cap = account::create_signer_with_capability(&raffle_data.treasury_cap);
        if (raffle_data.ticket_sold == 0)
        {
        direct_transfer(&raffle_signer_from_cap,creator,token_id,1);
        } else {
            let winning_ticket=draw_raffle(creator_addr,raffle_data.ticket_sold);
            raffle_data.winning_ticket=winning_ticket;
            if (!coin::is_account_registered<CoinType>(creator_addr))
            {
                managed_coin::register<CoinType>(creator); 
            };
            let amount = raffle_data.ticket_sold * raffle_data.ticket_prize;
            coin::transfer<CoinType>(&raffle_signer_from_cap,raffle_data.raffle_creator,amount);
        };    
    }
    public entry fun check_claim_reward(
        player:&signer,
        collection:String,
        token_name:String,
    )acquires GameMap,Raffle,Player
    {
        let player_addr = signer::address_of(player);
        //raffle game address derivation
        let seed = collection;
        let tmp_seed = token_name;
        append(&mut seed,tmp_seed);
        let raffle_map = &borrow_global<GameMap>(@raffle).raffles;
        assert!(
            table::contains(raffle_map, seed),ENO_RAFFLE_DOESNT_EXISTS
        );
        let raffle_treasury_address=*table::borrow(raffle_map,seed);
        assert!(exists<Raffle>(raffle_treasury_address),ENO_RAFFLE_DOESNT_EXISTS);
        let raffle_data = borrow_global_mut<Raffle>(raffle_treasury_address);
        //time verification
        let now = aptos_framework::timestamp::now_seconds();
        assert!(now>raffle_data.start_time,ENO_NOT_STARTED);
        assert!(now>raffle_data.end_time,ENO_NOT_ENDED);
        assert!(raffle_data.winner==@raffle,ENO_ALREADY_CLAIMED);
        //player verification
        assert!(exists<Player>(player_addr),ENO_NOT_PLAYER);
        let player_data= & borrow_global<Player>(player_addr).raffles;
        assert!(table::contains(player_data,raffle_data.token_info),ENO_NOT_PLAYER);
        //winner_verification
        let ticket_set= table::borrow(player_data,raffle_data.token_info);
        let winner = vector::contains(ticket_set,&raffle_data.winning_ticket);
        assert!(winner,ENO_NOT_WINNER);
        //send the prize
        let token_id = token::create_token_id_raw(raffle_data.token_info.token_creator, collection, token_name, raffle_data.token_info.property_version);
        //verifying the raffle has the token
        assert!(balance_of(raffle_treasury_address,token_id)>=1,ENO_NO_TOKEN);
        let raffle_signer_from_cap = account::create_signer_with_capability(&raffle_data.treasury_cap);
        direct_transfer(&raffle_signer_from_cap,player,token_id,1);
        raffle_data.winner=player_addr;
    }
    /// A helper functions
    //to find the coin_address
    fun coin_address<CoinType>(): address {
        let type_info = type_info::type_of<CoinType>();
        type_info::account_address(&type_info)
    }
    //function to draw the raffle 
    fun draw_raffle(creator_addr:address,tickets_sold:u64):u64
    {
        let x = bcs::to_bytes<address>(&creator_addr);
        let z = bcs::to_bytes<u64>(&aptos_framework::timestamp::now_seconds());
        vector::append(&mut x,z);
        let tmp = hash::sha2_256(x);

        let data = vector<u8>[];
        let i =24;
        while (i < 32)
        {
            let x =vector::borrow(&tmp,i);
            vector::append(&mut data,vector<u8>[*x]);
            i= i+1;
        };
        assert!(tickets_sold>0,999);

        let random = from_bcs::to_u64(data) % tickets_sold + 1;
        if (random == 0 )
        {
            random = 1;
        };
        random
    }
//     #[test_only] 
//     // use aptos_token::token::{create_collection,create_token_script,create_token_id_raw};
//     // use aptos_token::token::withdraw_token;
//     // use aptos_token::token::deposit_token;
//     // use std::string;
//     // use aptos_framework::timestamp;

//     struct MokshyaMoney { }
// //     #[test( raffle = @raffle)]
// //    fun test_init_module(
// //         raffle: signer
// //     ){
// //         init_module(&raffle);
// //     } 
//     fun create_collection_token(creator: &signer)
//     {
//         aptos_token::token::create_collection(
//                 creator,
//                 string::utf8(b"Mokshya Collection"),
//                 string::utf8(b"Collection for Test"),
//                 string::utf8(b"https://github.com/mokshyaprotocol"),
//                 2,
//                 vector<bool>[false, false, false],
//             );
//             let default_keys = vector<String>[string::utf8(b"attack"), string::utf8(b"num_of_use")]; 
//             let default_vals = vector<vector<u8>>[bcs::to_bytes<u64>(&10), bcs::to_bytes<u64>(&5)];
//             let default_types = vector<String>[string::utf8(b"u64"), string::utf8(b"u64")];
//             let mutate_setting = vector<bool>[false, false, false, false, false];
//         aptos_token::token::create_token_script(
//                 creator,
//                 string::utf8(b"Mokshya Collection"),
//                 string::utf8(b"Mokshya Token #1"),
//                 string::utf8(b"Collection for Test"),
//                 2,
//                 5,
//                 string::utf8(b"mokshya.io"),
//                 signer::address_of(creator),
//                 100,
//                 0,
//                 mutate_setting,
//                 default_keys,
//                 default_vals,
//                 default_types,
//             );
//     }
//    #[test( creator = @0xa11ce, player = @0xb0b,raffle = @raffle,framework = @0x1)]
//    fun test_start_raffle(
//         creator:signer,
//         //player: signer,
//         raffle: signer,
//         framework: signer,
//     )  acquires GameMap
//     {
//        let sender_addr = signer::address_of(&creator);
//        //let receiver_addr = signer::address_of(&player);
//         aptos_framework::account::create_account_for_test(sender_addr);
//         aptos_framework::managed_coin::initialize<MokshyaMoney>(
//             &raffle,
//             b"Mokshya Money",
//             b"MOK",
//             10,
//             true
//         );
//         // set up global time for testing purpose
//         aptos_framework::timestamp::set_time_has_started_for_testing(&framework);
//         let now = aptos_framework::timestamp::now_seconds();
//         init_module(&raffle);
//         create_collection_token(&creator);
//         start_raffle<MokshyaMoney>(
//             &creator,
//             sender_addr,
//             string::utf8(b"Mokshya Collection"),
//             string::utf8(b"Mokshya Token #1"),
//             0,
//             now+10000,
//             now+20000,
//             10,
//             1
//         );
//     }
// //         let staking_data = borrow_global<MokshyaStaking>(resource_address);
// //         assert!(staking_data.state==true,88);
// //         assert!(staking_data.dpr==30,78);
// //         assert!(staking_data.amount==95,68);
// //     } 
// //     #[test(creator = @0xa11ce, receiver = @0xb0b, token_staking = @mokshyastaking,framework = @0x1)]
// //     fun test_staking_token(
// //         creator: signer,
// //         receiver: signer,
// //         token_staking: signer,
// //         framework: signer,
// //     )acquires ResourceInfo,MokshyaStaking,MokshyaReward{
// //        let sender_addr = signer::address_of(&creator);
// //        let receiver_addr = signer::address_of(&receiver);
// //        // set up global time for testing purpose
// //         timestamp::set_time_has_started_for_testing(&framework);
// //        // create accounts 
// //         aptos_framework::account::create_account_for_test(sender_addr);
// //         aptos_framework::account::create_account_for_test(receiver_addr);
// //         // create reward coin
// //         aptos_framework::managed_coin::initialize<MokshyaMoney>(
// //             &token_staking,
// //             b"Mokshya Money",
// //             b"MOK",
// //             10,
// //             true
// //         );
// //         aptos_framework::managed_coin::register<MokshyaMoney>(&creator);
// //         aptos_framework::managed_coin::mint<MokshyaMoney>(&token_staking,sender_addr,100); 
// //         //create collection  
// //         create_collection(
// //             &creator,
// //             string::utf8(b"Mokshya Collection"),
// //             string::utf8(b"Collection for Test"),
// //             string::utf8(b"https://github.com/mokshyaprotocol"),
// //             2,
// //             vector<bool>[false, false, false],
// //         );
// //         //token data
// //         let default_keys = vector<String>[string::utf8(b"attack"), string::utf8(b"num_of_use")]; 
// //         let default_vals = vector<vector<u8>>[bcs::to_bytes<u64>(&10), bcs::to_bytes<u64>(&5)];
// //         let default_types = vector<String>[string::utf8(b"u64"), string::utf8(b"u64")];
// //         let mutate_setting = vector<bool>[false, false, false, false, false];
// //         //create token
// //         create_token_script(
// //             &creator,
// //             string::utf8(b"Mokshya Collection"),
// //             string::utf8(b"Mokshya Token #1"),
// //             string::utf8(b"Collection for Test"),
// //             2,
// //             5,
// //             string::utf8(b"https://aptos.dev"),
// //             signer::address_of(&creator),
// //             100,
// //             0,
// //             mutate_setting,
// //             default_keys,
// //             default_vals,
// //             default_types,
// //         );
// //         let token_id=create_token_id_raw(signer::address_of(&creator), string::utf8(b"Mokshya Collection"), 
// //         string::utf8(b"Mokshya Token #1"), 0);
// //         let token = withdraw_token(&creator, token_id, 1);
// //         deposit_token(&receiver, token);
// //         create_staking<MokshyaMoney>(
// //                &creator,
// //                20,
// //                string::utf8(b"Mokshya Collection"),
// //                90);
// //         stake_token(
// //             &receiver,
// //             sender_addr,
// //             string::utf8(b"Mokshya Collection"),
// //             string::utf8(b"Mokshya Token #1"),
// //             0,
// //             1);
// //         let seed = string::utf8(b"Mokshya Collection");
// //         let seed2 = string::utf8(b"Mokshya Token #1");
// //         append(&mut seed,seed2);
// //         let reward_treasury_address = get_resource_address(receiver_addr,seed);
// //         assert!(balance_of(reward_treasury_address,token_id)==1,99);
// //         assert!(balance_of(receiver_addr,token_id)==0,89);
// //         claim_reward<MokshyaMoney>(
// //             &receiver,
// //             string::utf8(b"Mokshya Collection"),
// //             string::utf8(b"Mokshya Token #1"),
// //             sender_addr,
// //         );
// //         unstake_token<MokshyaMoney>( 
// //             &receiver,
// //             sender_addr,
// //             string::utf8(b"Mokshya Collection"),
// //             string::utf8(b"Mokshya Token #1"),
// //             0);
// //         assert!(balance_of(receiver_addr,token_id)==1,79);
// //         assert!(balance_of(reward_treasury_address,token_id)==0,69);
// //         let reward_data = borrow_global<MokshyaReward>(reward_treasury_address);
// //         assert!(reward_data.start_time==0,59);
// //         assert!(reward_data.tokens==0,59);
// //         assert!(reward_data.withdraw_amount==0,59);

// //         //testing restake of token
// //         stake_token(
// //             &receiver,
// //             sender_addr,
// //             string::utf8(b"Mokshya Collection"),
// //             string::utf8(b"Mokshya Token #1"),
// //             0,
// //             1);
// //         assert!(balance_of(reward_treasury_address,token_id)==1,49);
// //         assert!(balance_of(receiver_addr,token_id)==0,49);
// //     } 
}




