import type { ProviderUsageData } from './types';

// In production, this would fetch from an API endpoint
// For now, we'll import the JSON directly
import usageData from './data/provider-usage-data.json';

export const loadProviderData = (): ProviderUsageData => {
  return usageData as ProviderUsageData;
};

export const formatTokenCount = (count: number): string => {
  if (count >= 1_000_000_000) {
    return `${(count / 1_000_000_000).toFixed(2)}B`;
  }
  if (count >= 1_000_000) {
    return `${(count / 1_000_000).toFixed(2)}M`;
  }
  if (count >= 1_000) {
    return `${(count / 1_000).toFixed(2)}K`;
  }
  return count.toString();
};

export const formatDate = (dateString: string): string => {
  return new Date(dateString).toLocaleString('en-US', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};

export const getProviderColor = (provider: string): string => {
  const colors: Record<string, string> = {
    anthropic: '#D4A574',
    'kimi-for-coding': '#8B5CF6',
    'zai-coding-plan': '#10B981',
    google: '#3B82F6',
    openai: '#10A37F',
  };
  return colors[provider] || '#6B7280';
};
