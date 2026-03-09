/**
 * Test setup file
 * Creates temporary test directories and cleanup utilities
 */
import * as fs from 'fs';
import * as path from 'path';

// Test directory paths
export const TEST_DIR = path.join(__dirname, 'temp');
export const TEST_DB_PATH = path.join(TEST_DIR, 'test.db');
export const TEST_AUTH_PATH = path.join(TEST_DIR, 'auth.json');
export const TEST_OUTPUT_DIR = path.join(TEST_DIR, 'output');

/**
 * Ensure test directory exists and is clean
 */
export function setupTestDir(): void {
  if (!fs.existsSync(TEST_DIR)) {
    fs.mkdirSync(TEST_DIR, { recursive: true });
  }
  if (!fs.existsSync(TEST_OUTPUT_DIR)) {
    fs.mkdirSync(TEST_OUTPUT_DIR, { recursive: true });
  }
}

/**
 * Clean up test files
 */
export function cleanupTestDir(): void {
  if (fs.existsSync(TEST_DIR)) {
    fs.rmSync(TEST_DIR, { recursive: true, force: true });
  }
}

/**
 * Create a test SQLite database with sample data
 */
export function createTestDatabase(dbPath: string): void {
  const Database = require('better-sqlite3');
  const db = new Database(dbPath);

  // Create message table
  db.exec(`
    CREATE TABLE IF NOT EXISTS message (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      time_created INTEGER NOT NULL,
      data TEXT NOT NULL
    )
  `);

  // Create part table
  db.exec(`
    CREATE TABLE IF NOT EXISTS part (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      time_created INTEGER NOT NULL,
      data TEXT NOT NULL
    )
  `);

  // Insert test messages with providerID
  const now = Date.now();
  const fiveHoursAgo = now - 5 * 60 * 60 * 1000;
  const yesterday = now - 24 * 60 * 60 * 1000;

  const messageData = [
    {
      time_created: now,
      data: JSON.stringify({
        role: 'user',
        time: { created: now },
        providerID: 'anthropic',
        modelID: 'claude-3-opus',
        tokens: {
          total: 1500,
          input: 1000,
          output: 500,
          reasoning: 0,
          cache: { read: 0, write: 0 }
        }
      })
    },
    {
      time_created: now - 1000,
      data: JSON.stringify({
        role: 'assistant',
        time: { created: now - 1000 },
        providerID: 'anthropic',
        modelID: 'claude-3-opus',
        tokens: {
          total: 2500,
          input: 500,
          output: 2000,
          reasoning: 0,
          cache: { read: 1000, write: 0 }
        }
      })
    },
    {
      time_created: fiveHoursAgo,
      data: JSON.stringify({
        role: 'user',
        time: { created: fiveHoursAgo },
        providerID: 'kimi-for-coding',
        modelID: 'kimi-k2',
        tokens: {
          total: 3000,
          input: 2000,
          output: 1000,
          reasoning: 0,
          cache: { read: 0, write: 0 }
        }
      })
    },
    {
      time_created: yesterday,
      data: JSON.stringify({
        role: 'user',
        time: { created: yesterday },
        providerID: 'openai',
        modelID: 'gpt-4',
        tokens: {
          total: 2000,
          input: 1500,
          output: 500,
          reasoning: 100,
          cache: { read: 0, write: 0 }
        }
      })
    },
    {
      time_created: yesterday,
      data: JSON.stringify({
        role: 'user',
        time: { created: yesterday },
        providerID: 'google',
        modelID: 'gemini-pro',
        tokens: {
          total: 1000,
          input: 800,
          output: 200,
          reasoning: 0,
          cache: { read: 0, write: 0 }
        }
      })
    },
    // Message without tokens (should be counted but not added to totals)
    {
      time_created: now,
      data: JSON.stringify({
        role: 'user',
        time: { created: now },
        providerID: 'anthropic',
        modelID: 'claude-3-opus'
        // No tokens field
      })
    },
    // Message with unknown provider (should be skipped)
    {
      time_created: now,
      data: JSON.stringify({
        role: 'user',
        time: { created: now },
        providerID: 'unknown-provider',
        modelID: 'unknown-model',
        tokens: {
          total: 500,
          input: 300,
          output: 200,
          reasoning: 0,
          cache: { read: 0, write: 0 }
        }
      })
    }
  ];

  const insertMessage = db.prepare('INSERT INTO message (time_created, data) VALUES (?, ?)');
  for (const msg of messageData) {
    insertMessage.run(msg.time_created, msg.data);
  }

  // Insert test parts with providerID
  const partData = [
    {
      time_created: now,
      data: JSON.stringify({
        role: 'assistant',
        time: { created: now },
        providerID: 'anthropic',
        modelID: 'claude-3-opus',
        tokens: {
          total: 800,
          input: 200,
          output: 600,
          reasoning: 0,
          cache: { read: 0, write: 0 }
        }
      })
    },
    {
      time_created: fiveHoursAgo,
      data: JSON.stringify({
        role: 'assistant',
        time: { created: fiveHoursAgo },
        providerID: 'kimi-for-coding',
        modelID: 'kimi-k2',
        tokens: {
          total: 1500,
          input: 500,
          output: 1000,
          reasoning: 0,
          cache: { read: 0, write: 0 }
        }
      })
    }
  ];

  const insertPart = db.prepare('INSERT INTO part (time_created, data) VALUES (?, ?)');
  for (const part of partData) {
    insertPart.run(part.time_created, part.data);
  }

  db.close();
}

/**
 * Create a test auth.json file
 */
export function createTestAuthFile(authPath: string, providers: string[]): void {
  const authData: Record<string, { apiKey: string }> = {};
  for (const provider of providers) {
    authData[provider] = { apiKey: `test-api-key-${provider}` };
  }
  fs.writeFileSync(authPath, JSON.stringify(authData, null, 2));
}
