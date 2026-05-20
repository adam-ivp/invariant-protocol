use sp1_sdk::blocking::{ProverClient, SP1Stdin, Elf, Prover};
use ivp_lib::{
    EpochInput, EpochResult, StateSnapshot, StorageRead,
    CompiledInvariant, InvariantTier, ConstraintExpr, SlotRef, zero,
};
use sha3::{Digest, Keccak256};

const IVP_ELF_BYTES: &[u8] = include_bytes!(
    "../../../target/elf-compilation/riscv64im-succinct-zkvm-elf/release/ivp-program"
);

fn main() {
    sp1_sdk::utils::setup_logger();
    println!("IVP Prover Node starting...");
    println!("Target: Aave V3 Mainnet");
    println!("Protocol: 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2");

    let elf: Elf = IVP_ELF_BYTES.into();

    // Aave V3 Pool contract
    let aave_pool: [u8; 20] = hex_to_addr("87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2");

    // USDC reserve configuration slot
    // getConfiguration returns packed bitmap at storage mapping
    // LTV = config & 0xFFFF = 7500 (75%)
    // If governance calls setReserveLtvzero(USDC), LTV becomes 0
    // but eMode bitmap stays unchanged — that's the finding

    // Simulate post-setReserveLtvzero state:
    // LTV = 0 but eMode bitmap NOT updated (the bug)
    let mut ltv_zeroed_config = [0u8; 32];
    // LTV bits [0:15] = 0 (zeroed by governance)
    // liquidation threshold bits [16:31] = 7800 (unchanged)
    // rest of config unchanged
    let post_ltvzero: u128 = 0x7800_0000_0000_0000_0000_0000_0000_0000;
    ltv_zeroed_config[16..].copy_from_slice(&post_ltvzero.to_be_bytes());

    // eMode bitmap — NOT updated (the bug)
    // bit for USDC should be set to 1 after setReserveLtvzero
    // but it stays 0 because the function doesn't update it
    let emode_bitmap_not_updated = [0u8; 32]; // 0 = not marked as zeroed

    // The EModeSync invariant:
    // IF ltv == 0 THEN ltvzeroBitmap[asset] must == 1
    // Here: ltv == 0 AND bitmap == 0 — VIOLATION
    let emode_sync = CompiledInvariant {
        id:   constraint_id("EModeSync"),
        tier: InvariantTier::Compound,
        name: "EModeSync".to_string(),
        constraint: ConstraintExpr::Implies(
            // antecedent: LTV == 0
            Box::new(ConstraintExpr::Eq(
                Box::new(ConstraintExpr::Read {
                    contract: aave_pool,
                    slot: slot_from_index(0),  // LTV slot
                }),
                Box::new(ConstraintExpr::Literal(zero())),
            )),
            // consequent: eMode bitmap must be 1
            Box::new(ConstraintExpr::Eq(
                Box::new(ConstraintExpr::Read {
                    contract: aave_pool,
                    slot: slot_from_index(1),  // eMode bitmap slot
                }),
                Box::new(ConstraintExpr::Literal(one())),
            )),
        ),
        slot_refs: vec![
            SlotRef { contract: aave_pool, slot: slot_from_index(0), label: "usdc_ltv".to_string() },
            SlotRef { contract: aave_pool, slot: slot_from_index(1), label: "emode_ltvzero_bitmap".to_string() },
        ],
    };

    // State after governance calls setReserveLtvzero(USDC):
    // LTV = 0 (correctly zeroed)
    // eMode bitmap = 0 (NOT updated — the bug)
    let snapshot = StateSnapshot {
        block_number: 22_418_441,
        state_root:   [0u8; 32],
        reads: vec![
            StorageRead {
                contract: aave_pool,
                slot:     slot_from_index(0),
                value:    [0u8; 32],                 // LTV = 0
                proof:    vec![],
            },
            StorageRead {
                contract: aave_pool,
                slot:     slot_from_index(1),
                value:    emode_bitmap_not_updated,  // bitmap NOT updated
                proof:    vec![],
            },
        ],
    };

    let input = EpochInput {
        protocol_id: constraint_id("aave-v3-mainnet"),
        epoch_id:    1,
        snapshot,
        invariants:  vec![emode_sync],
    };

    let mut stdin = SP1Stdin::new();
    stdin.write(&input);

    println!("\nEvaluating EModeSync invariant...");
    println!("State: USDC LTV = 0 (post-setReserveLtvzero)");
    println!("State: eMode bitmap = 0 (NOT updated — the bug)");

    let client = ProverClient::builder().cpu().build();
    let (mut public_values, report) = client.execute(elf, stdin).run().unwrap();
    let result: EpochResult = public_values.read::<EpochResult>();

    println!("\n=== IVP EXECUTION RESULT ===");
    println!("Protocol: Aave V3 Mainnet");
    println!("Epoch:    {}", result.epoch_id);
    println!("Violated: {}", result.violated);

    if result.violated {
        println!("\n*** INVARIANT VIOLATION DETECTED ***");
        if let Some(w) = &result.witness {
            println!("Invariant: {}", w.invariant_name);
            println!("Details:   {}", w.description);
            println!("\nRoot cause: setReserveLtvzero() zeros LTV but does not");
            println!("update the eMode ltvzeroBitmap. eMode borrowers bypass");
            println!("the governance risk reduction and keep borrowing at old LTV.");
        }
    } else {
        println!("All invariants satisfied.");
    }

    println!("\nTotal instructions: {}", report.total_instruction_count());
}

fn hex_to_addr(hex: &str) -> [u8; 20] {
    let bytes = hex::decode(hex).unwrap();
    let mut addr = [0u8; 20];
    addr.copy_from_slice(&bytes);
    addr
}

fn slot_from_index(i: u32) -> [u8; 32] {
    let mut s = [0u8; 32];
    s[28..].copy_from_slice(&i.to_be_bytes());
    s
}

fn one() -> [u8; 32] {
    let mut b = [0u8; 32];
    b[31] = 1;
    b
}

fn constraint_id(name: &str) -> [u8; 32] {
    let mut h = Keccak256::new();
    h.update(name.as_bytes());
    let r = h.finalize();
    let mut id = [0u8; 32];
    id.copy_from_slice(&r);
    id
}
