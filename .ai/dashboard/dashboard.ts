#!/usr/bin/env node
/**
 * Terminal Usage Dashboard - Main Dashboard Renderer
 *
 * Main dashboard UI component that renders the terminal usage dashboard.
 * Handles terminal clearing, drawing, keyboard input, and auto-refresh.
 */

import * as readline from 'readline';
import * as path from 'path';
import { loadProviderData } from './lib/data-loader';
import { calculateTimeUntil5HourReset, calculateTimeUntilSunday, formatDuration } from './lib/time-utils';
import { generateProviderCard, formatTokenCount, formatMessageCount } from './components/provider-card';
import type { ProviderUsageData, TimeRemaining, ProviderUsage } from './types';

/**
 * Calculate the default data path based on script location
 */
function getDefaultDataPath(): string {
  // Try to find the data file relative to this script's location
  const scriptDir = __dirname;
  const possiblePaths = [
    // Running from .ai/dashboard/ directory
    path.join(scriptDir, '..', 'extracted', 'provider-usage-data.json'),
    // Running from project root
    path.join(process.cwd(), '.ai', 'extracted', 'provider-usage-data.json'),
  ];

  for (const p of possiblePaths) {
    if (require('fs').existsSync(p)) {
      return p;
    }
  }

  // Default to project root relative path
  return path.join(process.cwd(), '.ai', 'extracted', 'provider-usage-data.json');
}

/**
 * Dashboard configuration from CLI arguments
 */
interface DashboardOptions {
  /** Auto-refresh interval in seconds */
  interval: number;
  /** Enable compact mode */
  compact: boolean;
  /** Run once and exit */
  once: boolean;
  /** Path to data file */
  dataPath: string;
}

/**
 * Default dashboard options
 */
const DEFAULT_OPTIONS: DashboardOptions = {
  interval: 30,
  compact: false,
  once: false,
  dataPath: getDefaultDataPath(),
};

/**
 * ANSI escape codes for terminal control
 */
const ANSI = {
  clear: '\x1b[2J',
  cursorHome: '\x1b[H',
  cursorHide: '\x1b[?25l',
  cursorShow: '\x1b[?25h',
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
};

/**
 * Box drawing characters for dashboard borders
 */
const BOX_CHARS = {
  topLeft: '╭',
  topRight: '╮',
  bottomLeft: '╰',
  bottomRight: '╯',
  horizontal: '─',
  vertical: '│',
  leftT: '├',
  rightT: '┤',
};

/**
 * Dashboard state
 */
interface DashboardRuntimeState {
  /** Current data */
  data: ProviderUsageData | null;
  /** Last error message */
  error: string | null;
  /** Last update timestamp */
  lastUpdate: Date | null;
  /** Seconds until next refresh */
  countdown: number;
  /** Whether dashboard is running */
  isRunning: boolean;
  /** Terminal width */
  terminalWidth: number;
  /** Terminal height */
  terminalHeight: number;
}

/**
 * Create initial runtime state
 */
function createRuntimeState(): DashboardRuntimeState {
  return {
    data: null,
    error: null,
    lastUpdate: null,
    countdown: 0,
    isRunning: true,
    terminalWidth: process.stdout.columns || 80,
    terminalHeight: process.stdout.rows || 24,
  };
}

/**
 * Calculate time remaining for a provider
 */
function calculateProviderTimeRemaining(provider: ProviderUsage): TimeRemaining | null {
  const now = new Date();

  if (provider.windowType === '5-hour') {
    return calculateTimeUntil5HourReset(now);
  } else if (provider.windowType === 'weekly') {
    return calculateTimeUntilSunday(now);
  }

  return null;
}

/**
 * Format window type for display
 */
function formatWindowType(windowType: '5-hour' | 'weekly'): string {
  return windowType === '5-hour' ? '5h' : 'weekly';
}

/**
 * Generate the dashboard header line
 */
function generateHeader(timestamp: Date, width: number): string {
  const title = 'OpenCode Usage Dashboard';
  const timeStr = timestamp.toLocaleTimeString('en-US', { hour12: false });
  const suffix = `Last Update: ${timeStr}`;

  // Calculate filler: width - 2 (corners) - 1 (space) - title.length - 1 (space) - 1 (space) - suffix.length - 1 (space)
  const fixedWidth = 2 + 1 + title.length + 1 + 1 + suffix.length + 1;
  const fillerLength = Math.max(0, width - fixedWidth);
  const filler = BOX_CHARS.horizontal.repeat(fillerLength);

  return `${BOX_CHARS.topLeft}${BOX_CHARS.horizontal} ${title} ${filler} ${suffix} ${BOX_CHARS.topRight}`;
}

/**
 * Generate the dashboard footer line
 */
function generateFooter(width: number, countdown: number, interval: number): string {
  const controls = `Auto-refresh: ${interval}s (press 'r' to refresh, 'q' to quit)`;
  const countdownStr = countdown > 0 ? `${countdown}s` : 'refreshing...';
  const fullText = `${controls} [${countdownStr}]`;

  const fixedWidth = 2 + fullText.length;
  const fillerLength = Math.max(0, width - fixedWidth);
  const filler = BOX_CHARS.horizontal.repeat(fillerLength);

  return `${BOX_CHARS.bottomLeft}${filler}${fullText}${BOX_CHARS.bottomRight}`;
}

/**
 * Generate a separator line between sections
 */
function generateSeparator(width: number, label?: string): string {
  if (label) {
    // Format: ├─ Label ───────────┤
    const fixedWidth = 2 + 1 + 1 + label.length + 1; // corners + dashes + spaces + label
    const fillerLength = Math.max(0, width - fixedWidth);
    const filler = BOX_CHARS.horizontal.repeat(fillerLength);
    return `${BOX_CHARS.leftT}${BOX_CHARS.horizontal} ${label} ${filler}${BOX_CHARS.rightT}`;
  } else {
    const filler = BOX_CHARS.horizontal.repeat(Math.max(0, width - 2));
    return `${BOX_CHARS.leftT}${filler}${BOX_CHARS.rightT}`;
  }
}

/**
 * Generate an empty line
 */
function generateEmptyLine(width: number): string {
  const contentWidth = Math.max(0, width - 2);
  return `${BOX_CHARS.vertical}${' '.repeat(contentWidth)}${BOX_CHARS.vertical}`;
}

/**
 * Generate summary section
 */
function generateSummary(data: ProviderUsageData, width: number): string[] {
  const lines: string[] = [];
  const { summary } = data;

  const totalTokens = formatTokenCount(summary.totalTokensUsed);
  const totalMsgs = formatMessageCount(summary.totalMessagesAnalyzed);
  const providerCount = summary.providersConnected;
  const activeProviders = summary.providersWithUsage;

  const content = `Total: ${totalTokens} tokens • ${totalMsgs} msgs across ${activeProviders}/${providerCount} providers`;

  const contentWidth = Math.max(0, width - 4); // Subtract borders and padding
  const visibleContent = content.slice(0, contentWidth);
  const rightPad = Math.max(0, contentWidth - visibleContent.length);

  lines.push(`${BOX_CHARS.vertical} ${visibleContent}${' '.repeat(rightPad)} ${BOX_CHARS.vertical}`);

  return lines;
}

/**
 * Generate a compact provider display (single line per provider)
 */
function generateCompactProviderLine(provider: ProviderUsage, width: number): string {
  const percentage = provider.usagePercentageOfLimit;
  const tokens = formatTokenCount(provider.tokensUsed);
  const msgs = formatMessageCount(provider.messageCount);
  const windowLabel = formatWindowType(provider.windowType);

  // Build progress bar manually for compact view
  const barWidth = 20;
  const filledLength = Math.round((Math.min(100, percentage) / 100) * barWidth);
  const emptyLength = barWidth - filledLength;
  const bar = `[${'█'.repeat(filledLength)}${'░'.repeat(emptyLength)}]`;

  const content = `${provider.displayName}: ${bar} ${percentage.toFixed(1)}% (${windowLabel}) • ${tokens} • ${msgs} msgs`;

  const contentWidth = Math.max(0, width - 4);
  const visibleContent = content.slice(0, contentWidth);
  const rightPad = Math.max(0, contentWidth - visibleContent.length);

  return `${BOX_CHARS.vertical} ${visibleContent}${' '.repeat(rightPad)} ${BOX_CHARS.vertical}`;
}

/**
 * Generate error display
 */
function generateErrorDisplay(error: string, width: number): string[] {
  const lines: string[] = [];
  const contentWidth = Math.max(0, width - 4);

  lines.push(generateSeparator(width, 'Error'));

  const errorLines = error.length > contentWidth
    ? [error.slice(0, contentWidth), error.slice(contentWidth, contentWidth * 2)]
    : [error];

  for (const line of errorLines) {
    const rightPad = Math.max(0, contentWidth - line.length);
    lines.push(`${BOX_CHARS.vertical} ${line}${' '.repeat(rightPad)} ${BOX_CHARS.vertical}`);
  }

  return lines;
}

/**
 * Clear the terminal screen
 */
function clearScreen(): void {
  process.stdout.write(ANSI.clear + ANSI.cursorHome);
}

/**
 * Hide the cursor
 */
function hideCursor(): void {
  process.stdout.write(ANSI.cursorHide);
}

/**
 * Show the cursor
 */
function showCursor(): void {
  process.stdout.write(ANSI.cursorShow);
}

/**
 * Draw the complete dashboard
 */
function drawDashboard(state: DashboardRuntimeState, options: DashboardOptions): void {
  const width = state.terminalWidth;
  const lines: string[] = [];

  // Header
  const timestamp = state.lastUpdate || new Date();
  lines.push(generateHeader(timestamp, width));
  lines.push(generateEmptyLine(width));

  if (state.error) {
    // Show error
    lines.push(...generateErrorDisplay(state.error, width));
  } else if (state.data) {
    const { data } = state;

    if (options.compact) {
      // Compact mode: single line per provider
      for (const provider of data.providers) {
        lines.push(generateCompactProviderLine(provider, width));
      }
    } else {
      // Full mode: detailed cards
      for (let i = 0; i < data.providers.length; i++) {
        const provider = data.providers[i];
        const card = generateProviderCard(provider);

        // Add separator between providers (except before first)
        if (i > 0) {
          lines.push(generateEmptyLine(width));
        }

        // Convert card to full-width lines
        for (const cardLine of card) {
          // Card lines are already formatted with box chars, just add padding to fit width
          const visibleLength = cardLine.replace(/\x1b\[[0-9;]*m/g, '').length;
          if (visibleLength < width) {
            const padding = width - visibleLength - 1; // -1 for the │ at end
            lines.push(cardLine.slice(0, -1) + ' '.repeat(Math.max(0, padding)) + BOX_CHARS.vertical);
          } else {
            lines.push(cardLine);
          }
        }
      }
    }

    // Summary section
    lines.push(generateEmptyLine(width));
    lines.push(generateSeparator(width, 'Summary'));
    lines.push(...generateSummary(data, width));
  } else {
    // Loading state
    const contentWidth = Math.max(0, width - 4);
    const loadingMsg = 'Loading...';
    const leftPad = Math.floor((contentWidth - loadingMsg.length) / 2);
    const rightPad = contentWidth - loadingMsg.length - leftPad;
    lines.push(`${BOX_CHARS.vertical} ${' '.repeat(leftPad)}${loadingMsg}${' '.repeat(rightPad)} ${BOX_CHARS.vertical}`);
  }

  // Footer with controls
  lines.push(generateEmptyLine(width));
  lines.push(generateFooter(width, state.countdown, options.interval));

  // Draw everything
  clearScreen();
  process.stdout.write(lines.join('\n') + '\n');
}

/**
 * Load data and update state
 */
function refreshData(state: DashboardRuntimeState, options: DashboardOptions): void {
  try {
    const data = loadProviderData(options.dataPath);
    state.data = data;
    state.error = null;
    state.lastUpdate = new Date();
  } catch (error) {
    state.error = error instanceof Error ? error.message : 'Unknown error loading data';
    if (!state.data) {
      state.data = null;
    }
  }
}

/**
 * Set up keyboard input handling
 */
function setupInputHandling(state: DashboardRuntimeState, options: DashboardOptions, refreshCallback: () => void): void {
  readline.emitKeypressEvents(process.stdin);

  if (process.stdin.isTTY) {
    process.stdin.setRawMode(true);
  }

  process.stdin.on('keypress', (str, key) => {
    if (key.ctrl && key.name === 'c') {
      // Ctrl+C - quit
      shutdown(state);
    } else if (key.name === 'q') {
      // q - quit
      shutdown(state);
    } else if (key.name === 'r') {
      // r - refresh now
      state.countdown = 0;
      refreshCallback();
    }
  });
}

/**
 * Set up terminal resize handling
 */
function setupResizeHandling(state: DashboardRuntimeState): void {
  process.stdout.on('resize', () => {
    state.terminalWidth = process.stdout.columns || 80;
    state.terminalHeight = process.stdout.rows || 24;
  });
}

/**
 * Clean shutdown
 */
function shutdown(state: DashboardRuntimeState): void {
  state.isRunning = false;
  showCursor();
  clearScreen();
  process.exit(0);
}

/**
 * Run the dashboard with auto-refresh
 */
function runDashboard(options: DashboardOptions): void {
  const state = createRuntimeState();

  // Initial setup
  hideCursor();
  setupResizeHandling(state);

  // Initial data load
  refreshData(state, options);
  state.countdown = options.interval;
  drawDashboard(state, options);

  // If running once, exit after first render
  if (options.once) {
    showCursor();
    process.exit(state.error ? 1 : 0);
  }

  // Set up input handling
  let refreshTimer: NodeJS.Timeout | null = null;
  let countdownTimer: NodeJS.Timeout | null = null;

  const doRefresh = (): void => {
    refreshData(state, options);
    state.countdown = options.interval;
    drawDashboard(state, options);
  };

  setupInputHandling(state, options, doRefresh);

  // Countdown timer (update display every second)
  countdownTimer = setInterval(() => {
    if (state.countdown > 0) {
      state.countdown--;
      drawDashboard(state, options);
    }
  }, 1000);

  // Refresh timer
  refreshTimer = setInterval(() => {
    doRefresh();
  }, options.interval * 1000);

  // Handle process termination
  process.on('SIGINT', () => {
    if (refreshTimer) clearInterval(refreshTimer);
    if (countdownTimer) clearInterval(countdownTimer);
    shutdown(state);
  });

  process.on('SIGTERM', () => {
    if (refreshTimer) clearInterval(refreshTimer);
    if (countdownTimer) clearInterval(countdownTimer);
    shutdown(state);
  });
}

/**
 * Parse CLI arguments
 */
function parseArguments(args: string[]): DashboardOptions {
  const options: DashboardOptions = { ...DEFAULT_OPTIONS };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];

    if (arg === '--help' || arg === '-h') {
      showHelp();
      process.exit(0);
    } else if (arg === '--interval' || arg === '-i') {
      const value = args[++i];
      if (value) {
        const interval = parseInt(value, 10);
        if (!isNaN(interval) && interval > 0) {
          options.interval = interval;
        }
      }
    } else if (arg === '--compact' || arg === '-c') {
      options.compact = true;
    } else if (arg === '--once' || arg === '-o') {
      options.once = true;
    } else if (arg === '--data' || arg === '-d') {
      const value = args[++i];
      if (value) {
        options.dataPath = value;
      }
    }
  }

  return options;
}

/**
 * Show help text
 */
function showHelp(): void {
  console.log(`
Usage: usage-dashboard [options]

OpenCode Terminal Usage Dashboard

Options:
  -i, --interval <seconds>  Auto-refresh interval in seconds (default: 30)
  -c, --compact             Enable compact mode (single line per provider)
  -o, --once                Run once and exit (no auto-refresh)
  -d, --data <path>         Path to provider usage data JSON file
  -h, --help                Show this help message

Keyboard Controls:
  r        Refresh data immediately
  q        Quit dashboard
  Ctrl+C   Quit dashboard

Examples:
  usage-dashboard                    # Run with default settings
  usage-dashboard --interval 60      # Refresh every 60 seconds
  usage-dashboard --compact          # Compact display mode
  usage-dashboard --once             # Display once and exit
`);
}

/**
 * Main entry point
 */
function main(): void {
  const args = process.argv.slice(2);
  const options = parseArguments(args);

  runDashboard(options);
}

// Run if this file is executed directly
if (require.main === module) {
  main();
}

// Export for testing
export {
  DashboardOptions,
  DashboardRuntimeState,
  createRuntimeState,
  generateHeader,
  generateFooter,
  generateSeparator,
  generateEmptyLine,
  generateSummary,
  generateCompactProviderLine,
  drawDashboard,
  refreshData,
  parseArguments,
  runDashboard,
};
