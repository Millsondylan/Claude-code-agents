/**
 * Terminal Usage Dashboard - Progress Bar Component
 * 
 * ASCII progress bar renderer with color coding support.
 * Generates 50-character width progress bars with percentage display.
 */

import { STATUS_THRESHOLDS } from '../types';

/**
 * ANSI color codes for terminal output
 */
export const ANSI_COLORS = {
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  red: '\x1b[31m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
  gray: '\x1b[90m',
  reset: '\x1b[0m',
  bold: '\x1b[1m',
} as const;

/**
 * Color threshold configuration
 */
export type ColorCode = 'green' | 'yellow' | 'red' | 'blue' | 'cyan' | 'gray';

/**
 * Options for generating a progress bar
 */
export interface ProgressBarOptions {
  /** Width of the progress bar in characters (default: 50) */
  width?: number;
  /** Character to use for filled portion (default: '█') */
  fillChar?: string;
  /** Character to use for empty portion (default: '░') */
  emptyChar?: string;
  /** Show percentage at the end (default: true) */
  showPercentage?: boolean;
  /** Decimal precision for percentage (default: 1) */
  precision?: number;
  /** Force a specific color instead of auto-calculating */
  color?: ColorCode;
  /** Disable color output (default: false) */
  noColor?: boolean;
  /** Prefix label to show before the bar */
  label?: string;
  /** Custom threshold for yellow color (default: 50) */
  yellowThreshold?: number;
  /** Custom threshold for red color (default: 80) */
  redThreshold?: number;
}

/**
 * Default progress bar options
 */
const DEFAULT_OPTIONS: Required<ProgressBarOptions> = {
  width: 50,
  fillChar: '█',
  emptyChar: '░',
  showPercentage: true,
  precision: 1,
  color: undefined as unknown as ColorCode,
  noColor: false,
  label: '',
  yellowThreshold: STATUS_THRESHOLDS.healthy,
  redThreshold: STATUS_THRESHOLDS.warning,
};

/**
 * Generate an ASCII progress bar string
 * 
 * Color coding based on percentage:
 * - Green: < 50% (below yellowThreshold)
 * - Yellow: 50-80% (between yellowThreshold and redThreshold)
 * - Red: > 80% (above redThreshold)
 * 
 * Edge cases:
 * - 0%: Empty bar
 * - 100%: Full bar
 * - >100%: Full bar with percentage > 100
 * 
 * @param percentage - Percentage value (0-100 or higher)
 * @param options - Progress bar options
 * @returns Formatted progress bar string
 */
export function generateProgressBar(
  percentage: number,
  options: ProgressBarOptions = {}
): string {
  const opts = { ...DEFAULT_OPTIONS, ...options };
  const clampedPercentage = Math.max(0, percentage);
  const cappedPercentage = Math.min(100, clampedPercentage);
  
  // Calculate filled and empty portions
  const filledLength = Math.round((cappedPercentage / 100) * opts.width);
  const emptyLength = opts.width - filledLength;
  
  const filled = opts.fillChar.repeat(filledLength);
  const empty = opts.emptyChar.repeat(emptyLength);
  
  // Determine color
  const colorCode = opts.color || getColorForPercentage(clampedPercentage, opts);
  
  // Build the bar
  let bar = '';
  
  // Add label if provided
  if (opts.label) {
    bar += `${opts.label} `;
  }
  
  // Add colored bar
  if (opts.noColor) {
    bar += `[${filled}${empty}]`;
  } else {
    bar += `${ANSI_COLORS[colorCode]}[${filled}${empty}]${ANSI_COLORS.reset}`;
  }
  
  // Add percentage
  if (opts.showPercentage) {
    const percentStr = clampedPercentage.toFixed(opts.precision);
    bar += ` ${percentStr}%`;
  }
  
  return bar;
}

/**
 * Get the appropriate color for a percentage value
 * 
 * @param percentage - Percentage value
 * @param options - Options with threshold overrides
 * @returns Color code
 */
function getColorForPercentage(
  percentage: number,
  options: ProgressBarOptions
): ColorCode {
  const yellowThreshold = options.yellowThreshold ?? STATUS_THRESHOLDS.healthy;
  const redThreshold = options.redThreshold ?? STATUS_THRESHOLDS.warning;
  
  if (percentage < yellowThreshold) {
    return 'green';
  } else if (percentage < redThreshold) {
    return 'yellow';
  } else {
    return 'red';
  }
}

/**
 * Generate a compact progress bar (20 characters wide)
 * 
 * @param percentage - Percentage value
 * @param options - Progress bar options
 * @returns Formatted compact progress bar
 */
export function generateCompactProgressBar(
  percentage: number,
  options: ProgressBarOptions = {}
): string {
  return generateProgressBar(percentage, {
    ...options,
    width: 20,
    precision: 0,
  });
}

/**
 * Generate a horizontal bar chart segment
 * Useful for multi-bar comparisons
 * 
 * @param value - Current value
 * @param max - Maximum value for scaling
 * @param options - Progress bar options
 * @returns Formatted bar string
 */
export function generateHorizontalBar(
  value: number,
  max: number,
  options: ProgressBarOptions = {}
): string {
  const percentage = max > 0 ? (value / max) * 100 : 0;
  return generateProgressBar(percentage, options);
}

/**
 * Generate a usage bar with token count display
 * 
 * @param current - Current usage
 * @param limit - Usage limit
 * @param options - Progress bar options
 * @returns Formatted usage bar string
 */
export function generateUsageBar(
  current: number,
  limit: number,
  options: ProgressBarOptions = {}
): string {
  const percentage = limit > 0 ? (current / limit) * 100 : 0;
  const formattedCurrent = formatNumber(current);
  const formattedLimit = formatNumber(limit);
  
  const bar = generateProgressBar(percentage, {
    ...options,
    showPercentage: false,
  });
  
  return `${bar} ${formattedCurrent}/${formattedLimit}`;
}

/**
 * Format a number with appropriate suffix (K, M, B)
 * 
 * @param num - Number to format
 * @returns Formatted string
 */
function formatNumber(num: number): string {
  if (num >= 1_000_000_000) {
    return `${(num / 1_000_000_000).toFixed(1)}B`;
  } else if (num >= 1_000_000) {
    return `${(num / 1_000_000).toFixed(1)}M`;
  } else if (num >= 1_000) {
    return `${(num / 1_000).toFixed(1)}K`;
  }
  return num.toString();
}

/**
 * Strip ANSI color codes from a string
 * Useful for calculating string length without color codes
 * 
 * @param str - String with potential ANSI codes
 * @returns String without ANSI codes
 */
export function stripAnsiCodes(str: string): string {
  // eslint-disable-next-line no-control-regex
  return str.replace(/\x1b\[[0-9;]*m/g, '');
}

/**
 * Calculate the visible length of a string (excluding ANSI codes)
 * 
 * @param str - String to measure
 * @returns Visible character count
 */
export function getVisibleLength(str: string): number {
  return stripAnsiCodes(str).length;
}

/**
 * Center text within a given width
 * 
 * @param text - Text to center
 * @param width - Total width
 * @param fillChar - Character to use for padding
 * @returns Centered text
 */
export function centerText(text: string, width: number, fillChar: string = ' '): string {
  const visibleLength = getVisibleLength(text);
  if (visibleLength >= width) {
    return text;
  }
  
  const padding = width - visibleLength;
  const leftPad = Math.floor(padding / 2);
  const rightPad = padding - leftPad;
  
  return fillChar.repeat(leftPad) + text + fillChar.repeat(rightPad);
}

/**
 * Generate a multi-line progress bar with label and value
 * 
 * @param label - Label for the bar
 * @param percentage - Percentage value
 * @param value - Optional value to display
 * @param options - Progress bar options
 * @returns Formatted multi-line string
 */
export function generateLabeledProgressBar(
  label: string,
  percentage: number,
  value?: string,
  options: ProgressBarOptions = {}
): string {
  const bar = generateProgressBar(percentage, {
    ...options,
    showPercentage: !value,
  });
  
  if (value) {
    return `${label.padEnd(20)} ${bar} ${value}`;
  }
  
  return `${label.padEnd(20)} ${bar}`;
}

/**
 * Colorize text with ANSI codes
 * 
 * @param text - Text to colorize
 * @param color - Color to apply
 * @returns Colorized text
 */
export function colorize(text: string, color: ColorCode): string {
  return `${ANSI_COLORS[color]}${text}${ANSI_COLORS.reset}`;
}

/**
 * Apply bold formatting to text
 * 
 * @param text - Text to bold
 * @returns Bold text
 */
export function bold(text: string): string {
  return `${ANSI_COLORS.bold}${text}${ANSI_COLORS.reset}`;
}
