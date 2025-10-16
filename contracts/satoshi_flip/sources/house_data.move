module satoshi_flip::house_data;

use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};
use sui::package;
use sui::sui::SUI;

const EInsufficientBalance: u64 = 0;
const ECallerNotHouse: u64 = 1;

public struct HouseData has key {
    id: UID,
    balance: Balance<SUI>, //Game's treasury
    house: address, //House owner's address
    public_key: vector<u8>, //Public key for VRF
    max_stake: u64,
    min_stake: u64,
    fees: Balance<SUI>, //Portion of bets house keeps as profit
    base_fees_in_bp: u16, //Profit fee rate
}

public struct HouseCap has key {
    id: UID,
}

public struct HOUSE_DATA has drop {}

fun init(otw: HOUSE_DATA, ctx: &mut TxContext) {
    package::claim_and_keep(otw, ctx);

    let house_cap = HouseCap { id: object::new(ctx) };

    transfer::transfer(house_cap, ctx.sender());
}

public fun initiliaze_house_data(
    house_cap: HouseCap,
    public_key: vector<u8>,
    coin: Coin<SUI>,
    ctx: &mut TxContext,
) {
    assert!(coin.value() > 0, EInsufficientBalance);

    let house_data = HouseData {
        id: object::new(ctx),
        balance: coin.into_balance(),
        house: ctx.sender(),
        public_key,
        max_stake: 50_000_000_000,
        min_stake: 1_000_000_000,
        fees: balance::zero(),
        base_fees_in_bp: 100, //1% in basis points
    };

    let HouseCap { id } = house_cap;
    id.delete();

    transfer::share_object(house_data);
}

public fun top_up(house_data: &mut HouseData, coin: Coin<SUI>, ctx: &mut TxContext) {
    assert!(ctx.sender()==house_data.house, ECallerNotHouse);
    coin::put(&mut house_data.balance, coin)
}

public fun withdraw(house_data: &mut HouseData, ctx: &mut TxContext) {
    assert!(ctx.sender()==house_data.house, ECallerNotHouse);

    let total_balance = balance(house_data);
    let coin = coin::take(&mut house_data.balance, total_balance, ctx);
    transfer::public_transfer(coin, house_data.house);
}

public fun claim_fees(house_data: &mut HouseData, ctx: &mut TxContext) {
    assert!(ctx.sender()==house_data.house, ECallerNotHouse);

    let total_fees = fees(house_data);
    let coin = coin::take(&mut house_data.fees, total_fees, ctx);

    transfer::public_transfer(coin, house_data.house);
}

public fun update_max_stake(house_data: &mut HouseData, max_stake: u64, ctx: &mut TxContext) {
    assert!(ctx.sender() == house_data.house, ECallerNotHouse);

    house_data.max_stake = max_stake;
}

public fun update_min_stake(house_data: &mut HouseData, min_stake: u64, ctx: &mut TxContext) {
    assert!(ctx.sender() == house_data.house, ECallerNotHouse);

    house_data.min_stake = min_stake;
}

//Getter functions
public fun balance(house_data: &HouseData): u64 {
    house_data.balance.value()
}

public fun fees(house_data: &HouseData): u64 {
    house_data.fees.value()
}

public fun house(house_data: &HouseData): address {
    house_data.house
}

public fun public_key(house_data: &HouseData): vector<u8> {
    house_data.public_key
}

public fun max_stake(house_data: &HouseData): u64 {
    house_data.max_stake
}

public fun min_stake(house_data: &HouseData): u64 {
    house_data.min_stake
}

public fun base_fee_in_bp(house_data: &HouseData): u16 {
    house_data.base_fees_in_bp
}
