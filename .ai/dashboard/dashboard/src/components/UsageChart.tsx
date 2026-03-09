import { 
  LineChart, 
  Line, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  Legend, 
  ResponsiveContainer,
  BarChart,
  Bar,
  Cell
} from 'recharts';
import type { ProviderData } from '../types';
import { formatTokenCount, getProviderColor } from '../dataService';

interface UsageChartProps {
  providers: ProviderData[];
}

export const UsageChart = ({ providers }: UsageChartProps) => {
  // Prepare data for time-series chart (only providers with rolling windows)
  const providersWithWindows = providers.filter(p => p.rollingWindows && p.rollingWindows.length > 0);
  
  const timeSeriesData = providersWithWindows.length > 0 && providersWithWindows[0].rollingWindows
    ? providersWithWindows[0].rollingWindows.map((window, index) => {
        const dataPoint: Record<string, number | string> = {
          time: new Date(window.windowStart).toLocaleDateString('en-US', { 
            month: 'short', 
            day: 'numeric',
            hour: '2-digit'
          }),
        };
        
        providersWithWindows.forEach(provider => {
          if (provider.rollingWindows && provider.rollingWindows[index]) {
            dataPoint[provider.provider] = provider.rollingWindows[index].tokensUsed;
          }
        });
        
        return dataPoint;
      })
    : [];

  // Prepare data for comparison bar chart
  const comparisonData = providers.map(provider => ({
    name: provider.displayName.split(' ')[0],
    fullName: provider.displayName,
    tokens: provider.tokensUsed,
    color: getProviderColor(provider.provider),
  }));

  return (
    <div className="charts-container">
      <div className="chart-wrapper">
        <h3>Provider Comparison</h3>
        <ResponsiveContainer width="100%" height={300}>
          <BarChart data={comparisonData} margin={{ top: 20, right: 30, left: 20, bottom: 5 }}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="name" />
            <YAxis tickFormatter={(value) => formatTokenCount(value)} />
            <Tooltip 
              formatter={(value) => typeof value === 'number' ? [formatTokenCount(value), 'Tokens'] : [String(value), 'Tokens']}
              labelFormatter={(label) => comparisonData.find(d => d.name === label)?.fullName || String(label)}
            />
            <Bar dataKey="tokens" fill="#8884d8">
              {comparisonData.map((entry, index) => (
                <Cell key={`cell-${index}`} fill={entry.color} />
              ))}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>

      {timeSeriesData.length > 0 && (
        <div className="chart-wrapper">
          <h3>Usage Over Time (5-hour Windows)</h3>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={timeSeriesData} margin={{ top: 20, right: 30, left: 20, bottom: 5 }}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="time" />
              <YAxis tickFormatter={(value) => formatTokenCount(value)} />
              <Tooltip formatter={(value) => typeof value === 'number' ? formatTokenCount(value) : String(value)} />
              <Legend />
              
              {providersWithWindows.map(provider => (
                <Line
                  key={provider.provider}
                  type="monotone"
                  dataKey={provider.provider}
                  stroke={getProviderColor(provider.provider)}
                  strokeWidth={2}
                  dot={false}
                  name={provider.displayName.split(' ')[0]}
                />
              ))}
            </LineChart>
          </ResponsiveContainer>
        </div>
      )}
    </div>
  );
};
