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

    let elf: Elf = IVP_ELF_BYTES.into();

    let lender: [u8; 20] = [0x1d; 20];
    let paid_debt_slot   = slot_from_index(7);
    let paid_shares_slot = slot_from_index(8);

    let ghost_guard = CompiledInvariant {
        id:   constraint_id("PaidDebtGhostShareGuard"),
        tier: InvariantTier::Simple,
        name: "PaidDebtGhostShareGuard".to_string(),
        constraint: ConstraintExpr::Implies(
            Box::new(ConstraintExpr::Eq(
                Box::new(ConstraintExpr::Read { contract: lender, slot: paid_debt_slot }),
                Box::new(ConstraintExpr::Literal(zero())),
            )),
            Box::new(ConstraintExpr::Eq(
                Box::new(ConstraintExpr::Read { contract: lender, slot: paid_shares_slot }),
                Box::new(ConstraintExpr::Literal(zero())),
            )),
        ),
        slot_refs: vec![
            SlotRef { contract: lender, slot: paid_debt_slot,   label: "totalPaidDebt".to_string() },
            SlotRef { contract: lender, slot: paid_shares_slot, label: "totalPaidDebtShares".to_string() },
        ],
    };

    let mut ghost_shares = [0u8; 32];
    ghost_shares[5] = 0x08;

    let snapshot = StateSnapshot {
        block_number: 22_418_441,
        state_root:   [0u8; 32],
        reads: vec![
            StorageRead { contract: lender, slot: paid_debt_slot,   value: [0u8; 32],   proof: vec![] },
            StorageRead { contract: lender, slot: paid_shares_slot, value: ghost_shares, proof: vec![] },
        ],
    };

    let input = EpochInput {
        protocol_id: constraint_id("monolith-lender"),
        epoch_id:    1,
        snapshot,
        invariants:  vec![ghost_guard],
    };

    let mut stdin = SP1Stdin::new();
    stdin.write(&input);

    println!("Executing program inside zkVM...");
    let client = ProverClient::builder().cpu().build();
    let (mut public_values, report) = client.execute(elf, stdin).run().unwrap();
    let result: EpochResult = public_values.read::<EpochResult>();

    println!("\n=== IVP EXECUTION RESULT ===");
    println!("Epoch:    {}", result.epoch_id);
    println!("Violated: {}", result.violated);

    if result.violated {
        println!("\n*** INVARIANT VIOLATION DETECTED ***");
        if let Some(w) = &result.witness {
            println!("Invariant: {}", w.invariant_name);
            println!("Details:   {}", w.description);
        }
    } else {
        println!("All invariants satisfied.");
    }

    println!("\nTotal instructions: {}", report.total_instruction_count());
}

fn slot_from_index(i: u32) -> [u8; 32] {
    let mut s = [0u8; 32];
    s[28..].copy_from_slice(&i.to_be_bytes());
    s
}

fn constraint_id(name: &str) -> [u8; 32] {
    let mut h = Keccak256::new();
    h.update(name.as_bytes());
    let r = h.finalize();
    let mut id = [0u8; 32];
    id.copy_from_slice(&r);
    id
}
