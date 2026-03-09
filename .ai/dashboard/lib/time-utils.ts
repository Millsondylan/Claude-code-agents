/**
 * Terminal Usage Dashboard - Time Utilities
 * 
 * Time calculation utilities for the dashboard.
 * Handles 5-hour window resets, weekly quota resets, and duration formatting.
 */

import type { TimeRemaining } from '../types';

/**
 * Parse an ISO 8601 timestamp string to a Date object
 * 
 * @param timestamp - ISO 8601 timestamp (e.g., "2026-03-08T20:12:00.289Z")
 * @returns Date object
 * @throws Error if timestamp is invalid
 */
export function parseISOTimestamp(timestamp: string): Date {
  const date = new Date(timestamp);
  if (isNaN(date.getTime())) {
    throw new Error(`Invalid ISO timestamp: ${timestamp}`);
  }
  return date;
}

/**
 * Calculate time remaining until the next 5-hour window reset
 * Rolling windows reset every 5 hours from a base time.
 * 
 * @param fromDate - Date to calculate from (defaults to now)
 * @param baseTime - Optional base time to align windows to (defaults to Unix epoch)
 * @returns TimeRemaining object with formatted display
 */
export function calculateTimeUntil5HourReset(
  fromDate: Date = new Date(),
  baseTime: Date = new Date(0)
): TimeRemaining {
  const FIVE_HOURS_MS = 5 * 60 * 60 * 1000; // 18,000,000 ms
  
  // Calculate time since base
  const timeSinceBase = fromDate.getTime() - baseTime.getTime();
  
  // Find the next 5-hour boundary
  const windowsPassed = Math.floor(timeSinceBase / FIVE_HOURS_MS);
  const nextWindowStart = (windowsPassed + 1) * FIVE_HOURS_MS + baseTime.getTime();
  
  const totalMs = nextWindowStart - fromDate.getTime();
  
  return createTimeRemaining(totalMs);
}

/**
 * Calculate time remaining until Sunday (weekly quota reset)
 * Weekly quotas reset at midnight on Sunday.
 * 
 * @param fromDate - Date to calculate from (defaults to now)
 * @returns TimeRemaining object with formatted display
 */
export function calculateTimeUntilSunday(fromDate: Date = new Date()): TimeRemaining {
  // Get the current day (0 = Sunday, 1 = Monday, etc.)
  const currentDay = fromDate.getDay();
  const currentHour = fromDate.getHours();
  const currentMinute = fromDate.getMinutes();
  const currentSecond = fromDate.getSeconds();
  const currentMs = fromDate.getMilliseconds();
  
  // Days until next Sunday
  const daysUntilSunday = currentDay === 0 ? 7 : 7 - currentDay;
  
  // Calculate milliseconds until next Sunday at midnight
  const msUntilSunday = (
    daysUntilSunday * 24 * 60 * 60 * 1000 -
    currentHour * 60 * 60 * 1000 -
    currentMinute * 60 * 1000 -
    currentSecond * 1000 -
    currentMs
  );
  
  return createTimeRemaining(msUntilSunday);
}

/**
 * Create a TimeRemaining object from milliseconds
 * 
 * @param totalMs - Total milliseconds remaining
 * @returns TimeRemaining object
 */
function createTimeRemaining(totalMs: number): TimeRemaining {
  const isExpired = totalMs <= 0;
  const absMs = Math.abs(totalMs);
  
  const hours = Math.floor(absMs / (60 * 60 * 1000));
  const remainingAfterHours = absMs % (60 * 60 * 1000);
  const minutes = Math.floor(remainingAfterHours / (60 * 1000));
  const remainingAfterMinutes = remainingAfterHours % (60 * 1000);
  const seconds = Math.floor(remainingAfterMinutes / 1000);
  
  return {
    totalMs,
    hours,
    minutes,
    seconds,
    isExpired,
    formatted: formatDuration(totalMs),
  };
}

/**
 * Format a duration in milliseconds to a human-readable string
 * 
 * - Over 1 hour: "Xh Ym" (e.g., "2h 15m")
 * - Under 1 hour: "Xm Ys" (e.g., "45m 30s")
 * - Under 1 minute: "Xs" (e.g., "45s")
 * - Zero or negative: "0s"
 * 
 * @param durationMs - Duration in milliseconds
 * @returns Formatted string
 */
export function formatDuration(durationMs: number): string {
  if (durationMs <= 0) {
    return '0s';
  }
  
  const hours = Math.floor(durationMs / (60 * 60 * 1000));
  const remainingAfterHours = durationMs % (60 * 60 * 1000);
  const minutes = Math.floor(remainingAfterHours / (60 * 1000));
  const remainingAfterMinutes = remainingAfterHours % (60 * 1000);
  const seconds = Math.floor(remainingAfterMinutes / 1000);
  
  if (hours > 0) {
    return `${hours}h ${minutes}m`;
  } else if (minutes > 0) {
    return `${minutes}m ${seconds}s`;
  } else {
    return `${seconds}s`;
  }
}

/**
 * Format a duration in milliseconds to a detailed string with all components
 * 
 * @param durationMs - Duration in milliseconds
 * @returns Formatted string (e.g., "2h 15m 30s")
 */
export function formatDurationDetailed(durationMs: number): string {
  if (durationMs <= 0) {
    return '0s';
  }
  
  const hours = Math.floor(durationMs / (60 * 60 * 1000));
  const remainingAfterHours = durationMs % (60 * 60 * 1000);
  const minutes = Math.floor(remainingAfterHours / (60 * 1000));
  const remainingAfterMinutes = remainingAfterHours % (60 * 1000);
  const seconds = Math.floor(remainingAfterMinutes / 1000);
  
  const parts: string[] = [];
  if (hours > 0) parts.push(`${hours}h`);
  if (minutes > 0 || hours > 0) parts.push(`${minutes}m`);
  parts.push(`${seconds}s`);
  
  return parts.join(' ');
}

/**
 * Convert a date to a different timezone
 * Returns a new Date object adjusted to the target timezone
 * 
 * @param date - Date to convert
 * @param timezone - Target timezone (e.g., 'America/New_York', 'UTC')
 * @returns Date object in the target timezone
 */
export function convertToTimezone(date: Date, timezone: string): Date {
  try {
    const formatter = new Intl.DateTimeFormat('en-US', {
      timeZone: timezone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: false,
    });
    
    const parts = formatter.formatToParts(date);
    const partMap = new Map(parts.map(p => [p.type, p.value]));
    
    const year = parseInt(partMap.get('year') || '0', 10);
    const month = parseInt(partMap.get('month') || '1', 10) - 1; // Month is 0-indexed
    const day = parseInt(partMap.get('day') || '1', 10);
    const hour = parseInt(partMap.get('hour') || '0', 10);
    const minute = parseInt(partMap.get('minute') || '0', 10);
    const second = parseInt(partMap.get('second') || '0', 10);
    
    return new Date(year, month, day, hour, minute, second);
  } catch {
    // If timezone is invalid, return the original date
    return new Date(date);
  }
}

/**
 * Get the local timezone name
 * 
 * @returns Timezone string (e.g., 'America/New_York')
 */
export function getLocalTimezone(): string {
  return Intl.DateTimeFormat().resolvedOptions().timeZone;
}

/**
 * Check if a date is in daylight saving time
 * 
 * @param date - Date to check
 * @returns True if date is in DST
 */
export function isDaylightSavingTime(date: Date = new Date()): boolean {
  const jan = new Date(date.getFullYear(), 0, 1);
  const jul = new Date(date.getFullYear(), 6, 1);
  const stdTimezoneOffset = Math.max(jan.getTimezoneOffset(), jul.getTimezoneOffset());
  return date.getTimezoneOffset() < stdTimezoneOffset;
}

/**
 * Calculate the time elapsed since a given timestamp
 * 
 * @param timestamp - ISO 8601 timestamp
 * @returns TimeRemaining object
 */
export function calculateElapsedTime(timestamp: string): TimeRemaining {
  const date = parseISOTimestamp(timestamp);
  const now = new Date();
  const elapsedMs = now.getTime() - date.getTime();
  
  return createTimeRemaining(elapsedMs);
}

/**
 * Format a date for display in the dashboard
 * 
 * @param date - Date to format
 * @param includeTime - Whether to include time
 * @returns Formatted string (e.g., "Mar 8, 2026" or "Mar 8, 2026 8:12 PM")
 */
export function formatDateForDisplay(date: Date, includeTime: boolean = false): string {
  const options: Intl.DateTimeFormatOptions = {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  };
  
  if (includeTime) {
    options.hour = 'numeric';
    options.minute = '2-digit';
  }
  
  return date.toLocaleDateString('en-US', options);
}

/**
 * Format an ISO timestamp for display
 * 
 * @param timestamp - ISO 8601 timestamp
 * @param includeTime - Whether to include time
 * @returns Formatted string
 */
export function formatTimestampForDisplay(timestamp: string, includeTime: boolean = false): string {
  const date = parseISOTimestamp(timestamp);
  return formatDateForDisplay(date, includeTime);
}
