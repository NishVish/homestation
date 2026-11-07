import pandas as pd
import numpy as np

class NiftyBeesTradingBot:
    def __init__(self, initial_capital=10000.0, risk_per_trade_pct=0.02):
        self.initial_capital = initial_capital
        self.capital = initial_capital
        self.risk_pct = risk_per_trade_pct  # Set to 2.0% risk
        
        self.position = 0          # 0: Flat, 1: Long
        self.entry_price = 0.0
        self.shares = 0
        self.highest_price = 0.0
        self.bars_in_trade = 0
        self.trade_log = []

    def calculate_indicators(self, df):
        # Calculate Average True Range (ATR)
        tr = np.maximum(
            df['High'] - df['Low'],
            np.maximum(
                abs(df['High'] - df['Close'].shift(1)),
                abs(df['Low'] - df['Close'].shift(1))
            )
        )
        df['ATR'] = tr.rolling(window=10).mean().bfill()
        
        # Calculate Exponential Moving Averages (EMAs)
        df['EMA_Fast'] = df['Close'].ewm(span=3, adjust=False).mean()
        df['EMA_Slow'] = df['Close'].ewm(span=8, adjust=False).mean()
        df['EMA_Macro'] = df['Close'].ewm(span=15, adjust=False).mean()
        return df

    def run_backtest(self, df):
        df = self.calculate_indicators(df)
        
        for i in range(1, len(df)):
            c = df['Close'].iloc[i]
            h = df['High'].iloc[i]
            l = df['Low'].iloc[i]
            atr = df['ATR'].iloc[i]
            
            fast_c, slow_c = df['EMA_Fast'].iloc[i], df['EMA_Slow'].iloc[i]
            fast_p, slow_p = df['EMA_Fast'].iloc[i-1], df['EMA_Slow'].iloc[i-1]
            macro_ema = df['EMA_Macro'].iloc[i]

            # --- EXIT LOGIC (WHEN IN POSITION) ---
            if self.position == 1:
                self.bars_in_trade += 1
                self.highest_price = max(self.highest_price, h)
                unrealized_profit = self.highest_price - self.entry_price
                
                # Dynamic Trailing Stop-Loss (2.0 * ATR)
                sl = self.highest_price - (2.0 * atr)
                
                # Lock-in breakeven + buffer if trade moves 1 ATR in favor
                if unrealized_profit >= (1.0 * atr):
                    sl = max(sl, self.entry_price + (0.05 * atr))

                # Exit conditions
                is_stale = (self.bars_in_trade >= 8) and ((c - self.entry_price) < (0.3 * atr))
                is_sl_hit = (c <= sl)
                is_reversal = (fast_p > slow_p and fast_c < slow_c)

                if is_stale or is_sl_hit or is_reversal:
                    pnl = (c - self.entry_price) * self.shares
                    self.capital += pnl  # Dynamic capital compounding update
                    
                    reason = 'STALE' if is_stale else ('SL' if is_sl_hit else 'REVERSAL')
                    self.trade_log.append({
                        'date': df.index[i] if hasattr(df.index[i], 'strftime') else i,
                        'type': 'EXIT',
                        'exit_price': round(c, 2),
                        'pnl': round(pnl, 2),
                        'reason': reason,
                        'new_balance': round(self.capital, 2)
                    })
                    self.position = 0

            # --- ENTRY LOGIC (WHEN FLAT) ---
            if self.position == 0:
                self.bars_in_trade = 0
                
                # Bullish EMA Crossover above Macro Trend Filter
                if (fast_p <= slow_p and fast_c > slow_c) and (c > macro_ema):
                    # Risk calculation based on current updated capital balance
                    risk_amount = self.capital * self.risk_pct
                    sl_distance = 2.0 * atr
                    
                    if sl_distance > 0:
                        self.shares = int(risk_amount // sl_distance)
                        
                        # Verify capital sufficiency
                        if self.shares * c <= self.capital and self.shares > 0:
                            self.position = 1
                            self.entry_price = c
                            self.highest_price = h
                            self.trade_log.append({
                                'date': df.index[i] if hasattr(df.index[i], 'strftime') else i,
                                'type': 'ENTRY',
                                'entry_price': round(c, 2),
                                'shares': self.shares
                            })

        return self.capital, pd.DataFrame(self.trade_log)

# --- EXECUTION EXAMPLE ---
if __name__ == "__main__":
    # Generating sample price movement for testing
    np.random.seed(42)
    n_days = 60
    prices = 285.50 + np.cumsum(np.random.normal(0.2, 0.5, n_days))
    
    df_market = pd.DataFrame({
        'Close': prices,
        'Open': pd.Series(prices).shift(1).fillna(285.50),
        'High': prices + np.abs(np.random.normal(0.4, 0.1, n_days)),
        'Low': prices - np.abs(np.random.normal(0.4, 0.1, n_days))
    }, index=pd.date_range(start="2026-08-01", periods=n_days, freq="B"))

    # Initialize bot with ₹10,000 capital and 2% risk rule
    bot = NiftyBeesTradingBot(initial_capital=10000.0, risk_per_trade_pct=0.02)
    final_balance, log_df = bot.run_backtest(df_market)
    
    print(f"Initial Capital: ₹10,000.00")
    print(f"Final Balance:   ₹{final_balance:,.2f}")
    print(f"Net Return:      {((final_balance - 10000) / 10000) * 100:.2f}%\n")
    print("--- Trade Log Summary ---")
    print(log_df.to_markdown(index=False) if not log_df.empty else "No trades executed in this sample window.")