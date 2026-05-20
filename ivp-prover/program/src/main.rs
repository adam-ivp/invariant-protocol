#![no_main]
sp1_zkvm::entrypoint!(main);

use ivp_lib::{EpochInput, EpochResult, Witness, evaluate};

pub fn main() {
    let input: EpochInput = sp1_zkvm::io::read::<EpochInput>();

    let mut violated = false;
    let mut violating_invariant: Option<u64> = None;
    let mut witness: Option<Witness> = None;

    for (idx, invariant) in input.invariants.iter().enumerate() {
        let (satisfied, failing_reads) = evaluate(&invariant.constraint, &input.snapshot);

        if !satisfied {
            violated = true;
            violating_invariant = Some(idx as u64);
            witness = Some(Witness {
                invariant_name: invariant.name.clone(),
                failing_reads,
                description: format!(
                    "Invariant '{}' violated at block {}",
                    invariant.name,
                    input.snapshot.block_number
                ),
            });
            break;
        }
    }

    let result = EpochResult {
        protocol_id:         input.protocol_id,
        epoch_id:            input.epoch_id,
        state_root:          input.snapshot.state_root,
        violated,
        violating_invariant,
        witness,
    };

    sp1_zkvm::io::commit(&result);
}
