/**
 * Terminal Usage Dashboard - Provider Card Component
 *
 * Individual provider display component with ASCII box-drawing characters.
 * Displays provider name, usage progress bar, message count, and time remaining.
 */

import type { ProviderUsage, TimeRemaining, ProviderStatus } from '../types';
import {
  generateCompactProgressBar,
  ANSI_COLORS,
  colorize,
  bold,
  stripAnsiCodes,
} from './progress-bar';
import {
  calculateTimeUntil5HourReset,
  calculateTimeUntilSunday,
  formatDuration,
} from '../lib/time-utils';

/**
 * Configuration for card dimensions
 */
const CARD_CONFIG = {
  /** Total card width including borders */
  width: 50,
  /** Horizontal padding inside the card */
  padding: 1,
  /** Box drawing characters */
  chars: {
    topLeft: '┌',
    topRight: '┐',
    bottomLeft: '└',
    bottomRight: '┘',
    horizontal: '─',
    vertical: '│',
  },
} as const;

/**
 * Format a token count with appropriate suffix (K, M, B)
 *
 * @param tokens - Number of tokens
 * @returns Formatted string (e.g., "2.1M")
 */
export function formatTokenCount(tokens: number): string {
  if (tokens >= 1_000_000_000) {
    return `${(tokens / 1_000_000_000).toFixed(1)}B`;
  } else if (tokens >= 1_000_000) {
    return `${(tokens / 1_000_000).toFixed(1)}M`;
  } else if (tokens >= 1_000) {
    return `${(tokens / 1_000).toFixed(1)}K`;
  }
  return tokens.toLocaleString();
}

/**
 * Format a message count with comma separators
 *
 * @param count - Number of messages
 * @returns Formatted string (e.g., "1,247")
 */
export function formatMessageCount(count: number): string {
  return count.toLocaleString();
}

/**
 * Determine provider status based on usage percentage
 *
 * Color coding based on percentage:
 * - Green (healthy): < 50%
 * - Yellow (warning): 50-80%
 * - Red (critical): > 80%
 *
 * @param percentage - Usage percentage
 * @returns Status string
 */
export function getProviderStatus(percentage: number): ProviderStatus {
  if (percentage > 80) return 'critical';
  if (percentage >= 50) return 'warning';
  return 'healthy';
}

/**
 * Get status indicator character
 *
 * @param status - Provider status
 * @returns Colored status indicator
 */
export function getStatusIndicator(status: ProviderStatus): string {
  const indicators: Record<ProviderStatus, string> = {
    healthy: colorize('●', 'green'),
    warning: colorize('●', 'yellow'),
    critical: colorize('●', 'red'),
    expired: colorize('●', 'gray'),
  };
  return indicators[status];
}

/**
 * Calculate time remaining until next reset based on window type
 *
 * @param provider - Provider usage data
 * @returns TimeRemaining object or null
 */
export function calculateProviderTimeRemaining(
  provider: ProviderUsage
): TimeRemaining | null {
  const now = new Date();

  if (provider.windowType === '5-hour') {
    return calculateTimeUntil5HourReset(now);
  } else if (provider.windowType === 'weekly') {
    return calculateTimeUntilSunday(now);
  }

  return null;
}

/**
 * Calculate effective percentage to display
 * For weekly providers showing current period usage
 *
 * @param provider - Provider usage data
 * @returns Percentage to display
 */
export function calculateDisplayPercentage(provider: ProviderUsage): number {
  // Use the usagePercentageOfLimit directly from the data
  // This is already calculated by the data extraction tool
  return provider.usagePercentageOfLimit;
}

/**
 * Generate the top border line with the provider name
 *
 * @param displayName - Provider display name
 * @returns Formatted top border line
 */
export function generateCardTop(displayName: string): string {
  const { chars, width } = CARD_CONFIG;

  // Format: ┌─ Name ─────────────┐
  // Count:  1 + 1 + 1 + name.length + 1 + filler + 1 = width
  // So:     filler = width - 5 - name.length
  const fixedOverhead = 5; // ┌ + ─ + space + space + ┐

  let namePart = displayName;
  const maxNameLength = width - fixedOverhead;

  if (namePart.length > maxNameLength) {
    namePart = namePart.slice(0, maxNameLength - 1) + '…';
  }

  const fillerLength = width - fixedOverhead - namePart.length;
  const filler = chars.horizontal.repeat(fillerLength);

  return `${chars.topLeft}${chars.horizontal} ${namePart} ${filler}${chars.topRight}`;
}

/**
 * Generate the bottom border line
 *
 * @returns Formatted bottom border line
 */
export function generateCardBottom(): string {
  const { chars, width } = CARD_CONFIG;
  const contentWidth = width - 2;
  const horizontalLine = chars.horizontal.repeat(contentWidth);
  return `${chars.bottomLeft}${horizontalLine}${chars.bottomRight}`;
}

/**
 * Center content within the card width
 *
 * @param content - Content to center
 * @returns Centered content with borders
 */
export function centerCardContent(content: string): string {
  const { chars, width } = CARD_CONFIG;
  const contentWidth = width - 4; // Subtract borders and 2 spaces padding

  const visibleContent = stripAnsiCodes(content);
  const contentLength = visibleContent.length;

  if (contentLength >= contentWidth) {
    return `${chars.vertical} ${content.slice(0, contentWidth)} ${chars.vertical}`;
  }

  const padding = contentWidth - contentLength;
  const leftPad = Math.floor(padding / 2);
  const rightPad = padding - leftPad;

  return `${chars.vertical} ${' '.repeat(leftPad)}${content}${' '.repeat(rightPad)} ${chars.vertical}`;
}

/**
 * Left-align content within the card width
 *
 * @param content - Content to align
 * @returns Left-aligned content with borders
 */
export function leftAlignCardContent(content: string): string {
  const { chars, width } = CARD_CONFIG;
  const contentWidth = width - 4; // Subtract borders and 2 spaces padding

  const visibleContent = stripAnsiCodes(content);
  const contentLength = visibleContent.length;

  if (contentLength >= contentWidth) {
    return `${chars.vertical} ${content.slice(0, contentWidth)} ${chars.vertical}`;
  }

  const rightPad = contentWidth - contentLength;
  return `${chars.vertical} ${content}${' '.repeat(rightPad)} ${chars.vertical}`;
}

/**
 * Generate the progress bar line for a provider card
 *
 * @param provider - Provider usage data
 * @returns Formatted progress bar line
 */
export function generateCardProgressLine(provider: ProviderUsage): string {
  const percentage = calculateDisplayPercentage(provider);
  const windowLabel = provider.windowType === '5-hour' ? '5h' : 'wk';

  // Generate compact progress bar (20 chars wide)
  const bar = generateCompactProgressBar(percentage, {
    showPercentage: false,
  });

  // Format: [████████░░░░░░░░░░] 45.2% (5h)
  const percentStr = percentage.toFixed(1);
  const content = `${bar} ${percentStr}% (${windowLabel})`;

  return leftAlignCardContent(content);
}

/**
 * Generate the stats line for a provider card
 *
 * @param provider - Provider usage data
 * @param timeRemaining - Time remaining until reset
 * @returns Formatted stats line
 */
export function generateCardStatsLine(
  provider: ProviderUsage,
  timeRemaining: TimeRemaining | null
): string {
  const tokens = formatTokenCount(provider.tokensUsed);
  const msgs = formatMessageCount(provider.messageCount);
  const timeStr = timeRemaining ? timeRemaining.formatted : 'N/A';

  // Format: 2.1M tokens • 1,247 msgs • 2h 15m
  const content = `${tokens} tokens • ${msgs} msgs • ${timeStr}`;

  return leftAlignCardContent(content);
}

/**
 * Generate a complete provider card as an array of strings
 *
 * @param provider - Provider usage data
 * @returns Array of card lines
 */
export function generateProviderCard(provider: ProviderUsage): string[] {
  const timeRemaining = calculateProviderTimeRemaining(provider);

  return [
    generateCardTop(provider.displayName),
    generateCardProgressLine(provider),
    generateCardStatsLine(provider, timeRemaining),
    generateCardBottom(),
  ];
}

/**
 * Render a provider card to a single string with newlines
 *
 * @param provider - Provider usage data
 * @returns Complete card as a string
 */
export function renderProviderCard(provider: ProviderUsage): string {
  return generateProviderCard(provider).join('\n');
}

/**
 * Render multiple provider cards with spacing between them
 *
 * @param providers - Array of provider usage data
 * @returns Complete render as a string
 */
export function renderProviderCards(providers: ProviderUsage[]): string {
  if (providers.length === 0) {
    return 'No providers to display.';
  }

  const cards = providers.map((provider) => generateProviderCard(provider));

  // Join cards with empty line between them
  return cards.map((card) => card.join('\n')).join('\n\n');
}

/**
 * Get a short status summary for a provider
 *
 * @param provider - Provider usage data
 * @returns Status summary string
 */
export function getProviderStatusSummary(provider: ProviderUsage): string {
  const percentage = calculateDisplayPercentage(provider);
  const status = getProviderStatus(percentage);
  const indicator = getStatusIndicator(status);

  return `${indicator} ${provider.displayName}: ${percentage.toFixed(1)}%`;
}

/**
 * Filter providers by window type
 *
 * @param providers - Array of provider usage data
 * @param windowType - Window type to filter by
 * @returns Filtered array
 */
export function filterProvidersByWindowType(
  providers: ProviderUsage[],
  windowType: '5-hour' | 'weekly'
): ProviderUsage[] {
  return providers.filter((p) => p.windowType === windowType);
}

/**
 * Sort providers by usage percentage (highest first)
 *
 * @param providers - Array of provider usage data
 * @returns Sorted array
 */
export function sortProvidersByUsage(
  providers: ProviderUsage[]
): ProviderUsage[] {
  return [...providers].sort(
    (a, b) => b.usagePercentageOfLimit - a.usagePercentageOfLimit
  );
}

/**
 * Sort providers by display name (alphabetically)
 *
 * @param providers - Array of provider usage data
 * @returns Sorted array
 */
export function sortProvidersByName(
  providers: ProviderUsage[]
): ProviderUsage[] {
  return [...providers].sort((a, b) =>
    a.displayName.localeCompare(b.displayName)
  );
}
