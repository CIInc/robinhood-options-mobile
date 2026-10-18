export interface WhaleWatchTransaction {
  symbol: string;
  filerName: string;
  filerRelation: string;
  transactionText: string;
  shares: number | string;
  value: number;
  date: string; // ISO string
  ownership: "D" | "I" | string;
  isBuy: boolean;
  isSale: boolean;
  isOptionExercise: boolean;
}

export interface InstitutionalAccumulation {
  symbol: string;
  institutionName: string;
  sharesHeld: number;
  changeInShares: number;
  percentChange: number;
  positionValue: number;
  reportDate: string;
}

export interface WhaleWatchAggregate {
  buyTotal: number;
  sellTotal: number;
  buyCount: number;
  sellCount: number;
  topAccumulatedSymbols: { symbol: string; score: number }[];
  recentLargeTransactions: WhaleWatchTransaction[];
  timestamp: string;
}
