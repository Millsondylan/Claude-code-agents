/**
 * Terminal Usage Dashboard - Data Loader Module
 * 
 * Handles loading and watching provider usage data from JSON files.
 * Provides real-time updates via file watching.
 */

import * as fs from 'fs';
import * as path from 'path';
import type { ProviderUsageData, DashboardState } from '../types';

/**
 * Default path to the provider usage data file
 */
export const DEFAULT_DATA_PATH = path.resolve(
  process.cwd(),
  '.ai',
  'extracted',
  'provider-usage-data.json'
);

/**
 * Error class for data loading failures
 */
export class DataLoadError extends Error {
  constructor(
    message: string,
    public readonly code: 'FILE_NOT_FOUND' | 'PARSE_ERROR' | 'INVALID_DATA' | 'ACCESS_DENIED',
    public readonly originalError?: Error
  ) {
    super(message);
    this.name = 'DataLoadError';
  }
}

/**
 * Load provider usage data from a JSON file
 * 
 * @param filePath - Path to the JSON file (defaults to DEFAULT_DATA_PATH)
 * @returns Parsed ProviderUsageData
 * @throws DataLoadError if file cannot be read or parsed
 */
export function loadProviderData(filePath: string = DEFAULT_DATA_PATH): ProviderUsageData {
  // Check if file exists
  if (!fs.existsSync(filePath)) {
    throw new DataLoadError(
      `Provider usage data file not found: ${filePath}`,
      'FILE_NOT_FOUND'
    );
  }

  // Check if it's a file (not a directory)
  const stats = fs.statSync(filePath);
  if (!stats.isFile()) {
    throw new DataLoadError(
      `Path is not a file: ${filePath}`,
      'FILE_NOT_FOUND'
    );
  }

  let fileContent: string;
  
  try {
    fileContent = fs.readFileSync(filePath, 'utf-8');
  } catch (error) {
    throw new DataLoadError(
      `Failed to read file: ${filePath}`,
      'ACCESS_DENIED',
      error instanceof Error ? error : undefined
    );
  }

  // Handle empty file
  if (!fileContent.trim()) {
    throw new DataLoadError(
      `File is empty: ${filePath}`,
      'INVALID_DATA'
    );
  }

  let parsedData: unknown;
  
  try {
    parsedData = JSON.parse(fileContent);
  } catch (error) {
    throw new DataLoadError(
      `Failed to parse JSON in file: ${filePath}`,
      'PARSE_ERROR',
      error instanceof Error ? error : undefined
    );
  }

  // Validate basic structure
  if (!isValidProviderUsageData(parsedData)) {
    throw new DataLoadError(
      `Invalid data structure in file: ${filePath}`,
      'INVALID_DATA'
    );
  }

  return parsedData;
}

/**
 * Type guard to validate ProviderUsageData structure
 */
function isValidProviderUsageData(data: unknown): data is ProviderUsageData {
  if (typeof data !== 'object' || data === null) {
    return false;
  }

  const d = data as Record<string, unknown>;

  // Check required top-level fields
  if (typeof d.generatedAt !== 'string') return false;
  if (typeof d.extractionVersion !== 'string') return false;
  if (!Array.isArray(d.providers)) return false;
  if (typeof d.summary !== 'object' || d.summary === null) return false;

  // Validate summary structure
  const summary = d.summary as Record<string, unknown>;
  if (typeof summary.totalTokensUsed !== 'number') return false;
  if (typeof summary.totalMessagesAnalyzed !== 'number') return false;
  if (typeof summary.providersConnected !== 'number') return false;

  // Validate each provider
  for (const provider of d.providers) {
    if (!isValidProvider(provider)) return false;
  }

  return true;
}

/**
 * Type guard to validate a single provider object
 */
function isValidProvider(provider: unknown): boolean {
  if (typeof provider !== 'object' || provider === null) {
    return false;
  }

  const p = provider as Record<string, unknown>;

  // Check required fields
  if (typeof p.provider !== 'string') return false;
  if (typeof p.displayName !== 'string') return false;
  if (typeof p.tokensUsed !== 'number') return false;
  if (typeof p.tokensInput !== 'number') return false;
  if (typeof p.tokensOutput !== 'number') return false;
  if (typeof p.tokensReasoning !== 'number') return false;
  if (typeof p.tokensCacheRead !== 'number') return false;
  if (typeof p.tokensCacheWrite !== 'number') return false;
  if (typeof p.messageCount !== 'number') return false;
  if (typeof p.partCount !== 'number') return false;
  if (p.windowType !== '5-hour' && p.windowType !== 'weekly') return false;
  if (typeof p.usagePercentageOfLimit !== 'number') return false;

  // Validate windowType-specific fields
  if (p.windowType === '5-hour' && p.rollingWindows !== undefined) {
    if (!Array.isArray(p.rollingWindows)) return false;
    for (const window of p.rollingWindows) {
      if (!isValidRollingWindow(window)) return false;
    }
  }

  return true;
}

/**
 * Type guard to validate a rolling window object
 */
function isValidRollingWindow(window: unknown): boolean {
  if (typeof window !== 'object' || window === null) {
    return false;
  }

  const w = window as Record<string, unknown>;

  if (typeof w.windowStart !== 'string') return false;
  if (typeof w.windowEnd !== 'string') return false;
  if (typeof w.tokensUsed !== 'number') return false;
  if (typeof w.percentageOfLimit !== 'number') return false;

  return true;
}

/**
 * Options for watchProviderData
 */
export interface WatchOptions {
  /** Callback when data is successfully loaded/updated */
  onData: (data: ProviderUsageData) => void;
  /** Callback when an error occurs */
  onError?: (error: DataLoadError) => void;
  /** Initial data load before watching starts */
  loadInitial?: boolean;
}

/**
 * Watch for changes to the provider data file
 * 
 * @param filePath - Path to the JSON file (defaults to DEFAULT_DATA_PATH)
 * @param options - Watch options with callbacks
 * @returns Function to stop watching
 */
export function watchProviderData(
  filePath: string = DEFAULT_DATA_PATH,
  options: WatchOptions
): () => void {
  const { onData, onError, loadInitial = true } = options;

  // Load initial data if requested
  if (loadInitial) {
    try {
      const data = loadProviderData(filePath);
      onData(data);
    } catch (error) {
      if (error instanceof DataLoadError && onError) {
        onError(error);
      } else if (error instanceof Error) {
        console.error('Unexpected error loading initial data:', error.message);
      }
    }
  }

  // Set up file watcher
  const watcher = fs.watch(filePath, (eventType) => {
    if (eventType === 'change') {
      try {
        const data = loadProviderData(filePath);
        onData(data);
      } catch (error) {
        if (error instanceof DataLoadError && onError) {
          onError(error);
        } else if (error instanceof Error) {
          console.error('Error reloading data:', error.message);
        }
      }
    }
  });

  // Return cleanup function
  return () => {
    watcher.close();
  };
}

/**
 * Create an initial dashboard state
 */
export function createInitialState(): DashboardState {
  return {
    lastLoadedAt: null,
    isLoading: false,
    error: null,
    data: null,
  };
}

/**
 * Async wrapper for loading data with loading state
 * 
 * @param filePath - Path to the JSON file
 * @returns Promise resolving to ProviderUsageData
 */
export async function loadProviderDataAsync(
  filePath: string = DEFAULT_DATA_PATH
): Promise<ProviderUsageData> {
  return new Promise((resolve, reject) => {
    try {
      const data = loadProviderData(filePath);
      resolve(data);
    } catch (error) {
      reject(error);
    }
  });
}

/**
 * Check if the data file exists and is readable
 * 
 * @param filePath - Path to check (defaults to DEFAULT_DATA_PATH)
 * @returns Object with exists flag and optional error
 */
export function checkDataFile(
  filePath: string = DEFAULT_DATA_PATH
): { exists: boolean; error?: string } {
  try {
    if (!fs.existsSync(filePath)) {
      return { exists: false, error: 'File not found' };
    }

    const stats = fs.statSync(filePath);
    if (!stats.isFile()) {
      return { exists: false, error: 'Path is not a file' };
    }

    // Try to read to verify access
    fs.accessSync(filePath, fs.constants.R_OK);

    return { exists: true };
  } catch (error) {
    return {
      exists: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

/**
 * Format file size for display
 * 
 * @param bytes - Size in bytes
 * @returns Formatted string (e.g., "1.5 KB")
 */
export function formatFileSize(bytes: number): string {
  const units = ['B', 'KB', 'MB', 'GB'];
  let size = bytes;
  let unitIndex = 0;

  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }

  return `${size.toFixed(1)} ${units[unitIndex]}`;
}

/**
 * Get file metadata for the data file
 * 
 * @param filePath - Path to the file (defaults to DEFAULT_DATA_PATH)
 * @returns File metadata or null if file doesn't exist
 */
export function getFileMetadata(
  filePath: string = DEFAULT_DATA_PATH
): { size: string; modifiedAt: Date } | null {
  try {
    const stats = fs.statSync(filePath);
    return {
      size: formatFileSize(stats.size),
      modifiedAt: stats.mtime,
    };
  } catch {
    return null;
  }
}
