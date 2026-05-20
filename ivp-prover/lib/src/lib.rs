//! IVP Core Types
//! Shared between the SP1 zkVM program and the host node.
//! These define exactly what goes into the ZK proof and what comes out.

use serde::{Deserialize, Serialize};

// ============================================================
// STORAGE TYPES
// ============================================================

/// A single storage slot read from an EVM contract.
/// Includes a merkle proof so the zkVM can verify it against a state root.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StorageRead {
    pub contract: [u8; 20],
    pub slot:     [u8; 32],
    pub value:    [u8; 32],
    pub proof:    Vec<Vec<u8>>,
}

/// Snapshot of all storage slots relevant to a protocol's invariants
/// at a specific block.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StateSnapshot {
    pub block_number: u64,
    pub state_root:   [u8; 32],
    pub reads:        Vec<StorageRead>,
}

// ============================================================
// INVARIANT TYPES
// ============================================================

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum InvariantTier {
    Simple,
    Compound,
    Temporal,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SlotRef {
    pub contract: [u8; 20],
    pub slot:     [u8; 32],
    pub label:    String,
}

/// A compiled invariant constraint.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CompiledInvariant {
    pub id:         [u8; 32],
    pub tier:       InvariantTier,
    pub name:       String,
    pub constraint: ConstraintExpr,
    pub slot_refs:  Vec<SlotRef>,
}

/// Constraint expression tree.
/// ISL compiler outputs this. Prover evaluates it inside zkVM.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ConstraintExpr {
    Read { contract: [u8; 20], slot: [u8; 32] },
    Literal([u8; 32]),
    Eq(Box<ConstraintExpr>, Box<ConstraintExpr>),
    Neq(Box<ConstraintExpr>, Box<ConstraintExpr>),
    Gt(Box<ConstraintExpr>, Box<ConstraintExpr>),
    Lt(Box<ConstraintExpr>, Box<ConstraintExpr>),
    Gte(Box<ConstraintExpr>, Box<ConstraintExpr>),
    Lte(Box<ConstraintExpr>, Box<ConstraintExpr>),
    Add(Box<ConstraintExpr>, Box<ConstraintExpr>),
    Sub(Box<ConstraintExpr>, Box<ConstraintExpr>),
    Mul(Box<ConstraintExpr>, Box<ConstraintExpr>),
    Div(Box<ConstraintExpr>, Box<ConstraintExpr>),
    And(Box<ConstraintExpr>, Box<ConstraintExpr>),
    Or(Box<ConstraintExpr>, Box<ConstraintExpr>),
    Not(Box<ConstraintExpr>),
    Implies(Box<ConstraintExpr>, Box<ConstraintExpr>),
    ForAll {
        keys:      Vec<[u8; 32]>,
        slot_fn:   Box<ConstraintExpr>,
        condition: Box<ConstraintExpr>,
    },
    Sum {
        keys:    Vec<[u8; 32]>,
        slot_fn: Box<ConstraintExpr>,
    },
}

// ============================================================
// EPOCH TYPES
// ============================================================

/// Input to the SP1 prover program.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EpochInput {
    pub protocol_id: [u8; 32],
    pub epoch_id:    u64,
    pub snapshot:    StateSnapshot,
    pub invariants:  Vec<CompiledInvariant>,
}

/// Output from the SP1 prover program — public inputs to on-chain verifier.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EpochResult {
    pub protocol_id:         [u8; 32],
    pub epoch_id:            u64,
    pub state_root:          [u8; 32],
    pub violated:            bool,
    pub violating_invariant: Option<u64>,
    pub witness:             Option<Witness>,
}

/// The violation witness — exact storage values that broke the invariant.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Witness {
    pub invariant_name: String,
    pub failing_reads:  Vec<StorageRead>,
    pub description:    String,
}

// ============================================================
// CONSTRAINT EVALUATOR
// ============================================================

/// Evaluate a constraint against a state snapshot.
/// Returns (satisfied, failing_reads).
/// This runs inside the SP1 zkVM — pure deterministic logic.
pub fn evaluate(expr: &ConstraintExpr, snapshot: &StateSnapshot) -> (bool, Vec<StorageRead>) {
    match expr {
        ConstraintExpr::Implies(ant, con) => {
            let (ant_val, _) = evaluate(ant, snapshot);
            if !ant_val {
                return (true, vec![]);
            }
            let (con_val, witness) = evaluate(con, snapshot);
            if !con_val {
                return (false, witness);
            }
            (true, vec![])
        }

        ConstraintExpr::And(l, r) => {
            let (lv, lw) = evaluate(l, snapshot);
            if !lv { return (false, lw); }
            let (rv, rw) = evaluate(r, snapshot);
            if !rv { return (false, rw); }
            (true, vec![])
        }

        ConstraintExpr::Or(l, r) => {
            let (lv, _) = evaluate(l, snapshot);
            if lv { return (true, vec![]); }
            evaluate(r, snapshot)
        }

        ConstraintExpr::Not(inner) => {
            let (v, w) = evaluate(inner, snapshot);
            (!v, w)
        }

        ConstraintExpr::Eq(l, r) => {
            let lv = eval_u256(l, snapshot);
            let rv = eval_u256(r, snapshot);
            if lv != rv {
                let witness = collect_reads(l, snapshot)
                    .into_iter()
                    .chain(collect_reads(r, snapshot))
                    .collect();
                return (false, witness);
            }
            (true, vec![])
        }

        ConstraintExpr::Neq(l, r) => {
            let lv = eval_u256(l, snapshot);
            let rv = eval_u256(r, snapshot);
            if lv == rv {
                let witness = collect_reads(l, snapshot)
                    .into_iter()
                    .chain(collect_reads(r, snapshot))
                    .collect();
                return (false, witness);
            }
            (true, vec![])
        }

        ConstraintExpr::Gt(l, r) => {
            let lv = to_u128(eval_u256(l, snapshot));
            let rv = to_u128(eval_u256(r, snapshot));
            if lv <= rv {
                let witness = collect_reads(l, snapshot)
                    .into_iter()
                    .chain(collect_reads(r, snapshot))
                    .collect();
                return (false, witness);
            }
            (true, vec![])
        }

        ConstraintExpr::Gte(l, r) => {
            let lv = to_u128(eval_u256(l, snapshot));
            let rv = to_u128(eval_u256(r, snapshot));
            if lv < rv {
                let witness = collect_reads(l, snapshot)
                    .into_iter()
                    .chain(collect_reads(r, snapshot))
                    .collect();
                return (false, witness);
            }
            (true, vec![])
        }

        ConstraintExpr::Lt(l, r) => {
            let lv = to_u128(eval_u256(l, snapshot));
            let rv = to_u128(eval_u256(r, snapshot));
            if lv >= rv {
                let witness = collect_reads(l, snapshot)
                    .into_iter()
                    .chain(collect_reads(r, snapshot))
                    .collect();
                return (false, witness);
            }
            (true, vec![])
        }

        ConstraintExpr::Lte(l, r) => {
            let lv = to_u128(eval_u256(l, snapshot));
            let rv = to_u128(eval_u256(r, snapshot));
            if lv > rv {
                let witness = collect_reads(l, snapshot)
                    .into_iter()
                    .chain(collect_reads(r, snapshot))
                    .collect();
                return (false, witness);
            }
            (true, vec![])
        }

        ConstraintExpr::ForAll { keys, slot_fn: _, condition } => {
            for _key in keys {
                let (ok, w) = evaluate(condition, snapshot);
                if !ok { return (false, w); }
            }
            (true, vec![])
        }

        _ => (true, vec![]),
    }
}

pub fn eval_u256(expr: &ConstraintExpr, snapshot: &StateSnapshot) -> [u8; 32] {
    match expr {
        ConstraintExpr::Read { contract, slot } => {
            snapshot.reads.iter()
                .find(|r| &r.contract == contract && &r.slot == slot)
                .map(|r| r.value)
                .unwrap_or([0u8; 32])
        }
        ConstraintExpr::Literal(v) => *v,
        ConstraintExpr::Add(l, r) => {
            from_u128(to_u128(eval_u256(l, snapshot))
                .saturating_add(to_u128(eval_u256(r, snapshot))))
        }
        ConstraintExpr::Sub(l, r) => {
            from_u128(to_u128(eval_u256(l, snapshot))
                .saturating_sub(to_u128(eval_u256(r, snapshot))))
        }
        ConstraintExpr::Mul(l, r) => {
            from_u128(to_u128(eval_u256(l, snapshot))
                .saturating_mul(to_u128(eval_u256(r, snapshot))))
        }
        ConstraintExpr::Div(l, r) => {
            let rv = to_u128(eval_u256(r, snapshot));
            if rv == 0 { return [0u8; 32]; }
            from_u128(to_u128(eval_u256(l, snapshot)) / rv)
        }
        ConstraintExpr::Sum { keys, slot_fn } => {
            let mut total: u128 = 0;
            for _key in keys {
                total = total.saturating_add(to_u128(eval_u256(slot_fn, snapshot)));
            }
            from_u128(total)
        }
        _ => [0u8; 32],
    }
}

fn collect_reads(expr: &ConstraintExpr, snapshot: &StateSnapshot) -> Vec<StorageRead> {
    match expr {
        ConstraintExpr::Read { contract, slot } => {
            snapshot.reads.iter()
                .filter(|r| &r.contract == contract && &r.slot == slot)
                .cloned()
                .collect()
        }
        _ => vec![],
    }
}

pub fn to_u128(bytes: [u8; 32]) -> u128 {
    let mut arr = [0u8; 16];
    arr.copy_from_slice(&bytes[16..]);
    u128::from_be_bytes(arr)
}

pub fn from_u128(val: u128) -> [u8; 32] {
    let mut bytes = [0u8; 32];
    bytes[16..].copy_from_slice(&val.to_be_bytes());
    bytes
}

pub fn zero() -> [u8; 32] { [0u8; 32] }

pub fn one() -> [u8; 32] {
    let mut b = [0u8; 32];
    b[31] = 1;
    b
}

// ============================================================
// TESTS
// ============================================================

#[cfg(test)]
mod tests {
    use super::*;

    fn lender() -> [u8; 20] { [0x1d; 20] }

    fn slot(i: u32) -> [u8; 32] {
        let mut s = [0u8; 32];
        s[28..].copy_from_slice(&i.to_be_bytes());
        s
    }

    fn ghost_snapshot() -> StateSnapshot {
        // Ghost state: totalPaidDebt=0, totalPaidDebtShares=10000e18
        let mut shares = [0u8; 32];
        shares[5] = 0x08; // ~10000e18 approximation
        StateSnapshot {
            block_number: 22_418_441,
            state_root:   [0u8; 32],
            reads: vec![
                StorageRead {
                    contract: lender(),
                    slot:     slot(7), // totalPaidDebt
                    value:    [0u8; 32], // == 0
                    proof:    vec![],
                },
                StorageRead {
                    contract: lender(),
                    slot:     slot(8), // totalPaidDebtShares
                    value:    shares,  // != 0
                    proof:    vec![],
                },
            ],
        }
    }

    fn clean_snapshot() -> StateSnapshot {
        StateSnapshot {
            block_number: 22_418_441,
            state_root:   [0u8; 32],
            reads: vec![
                StorageRead {
                    contract: lender(),
                    slot:     slot(7),
                    value:    [0u8; 32],
                    proof:    vec![],
                },
                StorageRead {
                    contract: lender(),
                    slot:     slot(8),
                    value:    [0u8; 32], // also zero — clean state
                    proof:    vec![],
                },
            ],
        }
    }

    /// PaidDebtGhostShareGuard:
    /// totalPaidDebt == 0 implies totalPaidDebtShares == 0
    fn ghost_share_invariant() -> ConstraintExpr {
        ConstraintExpr::Implies(
            Box::new(ConstraintExpr::Eq(
                Box::new(ConstraintExpr::Read { contract: lender(), slot: slot(7) }),
                Box::new(ConstraintExpr::Literal(zero())),
            )),
            Box::new(ConstraintExpr::Eq(
                Box::new(ConstraintExpr::Read { contract: lender(), slot: slot(8) }),
                Box::new(ConstraintExpr::Literal(zero())),
            )),
        )
    }

    #[test]
    fn test_ghost_share_violation_detected() {
        let (satisfied, witness) = evaluate(&ghost_share_invariant(), &ghost_snapshot());
        assert!(!satisfied, "Should detect ghost share violation");
        assert!(!witness.is_empty(), "Should return witness");
        println!("VIOLATION DETECTED: PaidDebtGhostShareGuard");
        println!("Witness reads: {}", witness.len());
    }

    #[test]
    fn test_clean_state_passes() {
        let (satisfied, _) = evaluate(&ghost_share_invariant(), &clean_snapshot());
        assert!(satisfied, "Clean state should pass");
        println!("CLEAN: PaidDebtGhostShareGuard satisfied");
    }
}
