#!/usr/bin/env node
/**
 * OpenCode Usage Extractor
 * 
 * Extracts token usage data from OpenCode's SQLite database and auth configuration.
 * Calculates rolling 5-hour windows for Claude and Kimi, and weekly usage for
 * providers with weekly quotas.
 * 
 * Output: .ai/extracted/provider-usage-data.json
 */

import DatabaseConstructor from 'better-sqlite3';
import * as fs from 'fs';
import * as path from 'path';

const Database = DatabaseConstructor;

// Provider configuration with known rate limits (will be populated from APIs in Run 2)
const PROVIDER_CONFIG: Record<string, {
  displayName: string;
  windowType: '5-hour' | 'weekly' | 'unknown';
  knownLimits?: {
    tokensPerWindow?: number;
    requestsPerWindow?: number;
  };
}> = {
  anthropic: {
    displayName: 'Claude (Anthropic)',
    windowType: '5-hour',
    knownLimits: {
      tokensPerWindow: 100000, // Tier 1 limit - will be updated from API
    }
  },
  'kimi-for-coding': {
    displayName: 'Kimi',
    windowType: '5-hour',
    knownLimits: {
      tokensPerWindow: 1000000, // Estimated - will be updated from API
    }
  },
  'zai-coding-plan': {
    displayName: 'GLM (Zhipu)',
    windowType: 'weekly',
    knownLimits: {
      tokensPerWindow: 1000000, // Estimated - will be updated from API
    }
  },
  google: {
    displayName: 'Gemini (Google)',
    windowType: 'weekly',
    knownLimits: {
      tokensPerWindow: 1000000, // Free tier - will be updated from API
    }
  },
  openai: {
    displayName: 'GPT (OpenAI)',
    windowType: 'weekly',
    knownLimits: {
      tokensPerWindow: 1000000, // Tier 1 limit - will be updated from API
    }
  }
};

interface TokenData {
  total: number;
  input: number;
  output: number;
  reasoning: number;
  cache: {
    read: number;
    write: number;
  };
}

interface MessageData {
  role: string;
  time: {
    created: number;
    completed?: number;
  };
  providerID: string;
  modelID: string;
  tokens?: TokenData;
}

interface ProviderUsage {
  provider: string;
  displayName: string;
  tokensUsed: number;
  tokensInput: number;
  tokensOutput: number;
  tokensReasoning: number;
  tokensCacheRead: number;
  tokensCacheWrite: number;
  messageCount: number;
  partCount: number;
  windowType: '5-hour' | 'weekly' | 'unknown';
  timeWindow: {
    start: string;
    end: string;
  };
  rollingWindows?: Array<{
    windowStart: string;
    windowEnd: string;
    tokensUsed: number;
    percentageOfLimit?: number;
  }>;
  knownLimits?: {
    tokensPerWindow?: number;
    requestsPerWindow?: number;
  };
  usagePercentageOfLimit?: number;
  notes: string[];
}

interface ExtractionResult {
  generatedAt: string;
  extractionVersion: string;
  dataSource: {
    databasePath: string;
    authPath: string;
    messageCount: number;
    partCount: number;
  };
  providers: ProviderUsage[];
  summary: {
    totalTokensUsed: number;
    totalMessagesAnalyzed: number;
    totalPartsAnalyzed: number;
    providersConnected: number;
    providersWithUsage: number;
  };
}

/**
 * Read and parse auth.json to identify connected providers
 */
function readAuthConfig(authPath: string): string[] {
  console.log(`Reading auth configuration from: ${authPath}`);
  
  if (!fs.existsSync(authPath)) {
    throw new Error(`Auth file not found: ${authPath}`);
  }
  
  const authData = JSON.parse(fs.readFileSync(authPath, 'utf-8'));
  const providers = Object.keys(authData);
  
  console.log(`Found ${providers.length} connected providers: ${providers.join(', ')}`);
  return providers;
}

/**
 * Calculate rolling 5-hour windows for a provider
 */
function calculateRolling5HourWindows(
  usageEvents: Array<{ timestamp: number; tokens: number }>,
  limit?: number
): Array<{ windowStart: string; windowEnd: string; tokensUsed: number; percentageOfLimit?: number }> {
  if (usageEvents.length === 0) return [];
  
  // Sort events by timestamp
  const sorted = [...usageEvents].sort((a, b) => a.timestamp - b.timestamp);
  const windows: Array<{ windowStart: string; windowEnd: string; tokensUsed: number; percentageOfLimit?: number }> = [];
  
  // Create 5-hour windows
  const windowSizeMs = 5 * 60 * 60 * 1000; // 5 hours in milliseconds
  
  // Find the time range
  const minTime = sorted[0].timestamp;
  const maxTime = sorted[sorted.length - 1].timestamp;
  
  // Create 5-hour windows starting from first event
  for (let windowStart = minTime; windowStart <= maxTime; windowStart += windowSizeMs) {
    const windowEnd = windowStart + windowSizeMs;
    
    // Sum tokens in this window
    const tokensInWindow = sorted
      .filter(e => e.timestamp >= windowStart && e.timestamp < windowEnd)
      .reduce((sum, e) => sum + e.tokens, 0);
    
    if (tokensInWindow > 0) {
      const window = {
        windowStart: new Date(windowStart).toISOString(),
        windowEnd: new Date(windowEnd).toISOString(),
        tokensUsed: tokensInWindow,
        percentageOfLimit: limit ? Math.round((tokensInWindow / limit) * 1000) / 10 : undefined
      };
      windows.push(window);
    }
  }
  
  // Return only the most recent windows (last 10)
  return windows.slice(-10);
}

/**
 * Calculate weekly usage
 */
function calculateWeeklyUsage(
  usageEvents: Array<{ timestamp: number; tokens: number }>,
  limit?: number
): { tokensUsed: number; percentageOfLimit?: number } {
  // Get current week's usage (from most recent Sunday)
  const now = Date.now();
  const dayOfWeek = new Date(now).getDay();
  const daysSinceSunday = dayOfWeek;
  const weekStart = now - (daysSinceSunday * 24 * 60 * 60 * 1000);
  
  // Reset to start of Sunday
  const sundayStart = new Date(weekStart);
  sundayStart.setHours(0, 0, 0, 0);
  
  const weeklyTokens = usageEvents
    .filter(e => e.timestamp >= sundayStart.getTime())
    .reduce((sum, e) => sum + e.tokens, 0);
  
  // Handle division by zero when limit is 0
  let percentageOfLimit: number | undefined;
  if (limit === 0) {
    percentageOfLimit = 0;
  } else if (limit) {
    percentageOfLimit = Math.round((weeklyTokens / limit) * 1000) / 10;
  } else {
    percentageOfLimit = undefined;
  }

  return {
    tokensUsed: weeklyTokens,
    percentageOfLimit
  };
}

/**
 * Extract usage data from SQLite database
 */
function extractUsageData(
  dbPath: string,
  connectedProviders: string[]
): Map<string, ProviderUsage> {
  console.log(`Connecting to database: ${dbPath}`);
  
  if (!fs.existsSync(dbPath)) {
    throw new Error(`Database not found: ${dbPath}`);
  }
  
  // Use better-sqlite3 for synchronous operations
  const db = new Database(dbPath);
  
  const providerData = new Map<string, ProviderUsage>();
  const usageEvents = new Map<string, Array<{ timestamp: number; tokens: number }>>();
  
  // Initialize provider data structures
  for (const provider of connectedProviders) {
    const config = PROVIDER_CONFIG[provider] || {
      displayName: provider,
      windowType: 'unknown'
    };
    
    providerData.set(provider, {
      provider,
      displayName: config.displayName,
      tokensUsed: 0,
      tokensInput: 0,
      tokensOutput: 0,
      tokensReasoning: 0,
      tokensCacheRead: 0,
      tokensCacheWrite: 0,
      messageCount: 0,
      partCount: 0,
      windowType: config.windowType,
      timeWindow: {
        start: new Date().toISOString(),
        end: new Date(0).toISOString()
      },
      knownLimits: config.knownLimits,
      notes: []
    });
    
    usageEvents.set(provider, []);
  }
  
  // Query messages table
  console.log('Querying message table...');
  const messageQuery = db.prepare(`
    SELECT time_created, data 
    FROM message 
    WHERE data LIKE '%providerID%'
  `);
  
  let messageCount = 0;
  for (const row of messageQuery.iterate() as IterableIterator<{ time_created: number; data: string }>) {
    try {
      const data: MessageData = JSON.parse(row.data);
      const provider = data.providerID;
      
      if (!provider || !providerData.has(provider)) continue;
      
      const usage = providerData.get(provider)!;
      const events = usageEvents.get(provider)!;
      
      // Track time window (for all messages with this provider)
      const timestamp = data.time?.created || row.time_created;
      const date = new Date(timestamp);
      if (date < new Date(usage.timeWindow.start)) {
        usage.timeWindow.start = date.toISOString();
      }
      if (date > new Date(usage.timeWindow.end)) {
        usage.timeWindow.end = date.toISOString();
      }
      
      // Extract token data if available
      if (data.tokens) {
        const tokens = data.tokens.total || 0;
        usage.tokensUsed += tokens;
        usage.tokensInput += data.tokens.input || 0;
        usage.tokensOutput += data.tokens.output || 0;
        usage.tokensReasoning += data.tokens.reasoning || 0;
        usage.tokensCacheRead += data.tokens.cache?.read || 0;
        usage.tokensCacheWrite += data.tokens.cache?.write || 0;
        
        // Add to events for window calculations
        events.push({ timestamp, tokens });
        
        // Only count messages that have token data
        usage.messageCount++;
      }
      
      messageCount++;
    } catch (e) {
      // Skip invalid JSON
    }
  }
  
  console.log(`Processed ${messageCount} messages with valid token data`);
  
  // Query parts table (for additional token data)
  console.log('Querying part table...');
  const partQuery = db.prepare(`
    SELECT time_created, data 
    FROM part 
    WHERE data LIKE '%providerID%'
  `);
  
  let partCount = 0;
  for (const row of partQuery.iterate() as IterableIterator<{ time_created: number; data: string }>) {
    try {
      const data: MessageData = JSON.parse(row.data);
      const provider = data.providerID;
      
      if (!provider || !providerData.has(provider)) continue;
      
      const usage = providerData.get(provider)!;
      const events = usageEvents.get(provider)!;
      
      usage.partCount++;
      
      // Extract token data if available
      if (data.tokens) {
        const tokens = data.tokens.total || 0;
        usage.tokensUsed += tokens;
        usage.tokensInput += data.tokens.input || 0;
        usage.tokensOutput += data.tokens.output || 0;
        usage.tokensReasoning += data.tokens.reasoning || 0;
        usage.tokensCacheRead += data.tokens.cache?.read || 0;
        usage.tokensCacheWrite += data.tokens.cache?.write || 0;
        
        const timestamp = data.time?.created || row.time_created;
        events.push({ timestamp, tokens });
      }
      
      partCount++;
    } catch (e) {
      // Skip invalid JSON
    }
  }
  
  console.log(`Processed ${partCount} parts with valid token data`);
  
  // Calculate rolling windows and weekly usage
  for (const [provider, usage] of providerData) {
    const events = usageEvents.get(provider) || [];
    const config = PROVIDER_CONFIG[provider];
    
    if (!config) continue;
    
    if (config.windowType === '5-hour' && events.length > 0) {
      usage.rollingWindows = calculateRolling5HourWindows(
        events,
        config.knownLimits?.tokensPerWindow
      );
      
      // Calculate current 5-hour window
      const now = Date.now();
      const fiveHoursAgo = now - (5 * 60 * 60 * 1000);
      const recentTokens = events
        .filter(e => e.timestamp >= fiveHoursAgo)
        .reduce((sum, e) => sum + e.tokens, 0);
      
      usage.usagePercentageOfLimit = config.knownLimits?.tokensPerWindow
        ? Math.round((recentTokens / config.knownLimits.tokensPerWindow) * 1000) / 10
        : undefined;
      
      usage.notes.push(`Current 5-hour window (last 5h): ${recentTokens.toLocaleString()} tokens`);
    } else if (config.windowType === 'weekly' && events.length > 0) {
      const weekly = calculateWeeklyUsage(events, config.knownLimits?.tokensPerWindow);
      usage.usagePercentageOfLimit = weekly.percentageOfLimit;
      usage.notes.push(`Current week (since Sunday): ${weekly.tokensUsed.toLocaleString()} tokens`);
    }
    
    // Add data quality notes
    if (usage.tokensUsed === 0) {
      usage.notes.push('No token data found - provider may not report usage in message/part tables');
    }
  }
  
  db.close();
  return providerData;
}

/**
 * Get database statistics
 */
function getDatabaseStats(dbPath: string): { messageCount: number; partCount: number } {
  const db = new Database(dbPath);
  
  const messageCount = (db.prepare('SELECT COUNT(*) as count FROM message').get() as any).count;
  const partCount = (db.prepare('SELECT COUNT(*) as count FROM part').get() as any).count;
  
  db.close();
  
  return { messageCount, partCount };
}

/**
 * Main extraction function
 */
async function main() {
  const homeDir = process.env.HOME || process.env.USERPROFILE || '.';
  const dbPath = path.join(homeDir, '.local', 'share', 'opencode', 'opencode.db');
  const authPath = path.join(homeDir, '.local', 'share', 'opencode', 'auth.json');
  const outputPath = path.join(process.cwd(), '.ai', 'extracted', 'provider-usage-data.json');
  
  console.log('=== OpenCode Usage Extractor ===\n');
  
  try {
    // Read connected providers from auth.json
    const connectedProviders = readAuthConfig(authPath);
    
    // Get database stats
    const stats = getDatabaseStats(dbPath);
    console.log(`\nDatabase stats: ${stats.messageCount.toLocaleString()} messages, ${stats.partCount.toLocaleString()} parts\n`);
    
    // Extract usage data
    const providerData = extractUsageData(dbPath, connectedProviders);
    
    // Build result
    const result: ExtractionResult = {
      generatedAt: new Date().toISOString(),
      extractionVersion: '1.0.0',
      dataSource: {
        databasePath: dbPath,
        authPath: authPath,
        messageCount: stats.messageCount,
        partCount: stats.partCount
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
    
    // Ensure output directory exists
    fs.mkdirSync(path.dirname(outputPath), { recursive: true });
    
    // Write output
    fs.writeFileSync(outputPath, JSON.stringify(result, null, 2));
    
    console.log(`\n=== Extraction Complete ===`);
    console.log(`Output written to: ${outputPath}`);
    console.log(`\nSummary:`);
    console.log(`  - ${result.summary.providersConnected} providers connected`);
    console.log(`  - ${result.summary.providersWithUsage} providers with usage data`);
    console.log(`  - ${result.summary.totalTokensUsed.toLocaleString()} total tokens used`);
    console.log(`  - ${result.summary.totalMessagesAnalyzed.toLocaleString()} messages analyzed`);
    console.log(`  - ${result.summary.totalPartsAnalyzed.toLocaleString()} parts analyzed`);
    
  } catch (error) {
    console.error('\n=== Extraction Failed ===');
    console.error(error);
    process.exit(1);
  }
}

// Run the extraction
main();

export { main, extractUsageData, readAuthConfig, calculateRolling5HourWindows, calculateWeeklyUsage };
