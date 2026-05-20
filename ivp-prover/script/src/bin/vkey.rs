//! Print the IVP program verification key.
//! This key gets registered on-chain in ProverRegistry.
//! Anyone can verify proofs against this key.

use sp1_sdk::{ProverClient, include_elf};

pub const IVP_ELF: &[u8] = include_elf!("ivp-program");

fn main() {
    let client = ProverClient::from_env();
    let (_, vk) = client.setup(IVP_ELF);
    println!("IVP Verification Key: {}", vk.bytes32());
    println!("Register this on-chain in ProverRegistry.sol");
}
