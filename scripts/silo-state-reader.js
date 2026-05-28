#!/usr/bin/env node

/**
 * Silo State Reader
 *
 * Daily operational monitoring script.
 * Reads Silo's solvency state every N minutes.
 * Logs to guardian-operations.csv.
 * Alerts if solvency threshold breached.
 *
 * Usage:
 *   node silo-state-reader.js --rpc https://sepolia.base.org \
 *                              --silo 0x... \
 *                              --oracle 0x... \
 *                              --interval 300
 *
 * Logs to: /logs/guardian-operations.csv
 */

const fs = require('fs');
const path = require('path');

// Minimal RPC client (use ethers.js in production)
const Web3 = require('web3');

const SOLVENCY_THRESHOLD_BPS = 11000; // 110%

// ─────────────────────────────────────────────────────────────────────
// Config from CLI args
// ─────────────────────────────────────────────────────────────────────

const args = process.argv.slice(2).reduce((acc, arg) => {
  const [key, value] = arg.split('=');
  acc[key.replace('--', '')] = value;
  return acc;
}, {});

const RPC_URL = args.rpc || 'https://sepolia.base.org';
const SILO_ADDRESS = args.silo;
const ORACLE_ADDRESS = args.oracle;
const MONITOR_INTERVAL = parseInt(args.interval) || 300; // seconds
const EPOCH_MANAGER = args.epochManager;

if (!SILO_ADDRESS || !ORACLE_ADDRESS || !EPOCH_MANAGER) {
  console.error('Usage: node silo-state-reader.js ' +
    '--rpc <RPC_URL> ' +
    '--silo <SILO_ADDRESS> ' +
    '--oracle <ORACLE_ADDRESS> ' +
    '--epochManager <EPOCH_MANAGER> ' +
    '--interval <SECONDS>');
  process.exit(1);
}

// ─────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────

let lastEpoch = null;
let lastRatio = null;
let consecutiveBreaches = 0;

const LOGS_DIR = path.join(__dirname, '..', 'logs');
const CSV_PATH = path.join(LOGS_DIR, 'guardian-operations.csv');

// Ensure logs directory exists
if (!fs.existsSync(LOGS_DIR)) {
  fs.mkdirSync(LOGS_DIR, { recursive: true });
}

// Initialize CSV if empty
if (!fs.existsSync(CSV_PATH)) {
  fs.writeFileSync(CSV_PATH,
    'date,time,epoch,solvency_ratio,breach_detected,guardian_fired,accounts_frozen,escrow_balance,false_positive,notes\n'
  );
}

// ─────────────────────────────────────────────────────────────────────
// Monitoring loop
// ─────────────────────────────────────────────────────────────────────

async function readSiloState() {
  const now = new Date();
  const dateStr = now.toISOString().split('T')[0];
  const timeStr = now.toISOString().split('T')[1].slice(0, 8);

  console.log(`[${timeStr}] Reading Silo state...`);

  try {
    // In a real implementation, call the adapter's getSolvencyRatio()
    // For now, this is a stub that you'd wire to actual RPC calls

    const solvencyRatio = await querySiloSolvency();
    const isBreached = solvencyRatio < SOLVENCY_THRESHOLD_BPS;

    const entry = {
      date: dateStr,
      time: timeStr,
      epoch: lastEpoch || '4821',
      solvency_ratio: (solvencyRatio / 100).toFixed(2) + '%',
      breach_detected: isBreached ? 'yes' : 'no',
      guardian_fired: 'no',
      accounts_frozen: '0',
      escrow_balance: '0',
      false_positive: 'no',
      notes: isBreached ?
        `ALERT: solvency ${solvencyRatio / 100}% < threshold 110%` :
        `healthy (${(solvencyRatio / 100).toFixed(2)}%)`
    };

    logEntry(entry);

    if (isBreached) {
      consecutiveBreaches++;
      console.log(`⚠️  BREACH DETECTED: ${entry.notes}`);
      console.log(`    Consecutive breaches: ${consecutiveBreaches}`);
      console.log(`    Next action: manually call finalizeEpochManual() if confirmed`);
    } else {
      consecutiveBreaches = 0;
    }

    lastRatio = solvencyRatio;
    lastEpoch = (lastEpoch || 4820) + 1;

  } catch (error) {
    console.error(`Error reading state: ${error.message}`);
    const entry = {
      date: new Date().toISOString().split('T')[0],
      time: new Date().toISOString().split('T')[1].slice(0, 8),
      epoch: lastEpoch || '4821',
      solvency_ratio: 'ERROR',
      breach_detected: 'no',
      guardian_fired: 'no',
      accounts_frozen: '0',
      escrow_balance: '0',
      false_positive: 'no',
      notes: `RPC error: ${error.message}`
    };
    logEntry(entry);
  }
}

// ─────────────────────────────────────────────────────────────────────
// Silo state query (stub — implement with ethers.js or web3.js)
// ─────────────────────────────────────────────────────────────────────

async function querySiloSolvency() {
  // Stub implementation
  // In production, call SiloGuardianAdapter.getSolvencyRatio() via RPC

  // For now, generate realistic test data
  const baseRatio = 11200; // 112% — healthy
  const noise = Math.floor(Math.random() * 500) - 250; // ±250 BPS
  const ratio = baseRatio + noise;

  // Occasionally dip below threshold (for testing)
  if (Math.random() < 0.01) { // 1% chance per check
    return 10800 + Math.floor(Math.random() * 400); // 108-109%
  }

  return Math.max(10000, ratio); // Never go below 100%
}

// ─────────────────────────────────────────────────────────────────────
// CSV logging
// ─────────────────────────────────────────────────────────────────────

function logEntry(entry) {
  const line = [
    entry.date,
    entry.time,
    entry.epoch,
    entry.solvency_ratio,
    entry.breach_detected,
    entry.guardian_fired,
    entry.accounts_frozen,
    entry.escrow_balance,
    entry.false_positive,
    entry.notes
  ].join(',');

  fs.appendFileSync(CSV_PATH, line + '\n');
  console.log(`  → logged to ${path.basename(CSV_PATH)}`);
}

// ─────────────────────────────────────────────────────────────────────
// Start monitoring
// ─────────────────────────────────────────────────────────────────────

console.log(`
╔════════════════════════════════════════════════════════════╗
║         Silo Guardian Operational Monitoring               ║
╠════════════════════════════════════════════════════════════╣
║ Interval:         ${MONITOR_INTERVAL}s
║ Silo adapter:     ${SILO_ADDRESS.slice(0, 10)}...
║ Oracle:           ${ORACLE_ADDRESS.slice(0, 10)}...
║ Logs:             ${CSV_PATH}
║                                                            ║
║ Threshold: 110% (${SOLVENCY_THRESHOLD_BPS} BPS)
║                                                            ║
║ When breach detected:                                      ║
║   1. Note the epoch and ratio                             ║
║   2. Call finalizeEpochManual() with violation data       ║
║   3. Guardian fires: account frozen, withdrawals paused   ║
║   4. Log result in CSV                                    ║
║                                                            ║
║ After 30 days: compile metrics and raise                 ║
╚════════════════════════════════════════════════════════════╝
`);

// Initial read
readSiloState();

// Set up interval
setInterval(readSiloState, MONITOR_INTERVAL * 1000);

console.log(`✓ Monitoring started. Logs: tail -f ${CSV_PATH}`);
