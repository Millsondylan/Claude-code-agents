import type { ProviderData } from '../types';
import { formatTokenCount, formatDate, getProviderColor } from '../dataService';

interface ProviderCardProps {
  provider: ProviderData;
}

export const ProviderCard = ({ provider }: ProviderCardProps) => {
  const color = getProviderColor(provider.provider);
  const usagePercentage = Math.min(provider.usagePercentageOfLimit, 100);
  
  return (
    <div className="provider-card" style={{ borderLeftColor: color }}>
      <div className="provider-header">
        <div className="provider-info">
          <h3 className="provider-name" style={{ color }}>{provider.displayName}</h3>
          <span className="provider-type">{provider.windowType} window</span>
        </div>
        <div className="provider-stats">
          <div className="stat">
            <span className="stat-value">{formatTokenCount(provider.tokensUsed)}</span>
            <span className="stat-label">Total Tokens</span>
          </div>
          <div className="stat">
            <span className="stat-value">{provider.messageCount.toLocaleString()}</span>
            <span className="stat-label">Messages</span>
          </div>
        </div>
      </div>

      <div className="usage-bar-container">
        <div className="usage-bar-header">
          <span>Usage vs Limit</span>
          <span className={provider.usagePercentageOfLimit > 100 ? 'usage-high' : 'usage-normal'}>
            {provider.usagePercentageOfLimit.toFixed(1)}%
          </span>
        </div>
        <div className="usage-bar">
          <div 
            className="usage-bar-fill" 
            style={{ 
              width: `${usagePercentage}%`,
              backgroundColor: provider.usagePercentageOfLimit > 100 ? '#EF4444' : color
            }}
          />
        </div>
        <div className="usage-limit">
          Limit: {formatTokenCount(provider.knownLimits.tokensPerWindow)} tokens
        </div>
      </div>

      <div className="token-breakdown">
        <div className="breakdown-item">
          <span className="breakdown-label">Input</span>
          <span className="breakdown-value">{formatTokenCount(provider.tokensInput)}</span>
        </div>
        <div className="breakdown-item">
          <span className="breakdown-label">Output</span>
          <span className="breakdown-value">{formatTokenCount(provider.tokensOutput)}</span>
        </div>
        {provider.tokensReasoning > 0 && (
          <div className="breakdown-item">
            <span className="breakdown-label">Reasoning</span>
            <span className="breakdown-value">{formatTokenCount(provider.tokensReasoning)}</span>
          </div>
        )}
        {provider.tokensCacheRead > 0 && (
          <div className="breakdown-item">
            <span className="breakdown-label">Cache Read</span>
            <span className="breakdown-value">{formatTokenCount(provider.tokensCacheRead)}</span>
          </div>
        )}
      </div>

      {provider.notes.length > 0 && (
        <div className="provider-notes">
          {provider.notes.map((note, index) => (
            <p key={index} className="note">{note}</p>
          ))}
        </div>
      )}

      <div className="time-window">
        <span>{formatDate(provider.timeWindow.start)} — {formatDate(provider.timeWindow.end)}</span>
      </div>
    </div>
  );
};
