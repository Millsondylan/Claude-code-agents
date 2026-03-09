import type { ProviderData } from '../types';

describe('types', () => {
  it('should have valid ProviderData structure', () => {
    const mockProvider: ProviderData = {
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
      timeWindow: {
        start: '2026-03-08T00:00:00Z',
        end: '2026-03-08T05:00:00Z',
      },
      knownLimits: {
        tokensPerWindow: 10000,
      },
      notes: ['Test note'],
      rollingWindows: [
        {
          windowStart: '2026-03-08T00:00:00Z',
          windowEnd: '2026-03-08T05:00:00Z',
          tokensUsed: 1000,
          percentageOfLimit: 10,
        },
      ],
      usagePercentageOfLimit: 10,
    };

    expect(mockProvider.provider).toBe('test-provider');
    expect(mockProvider.tokensUsed).toBe(1000);
    expect(mockProvider.windowType).toBe('5-hour');
    expect(mockProvider.usagePercentageOfLimit).toBe(10);
  });
});
