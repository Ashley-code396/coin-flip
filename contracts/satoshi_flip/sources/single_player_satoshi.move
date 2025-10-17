module satoshi_flip::single_player_satoshi;

use satoshi_flip::counter_nft::Counter;
use satoshi_flip::house_data::HouseData;
use std::string::String;
use sui::balance::Balance;
use sui::bls12381::bls12381_min_pk_verify;
use sui::coin::{Self, Coin};
use sui::dynamic_object_field as dof;
use sui::event::emit;
use sui::hash::blake2b256;
use sui::sui::SUI;

const EPOCHS_CANCEL_AFTER: u64 = 7;
const GAME_RETURN: u8 = 2;
const PLAYER_WON_STATE: u8 = 1;
const HOUSE_WON_STATE: u8 = 2;
const CHALLENGED_STATE: u8 = 3;
const HEADS: vector<u8> = b"H";
const TAILS: vector<u8> = b"T";

const EStakeTooLow: u64 = 0;
const EStakeTooHigh: u64 = 1;
const EInvalidBlsSig: u64 = 2;
const ECanNotChallengeYet: u64 = 3;
const EInvalidGuess: u64 = 4;
const EInsufficientHouseBalance: u64 = 5;
const EGameDoesNotExist: u64 = 6;

public struct NewGame has copy, drop {
    game_id: ID,
    player: address,
    vrf_input: vector<u8>,
    guess: String,
    user_stake: u64,
    fee_bp: u16,
}

public struct Outcome has copy, drop {
    game_id: ID,
    status: u8,
}

public struct Game has key, store {
    id: UID,
    guess_placed_epoch: u64,
    total_stake: Balance<SUI>,
    guess: String,
    player: address,
    vrf_input: vector<u8>,
    fee_bp: u16,
}

public fun finish_game(
    game_id: ID,
    bls_sig: vector<u8>,
    house_data: &mut HouseData,
    ctx: &mut TxContext,
) {
    // Ensure that the game exists.
    assert!(game_exists(house_data, game_id), EGameDoesNotExist);

    let Game {
        id,
        guess_placed_epoch: _,
        mut total_stake,
        guess,
        player,
        vrf_input,
        fee_bp,
    } = dof::remove<ID, Game>(house_data.borrow_mut(), game_id);

    object::delete(id);

    // Step 1: Check the BLS signature, if its invalid abort.
    let is_sig_valid = bls12381_min_pk_verify(&bls_sig, &house_data.public_key(), &vrf_input);
    assert!(is_sig_valid, EInvalidBlsSig);

    // Hash the beacon before taking the 1st byte.
    let hashed_beacon = blake2b256(&bls_sig);
    // Step 2: Determine winner.
    let first_byte = hashed_beacon[0];
    let player_won = map_guess(guess) == (first_byte % 2);

    // Step 3: Distribute funds based on result.
    let status = if (player_won) {
        // Step 3.a: If player wins transfer the game balance as a coin to the player.
        // Calculate the fee and transfer it to the house.
        let stake_amount = total_stake.value();
        let fee_amount = fee_amount(stake_amount, fee_bp);
        let fees = total_stake.split(fee_amount);
        house_data.borrow_fees_mut().join(fees);

        // Calculate the rewards and take it from the game stake.
        transfer::public_transfer(total_stake.into_coin(ctx), player);
        PLAYER_WON_STATE
    } else {
        // Step 3.b: If house wins, then add the game stake to the house_data.house_balance (no fees are taken).
        house_data.borrow_balance_mut().join(total_stake);
        HOUSE_WON_STATE
    };

    emit(Outcome {
        game_id,
        status,
    });
}

