/**
 * Terminal Usage Dashboard - Provider Card Test
 *
 * Test file for provider card component functions.
 */

import type { ProviderUsage } from '../types';
import {
  renderProviderCard,
  renderProviderCards,
  generateProviderCard,
  formatTokenCount,
  formatMessageCount,
  getProviderStatus,
  getStatusIndicator,
  calculateProviderTimeRemaining,
  filterProvidersByWindowType,
  sortProvidersByUsage,
  sortProvidersByName,
  getProviderStatusSummary,
  generateCardTop,
  generateCardBottom,
  centerCardContent,
  leftAlignCardContent,
} from './provider-card';

/**
 * Helper to create a minimal valid ProviderUsage mock
 */
function createMockProvider(overrides: Partial<ProviderUsage> = {}): ProviderUsage {
  return {
    provider: 'test-provider',
    displayName: 'Test Provider',
    tokensUsed: 1000,
    tokensInput: 500,
    tokensOutput: 400,
    tokensReasoning: 100,
    tokensCacheRead: 0,
    tokensCacheWrite: 0,
    messageCount: 10,
    partCount: 0,
    windowType: '5-hour',
    timeWindow: { start: '2026-03-08T00:00:00Z', end: '2026-03-08T05:00:00Z' },
    knownLimits: { tokensPerWindow: 10000 },
    notes: [],
    usagePercentageOfLimit: 10,
    ...overrides,
  };
}

describe('formatTokenCount', () => {
  it('should format billions correctly', () => {
    expect(formatTokenCount(2_500_000_000)).toBe('2.5B');
  });

  it('should format millions correctly', () => {
    expect(formatTokenCount(1_500_000)).toBe('1.5M');
  });

  it('should format thousands correctly', () => {
    expect(formatTokenCount(1_500)).toBe('1.5K');
  });

  it('should return raw number for small values', () => {
    expect(formatTokenCount(500)).toBe('500');
    expect(formatTokenCount(0)).toBe('0');
  });
});

describe('formatMessageCount', () => {
  it('should format message counts with commas', () => {
    expect(formatMessageCount(500)).toBe('500');
    expect(formatMessageCount(1247)).toBe('1,247');
    expect(formatMessageCount(1_000_000)).toBe('1,000,000');
  });
});

describe('getProviderStatus', () => {
  it('should return healthy for usage < 50%', () => {
    expect(getProviderStatus(25)).toBe('healthy');
    expect(getProviderStatus(49)).toBe('healthy');
  });

  it('should return warning for usage 50-80%', () => {
    expect(getProviderStatus(50)).toBe('warning');
    expect(getProviderStatus(80)).toBe('warning');
  });

  it('should return critical for usage > 80%', () => {
    expect(getProviderStatus(81)).toBe('critical');
    expect(getProviderStatus(100)).toBe('critical');
  });
});

describe('getStatusIndicator', () => {
  it('should return colored indicator for each status', () => {
    expect(getStatusIndicator('healthy')).toContain('●');
    expect(getStatusIndicator('warning')).toContain('●');
    expect(getStatusIndicator('critical')).toContain('●');
    expect(getStatusIndicator('expired')).toContain('●');
  });
});

describe('filterProvidersByWindowType', () => {
  const mockProviders: ProviderUsage[] = [
    createMockProvider({ provider: 'test-5h', displayName: 'Test 5h', windowType: '5-hour' }),
    createMockProvider({ provider: 'test-weekly', displayName: 'Test Weekly', windowType: 'weekly' }),
  ];

  it('should filter 5-hour providers', () => {
    const result = filterProvidersByWindowType(mockProviders, '5-hour');
    expect(result).toHaveLength(1);
    expect(result[0].provider).toBe('test-5h');
  });

  it('should filter weekly providers', () => {
    const result = filterProvidersByWindowType(mockProviders, 'weekly');
    expect(result).toHaveLength(1);
    expect(result[0].provider).toBe('test-weekly');
  });
});

describe('sortProvidersByUsage', () => {
  const mockProviders: ProviderUsage[] = [
    createMockProvider({ provider: 'a', displayName: 'A', usagePercentageOfLimit: 30 }),
    createMockProvider({ provider: 'b', displayName: 'B', usagePercentageOfLimit: 80 }),
    createMockProvider({ provider: 'c', displayName: 'C', usagePercentageOfLimit: 50 }),
  ];

  it('should sort providers by usage percentage (highest first)', () => {
    const result = sortProvidersByUsage(mockProviders);
    expect(result[0].provider).toBe('b');
    expect(result[1].provider).toBe('c');
    expect(result[2].provider).toBe('a');
  });
});

describe('sortProvidersByName', () => {
  const mockProviders: ProviderUsage[] = [
    createMockProvider({ provider: 'c', displayName: 'Charlie' }),
    createMockProvider({ provider: 'a', displayName: 'Alpha' }),
    createMockProvider({ provider: 'b', displayName: 'Bravo' }),
  ];

  it('should sort providers by display name alphabetically', () => {
    const result = sortProvidersByName(mockProviders);
    expect(result[0].displayName).toBe('Alpha');
    expect(result[1].displayName).toBe('Bravo');
    expect(result[2].displayName).toBe('Charlie');
  });
});

describe('getProviderStatusSummary', () => {
  const mockProvider = createMockProvider({
    displayName: 'Test Provider',
    usagePercentageOfLimit: 65.5,
  });

  it('should return status summary with indicator and percentage', () => {
    const result = getProviderStatusSummary(mockProvider);
    expect(result).toContain('Test Provider');
    expect(result).toContain('65.5%');
  });
});

describe('generateCardTop', () => {
  it('should generate top border with provider name', () => {
    const result = generateCardTop('Test Provider');
    expect(result).toContain('Test Provider');
    expect(result.startsWith('┌')).toBe(true);
    expect(result.endsWith('┐')).toBe(true);
  });

  it('should truncate long names', () => {
    const longName = 'A'.repeat(100);
    const result = generateCardTop(longName);
    expect(result.length).toBeLessThanOrEqual(52); // Allow for border chars
  });
});

describe('generateCardBottom', () => {
  it('should generate bottom border', () => {
    const result = generateCardBottom();
    expect(result.startsWith('└')).toBe(true);
    expect(result.endsWith('┘')).toBe(true);
  });
});

describe('centerCardContent', () => {
  it('should center content within card width', () => {
    const result = centerCardContent('Test');
    expect(result).toContain('Test');
    expect(result.startsWith('│')).toBe(true);
    expect(result.endsWith('│')).toBe(true);
  });
});

describe('leftAlignCardContent', () => {
  it('should left-align content within card width', () => {
    const result = leftAlignCardContent('Test');
    expect(result).toContain('Test');
    expect(result.startsWith('│')).toBe(true);
    expect(result.endsWith('│')).toBe(true);
  });
});

describe('generateProviderCard', () => {
  const mockProvider = createMockProvider({
    displayName: 'Test Provider',
    usagePercentageOfLimit: 50,
  });

  it('should generate an array of card lines', () => {
    const result = generateProviderCard(mockProvider);
    expect(Array.isArray(result)).toBe(true);
    expect(result.length).toBeGreaterThanOrEqual(4);
  });

  it('should include top border with provider name', () => {
    const result = generateProviderCard(mockProvider);
    expect(result[0]).toContain('Test Provider');
  });

  it('should include progress information', () => {
    const result = generateProviderCard(mockProvider);
    const progressLine = result.find(line => line.includes('50.0%'));
    expect(progressLine).toBeDefined();
  });
});

describe('renderProviderCard', () => {
  const mockProvider = createMockProvider({
    displayName: 'Test Provider',
  });

  it('should render card as a string with newlines', () => {
    const result = renderProviderCard(mockProvider);
    expect(typeof result).toBe('string');
    expect(result).toContain('\n');
    expect(result).toContain('Test Provider');
  });
});

describe('renderProviderCards', () => {
  const mockProviders: ProviderUsage[] = [
    createMockProvider({ provider: 'test1', displayName: 'Test 1' }),
    createMockProvider({ provider: 'test2', displayName: 'Test 2', windowType: 'weekly' }),
  ];

  it('should render multiple cards with spacing', () => {
    const result = renderProviderCards(mockProviders);
    expect(typeof result).toBe('string');
    expect(result).toContain('Test 1');
    expect(result).toContain('Test 2');
  });

  it('should return message for empty providers', () => {
    const result = renderProviderCards([]);
    expect(result).toBe('No providers to display.');
  });
});

describe('calculateProviderTimeRemaining', () => {
  it('should calculate time for 5-hour window', () => {
    const provider = createMockProvider({ windowType: '5-hour' });
    const result = calculateProviderTimeRemaining(provider);
    expect(result).toBeDefined();
    expect(result).toHaveProperty('formatted');
  });

  it('should calculate time for weekly window', () => {
    const provider = createMockProvider({ windowType: 'weekly' });
    const result = calculateProviderTimeRemaining(provider);
    expect(result).toBeDefined();
    expect(result).toHaveProperty('formatted');
  });
});
