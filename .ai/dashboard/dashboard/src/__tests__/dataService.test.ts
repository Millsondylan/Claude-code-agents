import { formatTokenCount, formatDate, getProviderColor, loadProviderData } from '../dataService';

describe('dataService', () => {
  describe('formatTokenCount', () => {
    it('should format billions correctly', () => {
      expect(formatTokenCount(1_500_000_000)).toBe('1.50B');
      expect(formatTokenCount(2_345_678_901)).toBe('2.35B');
    });

    it('should format millions correctly', () => {
      expect(formatTokenCount(1_500_000)).toBe('1.50M');
      expect(formatTokenCount(2_345_678)).toBe('2.35M');
    });

    it('should format thousands correctly', () => {
      expect(formatTokenCount(1_500)).toBe('1.50K');
      expect(formatTokenCount(2_345)).toBe('2.35K');
    });

    it('should return raw number for small values', () => {
      expect(formatTokenCount(999)).toBe('999');
      expect(formatTokenCount(0)).toBe('0');
    });
  });

  describe('formatDate', () => {
    it('should format date string correctly', () => {
      const result = formatDate('2026-03-08T20:12:00.289Z');
      expect(result).toContain('Mar');
      expect(result).toContain('8');
    });

    it('should handle invalid dates gracefully', () => {
      const result = formatDate('invalid-date');
      expect(result).toBe('Invalid Date');
    });
  });

  describe('getProviderColor', () => {
    it('should return correct colors for known providers', () => {
      expect(getProviderColor('anthropic')).toBe('#D4A574');
      expect(getProviderColor('kimi-for-coding')).toBe('#8B5CF6');
      expect(getProviderColor('zai-coding-plan')).toBe('#10B981');
      expect(getProviderColor('google')).toBe('#3B82F6');
      expect(getProviderColor('openai')).toBe('#10A37F');
    });

    it('should return default color for unknown providers', () => {
      expect(getProviderColor('unknown')).toBe('#6B7280');
      expect(getProviderColor('')).toBe('#6B7280');
    });
  });

  describe('loadProviderData', () => {
    it('should load provider data successfully', () => {
      const data = loadProviderData();
      expect(data).toBeDefined();
      expect(data.providers).toBeInstanceOf(Array);
      expect(data.providers.length).toBeGreaterThan(0);
      expect(data.summary).toBeDefined();
    });

    it('should have valid provider structure', () => {
      const data = loadProviderData();
      const provider = data.providers[0];
      
      expect(provider).toHaveProperty('provider');
      expect(provider).toHaveProperty('displayName');
      expect(provider).toHaveProperty('tokensUsed');
      expect(provider).toHaveProperty('windowType');
      expect(provider).toHaveProperty('usagePercentageOfLimit');
    });
  });
});
