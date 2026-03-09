import { useState, useEffect } from 'react';
import { ProviderCard } from './components/ProviderCard';
import { UsageChart } from './components/UsageChart';
import { loadProviderData, formatTokenCount, formatDate } from './dataService';
import type { ProviderUsageData } from './types';
import './App.css';

function App() {
  const [data, setData] = useState<ProviderUsageData | null>(null);
  const [loading, setLoading] = useState(true);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);

  useEffect(() => {
    const fetchData = () => {
      const usageData = loadProviderData();
      setData(usageData);
      setLastUpdated(new Date());
      setLoading(false);
    };

    fetchData();

    // Auto-refresh every 5 minutes
    const interval = setInterval(fetchData, 5 * 60 * 1000);
    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return (
      <div className="loading">
        <div className="loading-spinner"></div>
        <p>Loading provider usage data...</p>
      </div>
    );
  }

  if (!data) {
    return (
      <div className="error">
        <h2>Error Loading Data</h2>
        <p>Could not load provider usage data. Please try again later.</p>
      </div>
    );
  }

  return (
    <div className="dashboard">
      <header className="dashboard-header">
        <div className="header-content">
          <h1>🔌 Provider Usage Dashboard</h1>
          <div className="header-meta">
            {lastUpdated && (
              <span className="last-updated">
                Last updated: {formatDate(lastUpdated.toISOString())}
              </span>
            )}
            <span className="version">
              v{data.extractionVersion}
            </span>
          </div>
        </div>
      </header>

      <section className="summary-section">
        <div className="summary-cards">
          <div className="summary-card total-tokens">
            <div className="summary-value">{formatTokenCount(data.summary.totalTokensUsed)}</div>
            <div className="summary-label">Total Tokens</div>
          </div>
          <div className="summary-card messages">
            <div className="summary-value">{data.summary.totalMessagesAnalyzed.toLocaleString()}</div>
            <div className="summary-label">Messages Analyzed</div>
          </div>
          <div className="summary-card providers">
            <div className="summary-value">{data.summary.providersConnected}</div>
            <div className="summary-label">Providers Connected</div>
          </div>
          <div className="summary-card active">
            <div className="summary-value">{data.summary.providersWithUsage}</div>
            <div className="summary-label">Active Providers</div>
          </div>
        </div>
      </section>

      <section className="charts-section">
        <UsageChart providers={data.providers} />
      </section>

      <section className="providers-section">
        <h2>Provider Details</h2>
        <div className="providers-grid">
          {data.providers.map(provider => (
            <ProviderCard key={provider.provider} provider={provider} />
          ))}
        </div>
      </section>

      <footer className="dashboard-footer">
        <p>
          Data extracted from: <code>{data.dataSource.databasePath}</code>
        </p>
        <p>
          Generated: {new Date(data.generatedAt).toLocaleString()}
        </p>
      </footer>
    </div>
  );
}

export default App;
