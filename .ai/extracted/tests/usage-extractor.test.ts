/**
 * Comprehensive tests for usage-extractor.ts
 * 
 * Tests cover:
 * - SQLite database connectivity and querying
 * - Auth.json reading and provider detection
 * - Message/part table queries
 * - Rolling 5-hour window calculations
 * - Weekly usage calculations
 * - JSON output format validation
 * - Error handling for missing files
 */

import * as fs from 'fs';
import * as path from 'path';
import DatabaseConstructor from 'better-sqlite3';
import {
  readAuthConfig,
  calculateRolling5HourWindows,
  calculateWeeklyUsage,
  extractUsageData
} from '../usage-extractor';
import {
  TEST_DIR,
  TEST_DB_PATH,
  TEST_AUTH_PATH,
  TEST_OUTPUT_DIR,
  createTestDatabase,
  createTestAuthFile,
  cleanupTestDir,
  setupTestDir
} from './setup';

const Database = DatabaseConstructor;

describe('Usage Extractor', () => {
  beforeEach(() => {
    cleanupTestDir();
    setupTestDir();
  });

  afterEach(() => {
    cleanupTestDir();
  });

  describe('readAuthConfig', () => {
    it('should read auth.json and return list of connected providers', () => {
      const providers = ['anthropic', 'openai', 'google'];
      createTestAuthFile(TEST_AUTH_PATH, providers);

      const result = readAuthConfig(TEST_AUTH_PATH);

      expect(result).toEqual(providers);
      expect(result.length).toBe(3);
      expect(result).toContain('anthropic');
      expect(result).toContain('openai');
      expect(result).toContain('google');
    });

    it('should handle single provider in auth.json', () => {
      createTestAuthFile(TEST_AUTH_PATH, ['anthropic']);

      const result = readAuthConfig(TEST_AUTH_PATH);

      expect(result).toEqual(['anthropic']);
      expect(result.length).toBe(1);
    });

    it('should handle empty provider object in auth.json', () => {
      fs.writeFileSync(TEST_AUTH_PATH, JSON.stringify({}));

      const result = readAuthConfig(TEST_AUTH_PATH);

      expect(result).toEqual([]);
      expect(result.length).toBe(0);
    });

    it('should throw error when auth file does not exist', () => {
      const nonExistentPath = path.join(TEST_DIR, 'non-existent-auth.json');

      expect(() => readAuthConfig(nonExistentPath)).toThrow(
        `Auth file not found: ${nonExistentPath}`
      );
    });

    it('should throw error when auth file contains invalid JSON', () => {
      fs.writeFileSync(TEST_AUTH_PATH, 'invalid json {', 'utf-8');

      expect(() => readAuthConfig(TEST_AUTH_PATH)).toThrow();
    });

    it('should correctly identify all providers from auth.json with multiple providers', () => {
      const providers = ['anthropic', 'kimi-for-coding', 'openai', 'google', 'zai-coding-plan'];
      createTestAuthFile(TEST_AUTH_PATH, providers);

      const result = readAuthConfig(TEST_AUTH_PATH);

      expect(result).toHaveLength(5);
      expect(result.sort()).toEqual(providers.sort());
    });
  });

  describe('Database Connectivity', () => {
    it('should successfully connect to SQLite database', () => {
      createTestDatabase(TEST_DB_PATH);

      const db = new Database(TEST_DB_PATH);
      expect(db.open).toBe(true);

      // Test a simple query
      const result = db.prepare('SELECT 1 as value').get() as { value: number };
      expect(result.value).toBe(1);

      db.close();
      expect(db.open).toBe(false);
    });

    it('should be able to query message table', () => {
      createTestDatabase(TEST_DB_PATH);

      const db = new Database(TEST_DB_PATH);
      const result = db.prepare('SELECT COUNT(*) as count FROM message').get() as { count: number };

      expect(result.count).toBe(7); // 7 test messages inserted

      db.close();
    });

    it('should be able to query part table', () => {
      createTestDatabase(TEST_DB_PATH);

      const db = new Database(TEST_DB_PATH);
      const result = db.prepare('SELECT COUNT(*) as count FROM part').get() as { count: number };

      expect(result.count).toBe(2); // 2 test parts inserted

      db.close();
    });

    it('should query messages with providerID in data', () => {
      createTestDatabase(TEST_DB_PATH);

      const db = new Database(TEST_DB_PATH);
      const query = db.prepare(`
        SELECT time_created, data 
        FROM message 
        WHERE data LIKE '%providerID%'
      `);

      const rows = query.all() as Array<{ time_created: number; data: string }>;

      expect(rows.length).toBe(7);

      // Verify each row has valid JSON with providerID
      for (const row of rows) {
        const data = JSON.parse(row.data);
        expect(data).toHaveProperty('providerID');
        expect(typeof data.providerID).toBe('string');
      }

      db.close();
    });

    it('should query parts with providerID in data', () => {
      createTestDatabase(TEST_DB_PATH);

      const db = new Database(TEST_DB_PATH);
      const query = db.prepare(`
        SELECT time_created, data 
        FROM part 
        WHERE data LIKE '%providerID%'
      `);

      const rows = query.all() as Array<{ time_created: number; data: string }>;

      expect(rows.length).toBe(2);

      for (const row of rows) {
        const data = JSON.parse(row.data);
        expect(data).toHaveProperty('providerID');
      }

      db.close();
    });

    it('should throw error when database file does not exist', () => {
      const nonExistentPath = path.join(TEST_DIR, 'non-existent.db');

      expect(() => extractUsageData(nonExistentPath, ['anthropic'])).toThrow(
        `Database not found: ${nonExistentPath}`
      );
    });
  });

  describe('Token Calculation from Messages', () => {
    it('should extract and sum token data from messages correctly', () => {
      createTestDatabase(TEST_DB_PATH);
      createTestAuthFile(TEST_AUTH_PATH, ['anthropic', 'kimi-for-coding', 'openai', 'google']);
      const connectedProviders = readAuthConfig(TEST_AUTH_PATH);

      const providerData = extractUsageData(TEST_DB_PATH, connectedProviders);

      // Anthropic: 2 messages with tokens (1500 + 2500) = 4000, plus 1 part with 800 tokens = 4800 total
      const anthropic = providerData.get('anthropic');
      expect(anthropic).toBeDefined();
      expect(anthropic!.messageCount).toBe(2); // Only messages with valid provider data
      expect(anthropic!.tokensUsed).toBe(4800); // Messages (4000) + parts (800)
      expect(anthropic!.tokensInput).toBe(1700); // 1000 + 500 + 200 (from part)
      expect(anthropic!.tokensOutput).toBe(3100); // 500 + 2000 + 600 (from part)
      expect(anthropic!.tokensCacheRead).toBe(1000);
      expect(anthropic!.tokensCacheWrite).toBe(0);
    });

    it('should extract token data from parts correctly', () => {
      createTestDatabase(TEST_DB_PATH);
      createTestAuthFile(TEST_AUTH_PATH, ['anthropic', 'kimi-for-coding']);
      const connectedProviders = readAuthConfig(TEST_AUTH_PATH);

      const providerData = extractUsageData(TEST_DB_PATH, connectedProviders);

      // Anthropic has 1 part with 800 tokens
      const anthropic = providerData.get('anthropic');
      expect(anthropic).toBeDefined();
      expect(anthropic!.partCount).toBe(1);
      // Total tokens should include both messages (4000) and parts (800) = 4800
      expect(anthropic!.tokensUsed).toBe(4800);
    });

    it('should handle messages without token data gracefully', () => {
      createTestDatabase(TEST_DB_PATH);
      createTestAuthFile(TEST_AUTH_PATH, ['anthropic']);
      const connectedProviders = readAuthConfig(TEST_AUTH_PATH);

      const providerData = extractUsageData(TEST_DB_PATH, connectedProviders);

      const anthropic = providerData.get('anthropic');
      expect(anthropic).toBeDefined();
      // Message without tokens should not increment count or token totals
      expect(anthropic!.messageCount).toBe(2);
      expect(anthropic!.tokensUsed).toBe(4800); // Messages (4000) + parts (800)
    });

    it('should handle unknown providers by skipping them', () => {
      createTestDatabase(TEST_DB_PATH);
      createTestAuthFile(TEST_AUTH_PATH, ['anthropic']); // Only anthropic is connected
      const connectedProviders = readAuthConfig(TEST_AUTH_PATH);

      const providerData = extractUsageData(TEST_DB_PATH, connectedProviders);

      // Should not have data for unknown-provider
      expect(providerData.has('unknown-provider')).toBe(false);
      // Should only have anthropic data
      expect(providerData.has('anthropic')).toBe(true);
    });

    it('should correctly aggregate all token types', () => {
      createTestDatabase(TEST_DB_PATH);
      createTestAuthFile(TEST_AUTH_PATH, ['openai']);
      const connectedProviders = readAuthConfig(TEST_AUTH_PATH);

      const providerData = extractUsageData(TEST_DB_PATH, connectedProviders);

      const openai = providerData.get('openai');
      expect(openai).toBeDefined();
      expect(openai!.tokensUsed).toBe(2000);
      expect(openai!.tokensInput).toBe(1500);
      expect(openai!.tokensOutput).toBe(500);
      expect(openai!.tokensReasoning).toBe(100);
    });
  });

  describe('calculateRolling5HourWindows', () => {
    it('should return empty array when no usage events', () => {
      const result = calculateRolling5HourWindows([], 100000);

      expect(result).toEqual([]);
      expect(result.length).toBe(0);
    });

    it('should calculate single 5-hour window for events within 5 hours', () => {
      const now = Date.now();
      const events = [
        { timestamp: now, tokens: 1000 },
        { timestamp: now - 60 * 60 * 1000, tokens: 2000 }, // 1 hour ago
        { timestamp: now - 2 * 60 * 60 * 1000, tokens: 3000 } // 2 hours ago
      ];

      const result = calculateRolling5HourWindows(events, 10000);

      expect(result.length).toBeGreaterThan(0);
      // All events should be in one window
      const totalTokens = result.reduce((sum, w) => sum + w.tokensUsed, 0);
      expect(totalTokens).toBe(6000);
    });

    it('should calculate percentage of limit correctly', () => {
      const now = Date.now();
      const events = [
        { timestamp: now, tokens: 2500 },
        { timestamp: now - 60 * 60 * 1000, tokens: 2500 }
      ];

      const result = calculateRolling5HourWindows(events, 10000);

      expect(result.length).toBeGreaterThan(0);
      // 5000 tokens out of 10000 limit = 50%
      expect(result[0].percentageOfLimit).toBe(50);
    });

    it('should handle events spanning multiple 5-hour windows', () => {
      const now = Date.now();
      const sixHoursAgo = now - 6 * 60 * 60 * 1000;
      const events = [
        { timestamp: now, tokens: 1000 },
        { timestamp: sixHoursAgo, tokens: 2000 }
      ];

      const result = calculateRolling5HourWindows(events, 10000);

      // Should have at least 2 windows (with 1-hour steps)
      expect(result.length).toBeGreaterThanOrEqual(2);
    });

    it('should return windows in chronological order', () => {
      const now = Date.now();
      const events = [
        { timestamp: now, tokens: 1000 },
        { timestamp: now - 4 * 60 * 60 * 1000, tokens: 2000 },
        { timestamp: now - 8 * 60 * 60 * 1000, tokens: 3000 }
      ];

      const result = calculateRolling5HourWindows(events, 10000);

      // Check that windows are sorted by start time
      for (let i = 1; i < result.length; i++) {
        const prevStart = new Date(result[i - 1].windowStart).getTime();
        const currStart = new Date(result[i].windowStart).getTime();
        expect(currStart).toBeGreaterThanOrEqual(prevStart);
      }
    });

    it('should limit results to last 10 windows', () => {
      const now = Date.now();
      const events: Array<{ timestamp: number; tokens: number }> = [];

      // Create events spanning 20 hours to generate many windows
      for (let i = 0; i < 20; i++) {
        events.push({
          timestamp: now - i * 60 * 60 * 1000, // Each hour
          tokens: 100
        });
      }

      const result = calculateRolling5HourWindows(events, 100000);

      // Should be limited to last 10 windows
      expect(result.length).toBeLessThanOrEqual(10);
    });

    it('should not include percentageOfLimit when limit is undefined', () => {
      const now = Date.now();
      const events = [{ timestamp: now, tokens: 1000 }];

      const result = calculateRolling5HourWindows(events, undefined);

      expect(result.length).toBeGreaterThan(0);
      expect(result[0].percentageOfLimit).toBeUndefined();
    });

    it('should calculate tokens correctly for overlapping windows', () => {
      const now = Date.now();
      const events = [
        { timestamp: now, tokens: 1000 },
        { timestamp: now - 30 * 60 * 1000, tokens: 2000 } // 30 minutes ago
      ];

      const result = calculateRolling5HourWindows(events, 10000);

      // The same events should appear in multiple overlapping windows
      const totalTokens = result.reduce((sum, w) => sum + w.tokensUsed, 0);
      // Total should be more than 3000 due to overlapping windows
      expect(totalTokens).toBeGreaterThanOrEqual(3000);
    });
  });

  describe('calculateWeeklyUsage', () => {
    it('should return zero tokens when no usage events', () => {
      const result = calculateWeeklyUsage([], 1000000);

      expect(result.tokensUsed).toBe(0);
      expect(result.percentageOfLimit).toBe(0);
    });

    it('should calculate weekly usage from current week only', () => {
      const now = Date.now();
      const yesterday = now - 24 * 60 * 60 * 1000;
      const events = [
        { timestamp: now, tokens: 5000 },
        { timestamp: yesterday, tokens: 3000 }
      ];

      const result = calculateWeeklyUsage(events, 100000);

      // Both events should be counted (assuming we're mid-week)
      expect(result.tokensUsed).toBeGreaterThan(0);
    });

    it('should not include events from previous week', () => {
      const now = Date.now();
      const lastWeek = now - 8 * 24 * 60 * 60 * 1000; // 8 days ago
      const events = [
        { timestamp: now, tokens: 1000 },
        { timestamp: lastWeek, tokens: 9999 }
      ];

      const result = calculateWeeklyUsage(events, 100000);

      // Should only count the current week event
      expect(result.tokensUsed).toBe(1000);
    });

    it('should calculate percentage of limit correctly', () => {
      const now = Date.now();
      const events = [{ timestamp: now, tokens: 25000 }];

      const result = calculateWeeklyUsage(events, 100000);

      // 25000 out of 100000 = 25%
      expect(result.percentageOfLimit).toBe(25);
    });

    it('should handle limit of 0 gracefully', () => {
      const now = Date.now();
      const events = [{ timestamp: now, tokens: 1000 }];

      const result = calculateWeeklyUsage(events, 0);

      expect(result.tokensUsed).toBe(1000);
      // Percentage should handle division by zero
      expect(result.percentageOfLimit).toBeDefined();
    });

    it('should calculate from Sunday start of week', () => {
      const now = new Date();
      const dayOfWeek = now.getDay();

      // Create an event from Monday (if today is after Sunday)
      if (dayOfWeek >= 1) {
        const mondayTime = now.getTime() - (dayOfWeek - 1) * 24 * 60 * 60 * 1000;
        const events = [{ timestamp: mondayTime, tokens: 5000 }];

        const result = calculateWeeklyUsage(events, 100000);

        expect(result.tokensUsed).toBe(5000);
      }
    });
  });

  describe('Provider Detection and Configuration', () => {
    it('should detect all connected providers from auth.json', () => {
      const providers = ['anthropic', 'openai', 'google', 'kimi-for-coding'];
      createTestAuthFile(TEST_AUTH_PATH, providers);

      const result = readAuthConfig(TEST_AUTH_PATH);

      expect(result).toHaveLength(4);
      providers.forEach(provider => {
        expect(result).toContain(provider);
      });
    });

    it('should initialize provider data with correct configuration', () => {
      createTestDatabase(TEST_DB_PATH);
      createTestAuthFile(TEST_AUTH_PATH, ['anthropic', 'openai']);
      const connectedProviders = readAuthConfig(TEST_AUTH_PATH);

      const providerData = extractUsageData(TEST_DB_PATH, connectedProviders);

      // Anthropic should have 5-hour window type
      const anthropic = providerData.get('anthropic');
      expect(anthropic).toBeDefined();
      expect(anthropic!.windowType).toBe('5-hour');
      expect(anthropic!.displayName).toBe('Claude (Anthropic)');
      expect(anthropic!.knownLimits).toBeDefined();
      expect(anthropic!.knownLimits!.tokensPerWindow).toBe(100000);

      // OpenAI should have weekly window type
      const openai = providerData.get('openai');
      expect(openai).toBeDefined();
      expect(openai!.windowType).toBe('weekly');
      expect(openai!.displayName).toBe('GPT (OpenAI)');
    });

    it('should handle unknown provider with default configuration', () => {
      createTestDatabase(TEST_DB_PATH);
      createTestAuthFile(TEST_AUTH_PATH, ['unknown-new-provider']);
      const connectedProviders = readAuthConfig(TEST_AUTH_PATH);

      const providerData = extractUsageData(TEST_DB_PATH, connectedProviders);

      const unknown = providerData.get('unknown-new-provider');
      expect(unknown).toBeDefined();
      expect(unknown!.windowType).toBe('unknown');
      expect(unknown!.displayName).toBe('unknown-new-provider');
    });
  });

  describe('Time Window Tracking', () => {
    it('should track correct time window for each provider', () => {
      createTestDatabase(TEST_DB_PATH);
      createTestAuthFile(TEST_AUTH_PATH, ['anthropic']);
      const connectedProviders = readAuthConfig(TEST_AUTH_PATH);

      const providerData = extractUsageData(TEST_DB_PATH, connectedProviders);

      const anthropic = providerData.get('anthropic');
      expect(anthropic).toBeDefined();
      expect(anthropic!.timeWindow.start).toBeDefined();
      expect(anthropic!.timeWindow.end).toBeDefined();

      // Verify dates are valid ISO strings
      const startDate = new Date(anthropic!.timeWindow.start);
      const endDate = new Date(anthropic!.timeWindow.end);
      expect(startDate.getTime()).not.toBeNaN();
      expect(endDate.getTime()).not.toBeNaN();
      expect(startDate.getTime()).toBeLessThanOrEqual(endDate.getTime());
    });
  });

  describe('Notes Generation', () => {
    it('should generate notes for 5-hour window providers', () => {
      createTestDatabase(TEST_DB_PATH);
      createTestAuthFile(TEST_AUTH_PATH, ['anthropic']);
      const connectedProviders = readAuthConfig(TEST_AUTH_PATH);

      const providerData = extractUsageData(TEST_DB_PATH, connectedProviders);

      const anthropic = providerData.get('anthropic');
      expect(anthropic).toBeDefined();
      expect(anthropic!.notes.length).toBeGreaterThan(0);
      expect(anthropic!.notes.some(n => n.includes('5-hour'))).toBe(true);
    });

    it('should generate notes for weekly providers', () => {
      createTestDatabase(TEST_DB_PATH);
      createTestAuthFile(TEST_AUTH_PATH, ['openai']);
      const connectedProviders = readAuthConfig(TEST_AUTH_PATH);

      const providerData = extractUsageData(TEST_DB_PATH, connectedProviders);

      const openai = providerData.get('openai');
      expect(openai).toBeDefined();
      expect(openai!.notes.length).toBeGreaterThan(0);
      expect(openai!.notes.some(n => n.includes('week'))).toBe(true);
    });

    it('should add note when no token data found', () => {
      // Create empty database
      const db = new Database(TEST_DB_PATH);
      db.exec(`
        CREATE TABLE IF NOT EXISTS message (id INTEGER PRIMARY KEY, time_created INTEGER, data TEXT);
        CREATE TABLE IF NOT EXISTS part (id INTEGER PRIMARY KEY, time_created INTEGER, data TEXT);
      `);
      db.close();

      createTestAuthFile(TEST_AUTH_PATH, ['google']);
      const connectedProviders = readAuthConfig(TEST_AUTH_PATH);

      const providerData = extractUsageData(TEST_DB_PATH, connectedProviders);

      const google = providerData.get('google');
      expect(google).toBeDefined();
      expect(google!.tokensUsed).toBe(0);
      expect(google!.notes.some(n => n.includes('No token data found'))).toBe(true);
    });
  });

  describe('JSON Output Format', () => {
    it('should produce valid JSON output structure', () => {
      createTestDatabase(TEST_DB_PATH);
      createTestAuthFile(TEST_AUTH_PATH, ['anthropic', 'openai']);
      const connectedProviders = readAuthConfig(TEST_AUTH_PATH);

      const providerData = extractUsageData(TEST_DB_PATH, connectedProviders);

      // Verify Map structure can be converted to expected format
      const providers = Array.from(providerData.values());
      expect(Array.isArray(providers)).toBe(true);
      expect(providers.length).toBe(2);

      // Verify each provider has required fields
      providers.forEach(provider => {
        expect(provider).toHaveProperty('provider');
        expect(provider).toHaveProperty('displayName');
        expect(provider).toHaveProperty('tokensUsed');
        expect(provider).toHaveProperty('tokensInput');
        expect(provider).toHaveProperty('tokensOutput');
        expect(provider).toHaveProperty('tokensReasoning');
        expect(provider).toHaveProperty('tokensCacheRead');
        expect(provider).toHaveProperty('tokensCacheWrite');
        expect(provider).toHaveProperty('messageCount');
        expect(provider).toHaveProperty('partCount');
        expect(provider).toHaveProperty('windowType');
        expect(provider).toHaveProperty('timeWindow');
        expect(provider).toHaveProperty('notes');
      });
    });

    it('should have correct data types in output', () => {
      createTestDatabase(TEST_DB_PATH);
      createTestAuthFile(TEST_AUTH_PATH, ['anthropic']);
      const connectedProviders = readAuthConfig(TEST_AUTH_PATH);

      const providerData = extractUsageData(TEST_DB_PATH, connectedProviders);
      const anthropic = providerData.get('anthropic')!;

      expect(typeof anthropic.provider).toBe('string');
      expect(typeof anthropic.displayName).toBe('string');
      expect(typeof anthropic.tokensUsed).toBe('number');
      expect(typeof anthropic.tokensInput).toBe('number');
      expect(typeof anthropic.tokensOutput).toBe('number');
      expect(typeof anthropic.tokensReasoning).toBe('number');
      expect(typeof anthropic.tokensCacheRead).toBe('number');
      expect(typeof anthropic.tokensCacheWrite).toBe('number');
      expect(typeof anthropic.messageCount).toBe('number');
      expect(typeof anthropic.partCount).toBe('number');
      expect(typeof anthropic.windowType).toBe('string');
      expect(typeof anthropic.timeWindow.start).toBe('string');
      expect(typeof anthropic.timeWindow.end).toBe('string');
      expect(Array.isArray(anthropic.notes)).toBe(true);
    });

    it('should serialize to JSON without errors', () => {
      createTestDatabase(TEST_DB_PATH);
      createTestAuthFile(TEST_AUTH_PATH, ['anthropic', 'openai']);
      const connectedProviders = readAuthConfig(TEST_AUTH_PATH);

      const providerData = extractUsageData(TEST_DB_PATH, connectedProviders);

      const outputPath = path.join(TEST_OUTPUT_DIR, 'test-output.json');
      const result = {
        generatedAt: new Date().toISOString(),
        extractionVersion: '1.0.0',
        dataSource: {
          databasePath: TEST_DB_PATH,
          authPath: TEST_AUTH_PATH,
          messageCount: 7,
          partCount: 2
        },
        providers: Array.from(providerData.values()),
        summary: {
          totalTokensUsed: Array.from(providerData.values()).reduce((sum, p) => sum + p.tokensUsed, 0),
          totalMessagesAnalyzed: Array.from(providerData.values()).reduce((sum, p) => sum + p.messageCount, 0),
          totalPartsAnalyzed: Array.from(providerData.values()).reduce((sum, p) => sum + p.partCount, 0),
          providersConnected: connectedProviders.length,
          providersWithUsage: Array.from(providerData.values()).filter(p => p.tokensUsed > 0).length
        }
      };

      // Should serialize without throwing
      expect(() => {
        fs.writeFileSync(outputPath, JSON.stringify(result, null, 2));
      }).not.toThrow();

      // Should be readable and parseable
      const readData = JSON.parse(fs.readFileSync(outputPath, 'utf-8'));
      expect(readData.generatedAt).toBeDefined();
      expect(readData.providers).toHaveLength(2);
      expect(readData.summary.providersConnected).toBe(2);
    });
  });

  describe('Edge Cases and Error Handling', () => {
    it('should handle database with no message table gracefully', () => {
      // Create database without message/part tables
      const db = new Database(TEST_DB_PATH);
      db.exec('CREATE TABLE other_table (id INTEGER)');
      db.close();

      createTestAuthFile(TEST_AUTH_PATH, ['anthropic']);
      const connectedProviders = readAuthConfig(TEST_AUTH_PATH);

      // Should throw when trying to query non-existent table
      expect(() => extractUsageData(TEST_DB_PATH, connectedProviders)).toThrow();
    });

    it('should handle invalid JSON in message data', () => {
      const db = new Database(TEST_DB_PATH);
      db.exec(`
        CREATE TABLE message (id INTEGER PRIMARY KEY, time_created INTEGER, data TEXT);
        CREATE TABLE part (id INTEGER PRIMARY KEY, time_created INTEGER, data TEXT);
      `);

      const now = Date.now();
      db.prepare('INSERT INTO message (time_created, data) VALUES (?, ?)')
        .run(now, 'invalid json {{{');
      db.prepare('INSERT INTO message (time_created, data) VALUES (?, ?)')
        .run(now, JSON.stringify({ providerID: 'anthropic', tokens: { total: 1000 } }));

      db.close();

      createTestAuthFile(TEST_AUTH_PATH, ['anthropic']);
      const connectedProviders = readAuthConfig(TEST_AUTH_PATH);

      // Should not throw, should skip invalid JSON
      const providerData = extractUsageData(TEST_DB_PATH, connectedProviders);

      const anthropic = providerData.get('anthropic');
      expect(anthropic).toBeDefined();
      expect(anthropic!.tokensUsed).toBe(1000); // Only valid message counted
    });

    it('should handle empty database gracefully', () => {
      const db = new Database(TEST_DB_PATH);
      db.exec(`
        CREATE TABLE message (id INTEGER PRIMARY KEY, time_created INTEGER, data TEXT);
        CREATE TABLE part (id INTEGER PRIMARY KEY, time_created INTEGER, data TEXT);
      `);
      db.close();

      createTestAuthFile(TEST_AUTH_PATH, ['anthropic']);
      const connectedProviders = readAuthConfig(TEST_AUTH_PATH);

      const providerData = extractUsageData(TEST_DB_PATH, connectedProviders);

      const anthropic = providerData.get('anthropic');
      expect(anthropic).toBeDefined();
      expect(anthropic!.tokensUsed).toBe(0);
      expect(anthropic!.messageCount).toBe(0);
      expect(anthropic!.notes.some(n => n.includes('No token data found'))).toBe(true);
    });

    it('should handle messages without providerID', () => {
      const db = new Database(TEST_DB_PATH);
      db.exec(`
        CREATE TABLE message (id INTEGER PRIMARY KEY, time_created INTEGER, data TEXT);
        CREATE TABLE part (id INTEGER PRIMARY KEY, time_created INTEGER, data TEXT);
      `);

      const now = Date.now();
      // Message without providerID
      db.prepare('INSERT INTO message (time_created, data) VALUES (?, ?)')
        .run(now, JSON.stringify({ role: 'user', tokens: { total: 1000 } }));
      // Message with providerID
      db.prepare('INSERT INTO message (time_created, data) VALUES (?, ?)')
        .run(now, JSON.stringify({ providerID: 'anthropic', tokens: { total: 2000 } }));

      db.close();

      createTestAuthFile(TEST_AUTH_PATH, ['anthropic']);
      const connectedProviders = readAuthConfig(TEST_AUTH_PATH);

      const providerData = extractUsageData(TEST_DB_PATH, connectedProviders);

      // Should only count message with providerID
      const anthropic = providerData.get('anthropic');
      expect(anthropic!.tokensUsed).toBe(2000);
    });

    it('should handle very large token counts', () => {
      const db = new Database(TEST_DB_PATH);
      db.exec(`
        CREATE TABLE message (id INTEGER PRIMARY KEY, time_created INTEGER, data TEXT);
        CREATE TABLE part (id INTEGER PRIMARY KEY, time_created INTEGER, data TEXT);
      `);

      const now = Date.now();
      const largeTokenCount = 1000000000; // 1 billion
      db.prepare('INSERT INTO message (time_created, data) VALUES (?, ?)')
        .run(now, JSON.stringify({
          providerID: 'anthropic',
          tokens: {
            total: largeTokenCount,
            input: largeTokenCount / 2,
            output: largeTokenCount / 2
          }
        }));

      db.close();

      createTestAuthFile(TEST_AUTH_PATH, ['anthropic']);
      const connectedProviders = readAuthConfig(TEST_AUTH_PATH);

      const providerData = extractUsageData(TEST_DB_PATH, connectedProviders);

      const anthropic = providerData.get('anthropic');
      expect(anthropic!.tokensUsed).toBe(largeTokenCount);
    });

    it('should handle concurrent provider data correctly', () => {
      const db = new Database(TEST_DB_PATH);
      db.exec(`
        CREATE TABLE message (id INTEGER PRIMARY KEY, time_created INTEGER, data TEXT);
        CREATE TABLE part (id INTEGER PRIMARY KEY, time_created INTEGER, data TEXT);
      `);

      const now = Date.now();
      // Insert messages for multiple providers
      ['anthropic', 'openai', 'google'].forEach((provider, i) => {
        db.prepare('INSERT INTO message (time_created, data) VALUES (?, ?)')
          .run(now, JSON.stringify({
            providerID: provider,
            tokens: { total: (i + 1) * 1000 }
          }));
      });

      db.close();

      createTestAuthFile(TEST_AUTH_PATH, ['anthropic', 'openai', 'google']);
      const connectedProviders = readAuthConfig(TEST_AUTH_PATH);

      const providerData = extractUsageData(TEST_DB_PATH, connectedProviders);

      expect(providerData.get('anthropic')!.tokensUsed).toBe(1000);
      expect(providerData.get('openai')!.tokensUsed).toBe(2000);
      expect(providerData.get('google')!.tokensUsed).toBe(3000);
    });
  });

  describe('Rolling Windows for 5-Hour Providers', () => {
    it('should generate rolling windows for anthropic provider', () => {
      createTestDatabase(TEST_DB_PATH);
      createTestAuthFile(TEST_AUTH_PATH, ['anthropic']);
      const connectedProviders = readAuthConfig(TEST_AUTH_PATH);

      const providerData = extractUsageData(TEST_DB_PATH, connectedProviders);

      const anthropic = providerData.get('anthropic');
      expect(anthropic).toBeDefined();
      expect(anthropic!.windowType).toBe('5-hour');
      expect(anthropic!.rollingWindows).toBeDefined();
      expect(Array.isArray(anthropic!.rollingWindows)).toBe(true);

      // Each window should have required fields
      if (anthropic!.rollingWindows && anthropic!.rollingWindows.length > 0) {
        anthropic!.rollingWindows.forEach(window => {
          expect(window).toHaveProperty('windowStart');
          expect(window).toHaveProperty('windowEnd');
          expect(window).toHaveProperty('tokensUsed');
          expect(typeof window.windowStart).toBe('string');
          expect(typeof window.windowEnd).toBe('string');
          expect(typeof window.tokensUsed).toBe('number');
        });
      }
    });

    it('should calculate usagePercentageOfLimit for 5-hour providers', () => {
      const db = new Database(TEST_DB_PATH);
      db.exec(`
        CREATE TABLE message (id INTEGER PRIMARY KEY, time_created INTEGER, data TEXT);
        CREATE TABLE part (id INTEGER PRIMARY KEY, time_created INTEGER, data TEXT);
      `);

      const now = Date.now();
      // Add recent message within 5 hours
      db.prepare('INSERT INTO message (time_created, data) VALUES (?, ?)')
        .run(now, JSON.stringify({
          providerID: 'anthropic',
          tokens: { total: 50000 }
        }));

      db.close();

      createTestAuthFile(TEST_AUTH_PATH, ['anthropic']);
      const connectedProviders = readAuthConfig(TEST_AUTH_PATH);

      const providerData = extractUsageData(TEST_DB_PATH, connectedProviders);

      const anthropic = providerData.get('anthropic');
      expect(anthropic).toBeDefined();
      expect(anthropic!.usagePercentageOfLimit).toBeDefined();
      // 50000 / 100000 limit = 50%
      expect(anthropic!.usagePercentageOfLimit).toBe(50);
    });
  });

  describe('Weekly Usage for Weekly Providers', () => {
    it('should calculate weekly usage for openai provider', () => {
      createTestDatabase(TEST_DB_PATH);
      createTestAuthFile(TEST_AUTH_PATH, ['openai']);
      const connectedProviders = readAuthConfig(TEST_AUTH_PATH);

      const providerData = extractUsageData(TEST_DB_PATH, connectedProviders);

      const openai = providerData.get('openai');
      expect(openai).toBeDefined();
      expect(openai!.windowType).toBe('weekly');
      // Weekly providers don't have rollingWindows
      expect(openai!.rollingWindows).toBeUndefined();
    });

    it('should calculate usagePercentageOfLimit for weekly providers', () => {
      const db = new Database(TEST_DB_PATH);
      db.exec(`
        CREATE TABLE message (id INTEGER PRIMARY KEY, time_created INTEGER, data TEXT);
        CREATE TABLE part (id INTEGER PRIMARY KEY, time_created INTEGER, data TEXT);
      `);

      const now = Date.now();
      // Add recent message (within this week)
      db.prepare('INSERT INTO message (time_created, data) VALUES (?, ?)')
        .run(now, JSON.stringify({
          providerID: 'openai',
          tokens: { total: 250000 }
        }));

      db.close();

      createTestAuthFile(TEST_AUTH_PATH, ['openai']);
      const connectedProviders = readAuthConfig(TEST_AUTH_PATH);

      const providerData = extractUsageData(TEST_DB_PATH, connectedProviders);

      const openai = providerData.get('openai');
      expect(openai).toBeDefined();
      expect(openai!.usagePercentageOfLimit).toBeDefined();
      // 250000 / 1000000 limit = 25%
      expect(openai!.usagePercentageOfLimit).toBe(25);
    });
  });
});
