module satoshi_flip::counter_nft;

use sui::bcs;

public struct Counter has key {
    id: UID,
    count: u64,
}

public fun mint(ctx: &mut TxContext): Counter {
    let counter = Counter {
        id: object::new(ctx),
        count: 0,
    };
    counter
}

entry fun burn(counter: Counter) {
    let Counter { id, count: _ } = counter;
    id.delete()
}

public fun transfer_to_sender(counter: Counter, ctx: &mut TxContext) {
    transfer::transfer(counter, ctx.sender());
}

public fun get_vrf_input_and_increment(self: &mut Counter): vector<u8> {
    let mut vrf_input = object::id_bytes(self);
    let count_to_bytes = bcs::to_bytes(&count(self));
    vrf_input.append(count_to_bytes);
    self.increment();
    vrf_input
}

public fun count(self: &Counter): u64 {
    self.count
}

fun increment(self: &mut Counter) {
    self.count = self.count + 1;
}
