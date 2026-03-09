export interface RollingWindow {
  windowStart: string;
  windowEnd: string;
  tokensUsed: number;
  percentageOfLimit: number;
}

export interface KnownLimits {
  tokensPerWindow: number;
}

export interface TimeWindow {
  start: string;
  end: string;
}

export interface ProviderData {
  provider: string;
  displayName: string;
  tokensUsed: number;
  tokensInput: number;
  tokensOutput: number;
  tokensReasoning: number;
  tokensCacheRead: number;
  tokensCacheWrite: number;
  messageCount: number;
  partCount: number;
  windowType: string;
  timeWindow: TimeWindow;
  knownLimits: KnownLimits;
  notes: string[];
  rollingWindows?: RollingWindow[];
  usagePercentageOfLimit: number;
}

export interface DataSource {
  databasePath: string;
  authPath: string;
  messageCount: number;
  partCount: number;
}

export interface Summary {
  totalTokensUsed: number;
  totalMessagesAnalyzed: number;
  totalPartsAnalyzed: number;
  providersConnected: number;
  providersWithUsage: number;
}

export interface ProviderUsageData {
  generatedAt: string;
  extractionVersion: string;
  dataSource: DataSource;
  providers: ProviderData[];
  summary: Summary;
}
