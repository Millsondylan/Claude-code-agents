/**
 * Terminal Usage Dashboard - TypeScript Type Definitions
 * 
 * Type definitions for the provider usage dashboard UI.
 * Matches the JSON structure from provider-usage-data.json
 */

/**
 * Represents a single 5-hour rolling window of token usage
 */
export interface RollingWindow {
  /** ISO 8601 timestamp when the window started */
  windowStart: string;
  /** ISO 8601 timestamp when the window ended */
  windowEnd: string;
  /** Total tokens used in this window */
  tokensUsed: number;
  /** Usage as percentage of provider's limit */
  percentageOfLimit: number;
}

/**
 * Time window boundaries
 */
export interface TimeWindow {
  /** Start of the time window (ISO 8601) */
  start: string;
  /** End of the time window (ISO 8601) */
  end: string;
}

/**
 * Known API limits for a provider
 */
export interface KnownLimits {
  /** Maximum tokens allowed per window/period */
  tokensPerWindow: number;
}

/**
 * Complete provider usage data
 */
export interface ProviderUsage {
  /** Provider identifier (e.g., 'anthropic', 'kimi-for-coding') */
  provider: string;
  /** Human-readable display name (e.g., 'Claude (Anthropic)') */
  displayName: string;
  /** Total tokens used (all time or in window) */
  tokensUsed: number;
  /** Input tokens consumed */
  tokensInput: number;
  /** Output tokens generated */
  tokensOutput: number;
  /** Reasoning tokens (for models that support it) */
  tokensReasoning: number;
  /** Tokens read from cache */
  tokensCacheRead: number;
  /** Tokens written to cache */
  tokensCacheWrite: number;
  /** Number of messages sent */
  messageCount: number;
  /** Number of parts (for multi-part messages) */
  partCount: number;
  /** Type of window: '5-hour' rolling or 'weekly' quota */
  windowType: '5-hour' | 'weekly';
  /** Time boundaries for the current data */
  timeWindow: TimeWindow;
  /** Known API limits */
  knownLimits: KnownLimits;
  /** Additional notes about the data */
  notes: string[];
  /** Array of rolling windows (only for 5-hour window types) */
  rollingWindows?: RollingWindow[];
  /** Current usage as percentage of limit */
  usagePercentageOfLimit: number;
}

/**
 * Data source metadata from extraction
 */
export interface DataSource {
  /** Path to the SQLite database */
  databasePath: string;
  /** Path to the auth configuration */
  authPath: string;
  /** Total messages in database */
  messageCount: number;
  /** Total parts in database */
  partCount: number;
}

/**
 * Summary statistics across all providers
 */
export interface Summary {
  /** Total tokens used across all providers */
  totalTokensUsed: number;
  /** Total messages analyzed */
  totalMessagesAnalyzed: number;
  /** Total parts analyzed */
  totalPartsAnalyzed: number;
  /** Number of connected providers */
  providersConnected: number;
  /** Number of providers with actual usage */
  providersWithUsage: number;
}

/**
 * Root data structure from provider-usage-data.json
 */
export interface ProviderUsageData {
  /** When the data was generated */
  generatedAt: string;
  /** Version of the extraction tool */
  extractionVersion: string;
  /** Information about the data source */
  dataSource: DataSource;
  /** Array of provider usage data */
  providers: ProviderUsage[];
  /** Summary statistics */
  summary: Summary;
}

/**
 * Dashboard configuration settings
 */
export interface DashboardConfig {
  /** Auto-refresh interval in milliseconds (default: 5000) */
  refreshIntervalMs: number;
  /** Enable/disable auto-refresh */
  autoRefresh: boolean;
  /** Color theme configuration */
  colors: ColorTheme;
  /** Number of rolling windows to display (default: 10) */
  maxWindowsToShow: number;
  /** Show providers with zero usage */
  showZeroUsage: boolean;
}

/**
 * Color theme configuration for the dashboard
 */
export interface ColorTheme {
  /** Primary brand color (hex) */
  primary: string;
  /** Secondary accent color (hex) */
  secondary: string;
  /** Success/good status color (hex) */
  success: string;
  /** Warning color (hex) */
  warning: string;
  /** Danger/error color (hex) */
  danger: string;
  /** Info/neutral color (hex) */
  info: string;
  /** Text color for headers (hex) */
  headerText: string;
  /** Text color for values (hex) */
  valueText: string;
  /** Border color (hex) */
  border: string;
}

/**
 * Time remaining calculation for countdown displays
 */
export interface TimeRemaining {
  /** Total milliseconds remaining */
  totalMs: number;
  /** Hours remaining (0-23) */
  hours: number;
  /** Minutes remaining (0-59) */
  minutes: number;
  /** Seconds remaining (0-59) */
  seconds: number;
  /** Whether the time has expired */
  isExpired: boolean;
  /** Human-readable formatted string (e.g., "2h 15m") */
  formatted: string;
}

/**
 * Dashboard display state
 */
export interface DashboardState {
  /** When the data was last loaded */
  lastLoadedAt: Date | null;
  /** Whether data is currently being loaded */
  isLoading: boolean;
  /** Error message if loading failed */
  error: string | null;
  /** Current provider data */
  data: ProviderUsageData | null;
}

/**
 * Provider status calculated from usage data
 */
export type ProviderStatus = 'healthy' | 'warning' | 'critical' | 'expired';

/**
 * Extended provider info with calculated fields
 */
export interface ProviderDisplayInfo extends ProviderUsage {
  /** Calculated status based on usage percentage */
  status: ProviderStatus;
  /** Time remaining until window resets (for 5-hour windows) */
  timeRemaining: TimeRemaining | null;
  /** Whether this provider has a rolling window */
  hasRollingWindow: boolean;
  /** Formatted token count (e.g., "1.2M") */
  tokensFormatted: string;
  /** Formatted percentage with symbol */
  percentageFormatted: string;
}

/**
 * Default dashboard configuration
 */
export const DEFAULT_CONFIG: DashboardConfig = {
  refreshIntervalMs: 5000,
  autoRefresh: true,
  maxWindowsToShow: 10,
  showZeroUsage: true,
  colors: {
    primary: '#3b82f6',      // Blue
    secondary: '#8b5cf6',    // Purple
    success: '#22c55e',      // Green
    warning: '#f59e0b',      // Amber
    danger: '#ef4444',       // Red
    info: '#06b6d4',         // Cyan
    headerText: '#e5e7eb',   // Gray-200
    valueText: '#ffffff',    // White
    border: '#374151',       // Gray-700
  },
};

/**
 * Status threshold configuration
 */
export const STATUS_THRESHOLDS = {
  /** Below this percentage is considered healthy */
  healthy: 50,
  /** Below this percentage is a warning, above is critical */
  warning: 80,
  /** Above this percentage is critical */
  critical: 100,
} as const;
