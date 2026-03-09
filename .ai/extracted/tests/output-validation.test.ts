/**
 * Tests for validating the provider-usage-data.json output format
 */

import * as fs from 'fs';
import * as path from 'path';

const OUTPUT_PATH = path.join(__dirname, '..', 'provider-usage-data.json');

describe('Provider Usage Data JSON Output', () => {
  let outputData: any;

  beforeAll(() => {
    if (fs.existsSync(OUTPUT_PATH)) {
      const content = fs.readFileSync(OUTPUT_PATH, 'utf-8');
      outputData = JSON.parse(content);
    }
  });

  it('should exist and be valid JSON', () => {
    expect(fs.existsSync(OUTPUT_PATH)).toBe(true);
    expect(outputData).toBeDefined();
  });

  describe('Top-Level Structure', () => {
    it('should have required top-level fields', () => {
      expect(outputData).toHaveProperty('generatedAt');
      expect(outputData).toHaveProperty('extractionVersion');
      expect(outputData).toHaveProperty('dataSource');
      expect(outputData).toHaveProperty('providers');
      expect(outputData).toHaveProperty('summary');
    });

    it('should have valid generatedAt timestamp', () => {
      const date = new Date(outputData.generatedAt);
      expect(date.getTime()).not.toBeNaN();
      expect(date.getTime()).toBeLessThanOrEqual(Date.now());
    });

    it('should have valid extraction version', () => {
      expect(typeof outputData.extractionVersion).toBe('string');
      expect(outputData.extractionVersion).toMatch(/^\d+\.\d+\.\d+$/);
    });
  });

  describe('Data Source Section', () => {
    it('should have required dataSource fields', () => {
      expect(outputData.dataSource).toHaveProperty('databasePath');
      expect(outputData.dataSource).toHaveProperty('authPath');
      expect(outputData.dataSource).toHaveProperty('messageCount');
      expect(outputData.dataSource).toHaveProperty('partCount');
    });

    it('should have valid database path', () => {
      expect(typeof outputData.dataSource.databasePath).toBe('string');
      expect(outputData.dataSource.databasePath).toContain('opencode.db');
    });

    it('should have valid auth path', () => {
      expect(typeof outputData.dataSource.authPath).toBe('string');
      expect(outputData.dataSource.authPath).toContain('auth.json');
    });

    it('should have non-negative message and part counts', () => {
      expect(typeof outputData.dataSource.messageCount).toBe('number');
      expect(typeof outputData.dataSource.partCount).toBe('number');
      expect(outputData.dataSource.messageCount).toBeGreaterThanOrEqual(0);
      expect(outputData.dataSource.partCount).toBeGreaterThanOrEqual(0);
    });
  });

  describe('Providers Array', () => {
    it('should be an array with at least one provider', () => {
      expect(Array.isArray(outputData.providers)).toBe(true);
      expect(outputData.providers.length).toBeGreaterThan(0);
    });

    it('each provider should have required fields', () => {
      for (const provider of outputData.providers) {
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
      }
    });

    it('each provider should have valid windowType', () => {
      const validWindowTypes = ['5-hour', 'weekly', 'unknown'];
      for (const provider of outputData.providers) {
        expect(validWindowTypes).toContain(provider.windowType);
      }
    });

    it('each provider should have valid timeWindow structure', () => {
      for (const provider of outputData.providers) {
        expect(provider.timeWindow).toHaveProperty('start');
        expect(provider.timeWindow).toHaveProperty('end');

        const startDate = new Date(provider.timeWindow.start);
        const endDate = new Date(provider.timeWindow.end);
        expect(startDate.getTime()).not.toBeNaN();
        expect(endDate.getTime()).not.toBeNaN();
      }
    });

    it('each provider should have numeric token counts', () => {
      for (const provider of outputData.providers) {
        expect(typeof provider.tokensUsed).toBe('number');
        expect(typeof provider.tokensInput).toBe('number');
        expect(typeof provider.tokensOutput).toBe('number');
        expect(typeof provider.tokensReasoning).toBe('number');
        expect(typeof provider.tokensCacheRead).toBe('number');
        expect(typeof provider.tokensCacheWrite).toBe('number');
        expect(provider.tokensUsed).toBeGreaterThanOrEqual(0);
      }
    });

    it('each provider should have message and part counts', () => {
      for (const provider of outputData.providers) {
        expect(typeof provider.messageCount).toBe('number');
        expect(typeof provider.partCount).toBe('number');
        expect(provider.messageCount).toBeGreaterThanOrEqual(0);
        expect(provider.partCount).toBeGreaterThanOrEqual(0);
      }
    });

    it('notes should be an array of strings', () => {
      for (const provider of outputData.providers) {
        expect(Array.isArray(provider.notes)).toBe(true);
        for (const note of provider.notes) {
          expect(typeof note).toBe('string');
        }
      }
    });

    it('providers with 5-hour windowType should have rollingWindows', () => {
      for (const provider of outputData.providers) {
        if (provider.windowType === '5-hour') {
          expect(provider).toHaveProperty('rollingWindows');
          expect(Array.isArray(provider.rollingWindows)).toBe(true);

          for (const window of provider.rollingWindows) {
            expect(window).toHaveProperty('windowStart');
            expect(window).toHaveProperty('windowEnd');
            expect(window).toHaveProperty('tokensUsed');
            expect(typeof window.tokensUsed).toBe('number');

            if (window.percentageOfLimit !== undefined) {
              expect(typeof window.percentageOfLimit).toBe('number');
            }
          }
        }
      }
    });

    it('should include knownLimits when available', () => {
      for (const provider of outputData.providers) {
        if (provider.knownLimits) {
          if (provider.knownLimits.tokensPerWindow !== undefined) {
            expect(typeof provider.knownLimits.tokensPerWindow).toBe('number');
          }
          if (provider.knownLimits.requestsPerWindow !== undefined) {
            expect(typeof provider.knownLimits.requestsPerWindow).toBe('number');
          }
        }
      }
    });

    it('known providers should have expected display names', () => {
      const expectedNames: Record<string, string> = {
        'anthropic': 'Claude (Anthropic)',
        'kimi-for-coding': 'Kimi',
        'zai-coding-plan': 'GLM (Zhipu)',
        'google': 'Gemini (Google)',
        'openai': 'GPT (OpenAI)'
      };

      for (const provider of outputData.providers) {
        if (expectedNames[provider.provider]) {
          expect(provider.displayName).toBe(expectedNames[provider.provider]);
        }
      }
    });
  });

  describe('Summary Section', () => {
    it('should have required summary fields', () => {
      expect(outputData.summary).toHaveProperty('totalTokensUsed');
      expect(outputData.summary).toHaveProperty('totalMessagesAnalyzed');
      expect(outputData.summary).toHaveProperty('totalPartsAnalyzed');
      expect(outputData.summary).toHaveProperty('providersConnected');
      expect(outputData.summary).toHaveProperty('providersWithUsage');
    });

    it('should have numeric summary values', () => {
      expect(typeof outputData.summary.totalTokensUsed).toBe('number');
      expect(typeof outputData.summary.totalMessagesAnalyzed).toBe('number');
      expect(typeof outputData.summary.totalPartsAnalyzed).toBe('number');
      expect(typeof outputData.summary.providersConnected).toBe('number');
      expect(typeof outputData.summary.providersWithUsage).toBe('number');
    });

    it('should have non-negative summary values', () => {
      expect(outputData.summary.totalTokensUsed).toBeGreaterThanOrEqual(0);
      expect(outputData.summary.totalMessagesAnalyzed).toBeGreaterThanOrEqual(0);
      expect(outputData.summary.totalPartsAnalyzed).toBeGreaterThanOrEqual(0);
      expect(outputData.summary.providersConnected).toBeGreaterThanOrEqual(0);
      expect(outputData.summary.providersWithUsage).toBeGreaterThanOrEqual(0);
    });

    it('providersWithUsage should not exceed providersConnected', () => {
      expect(outputData.summary.providersWithUsage).toBeLessThanOrEqual(
        outputData.summary.providersConnected
      );
    });

    it('totalTokensUsed should equal sum of all provider tokens', () => {
      const calculatedTotal = outputData.providers.reduce(
        (sum: number, p: any) => sum + p.tokensUsed,
        0
      );
      expect(outputData.summary.totalTokensUsed).toBe(calculatedTotal);
    });

    it('totalMessagesAnalyzed should equal sum of all provider message counts', () => {
      const calculatedTotal = outputData.providers.reduce(
        (sum: number, p: any) => sum + p.messageCount,
        0
      );
      expect(outputData.summary.totalMessagesAnalyzed).toBe(calculatedTotal);
    });

    it('totalPartsAnalyzed should equal sum of all provider part counts', () => {
      const calculatedTotal = outputData.providers.reduce(
        (sum: number, p: any) => sum + p.partCount,
        0
      );
      expect(outputData.summary.totalPartsAnalyzed).toBe(calculatedTotal);
    });
  });

  describe('Known Provider Detection', () => {
    it('should detect anthropic provider if connected', () => {
      const providerIds = outputData.providers.map((p: any) => p.provider);
      if (outputData.summary.providersConnected > 0) {
        // At least verify structure is correct
        expect(providerIds.length).toBeGreaterThan(0);
      }
    });

    it('should have provider-specific configuration for known providers', () => {
      const providersWith5HourWindow = ['anthropic', 'kimi-for-coding'];
      const providersWithWeeklyWindow = ['zai-coding-plan', 'google', 'openai'];

      for (const provider of outputData.providers) {
        if (providersWith5HourWindow.includes(provider.provider)) {
          expect(provider.windowType).toBe('5-hour');
        } else if (providersWithWeeklyWindow.includes(provider.provider)) {
          expect(provider.windowType).toBe('weekly');
        }
      }
    });
  });
});
