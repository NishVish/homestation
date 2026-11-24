//+------------------------------------------------------------------+
//|                                              TrendPullbackEA.mq5 |
//|  H1 trend filter + M15 RSI pullback entries, ATR-based risk mgmt |
//|  NOTE: No EA can guarantee a fixed pips/day. Backtest and demo   |
//|  test thoroughly before using real money.                        |
//+------------------------------------------------------------------+
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

//--- inputs
input group "=== General ==="
input ulong           InpMagic        = 20260419;      // Magic number
input ENUM_TIMEFRAMES InpEntryTF      = PERIOD_M15;    // Entry timeframe
input ENUM_TIMEFRAMES InpTrendTF      = PERIOD_H1;     // Trend timeframe

input group "=== Trend filter ==="
input int             InpFastEMA      = 50;            // Fast EMA (trend TF)
input int             InpSlowEMA      = 200;           // Slow EMA (trend TF)

input group "=== Entry (pullback) ==="
input int             InpRSIPeriod    = 14;            // RSI period
input double          InpRSIBuyLevel  = 35.0;          // Buy when RSI crosses back above
input double          InpRSISellLevel = 65.0;          // Sell when RSI crosses back below

input group "=== Risk ==="
input double          InpRiskPercent  = 0.5;           // Risk per trade (% of balance)
input int             InpATRPeriod    = 14;            // ATR period
input double          InpSL_ATR       = 1.5;           // Stop loss = ATR x
input double          InpTP_ATR       = 2.25;          // Take profit = ATR x
input double          InpBE_ATR       = 1.0;           // Move SL to breakeven after ATR x profit (0=off)
input double          InpMaxSpreadPips= 2.0;           // Max spread (pips)

input group "=== Daily limits ==="
input double          InpDailyTargetPct = 1.0;         // Stop trading after +x% on the day (0=off)
input double          InpDailyLossPct   = 2.0;         // Stop trading after -x% on the day (0=off)
input int             InpMaxTradesDay   = 3;           // Max trades per day

input group "=== Session (server time) ==="
input int             InpStartHour    = 7;             // Start hour
input int             InpEndHour      = 20;            // End hour

//--- globals
CTrade   trade;
int      hFast, hSlow, hRSI, hATR;
datetime lastBar = 0;
double   pipSize;

//+------------------------------------------------------------------+
int OnInit()
{
   pipSize = (_Digits == 3 || _Digits == 5) ? _Point * 10.0 : _Point;

   hFast = iMA(_Symbol, InpTrendTF, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hSlow = iMA(_Symbol, InpTrendTF, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   hRSI  = iRSI(_Symbol, InpEntryTF, InpRSIPeriod, PRICE_CLOSE);
   hATR  = iATR(_Symbol, InpEntryTF, InpATRPeriod);

   if(hFast == INVALID_HANDLE || hSlow == INVALID_HANDLE ||
      hRSI == INVALID_HANDLE  || hATR == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles");
      return INIT_FAILED;
   }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(20);
   trade.SetTypeFillingBySymbol(_Symbol);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   IndicatorRelease(hFast);
   IndicatorRelease(hSlow);
   IndicatorRelease(hRSI);
   IndicatorRelease(hATR);
}

//+------------------------------------------------------------------+
bool GetVal(int handle, int shift, double &val)
{
   double buf[1];
   if(CopyBuffer(handle, 0, shift, 1, buf) != 1) return false;
   val = buf[0];
   return true;
}

bool HasPosition(ulong &ticket)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == (long)InpMagic)
      {
         ticket = t;
         return true;
      }
   }
   return false;
}

// Realized P/L today for this EA + number of trades opened today
void DayStats(double &pl, int &trades)
{
   pl = 0; trades = 0;
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime dayStart = StructToTime(dt);

   if(!HistorySelect(dayStart, TimeCurrent())) return;
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong d = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(d, DEAL_MAGIC) != (long)InpMagic) continue;
      if(HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
      long entry = HistoryDealGetInteger(d, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN) trades++;
      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
         pl += HistoryDealGetDouble(d, DEAL_PROFIT) +
               HistoryDealGetDouble(d, DEAL_SWAP) +
               HistoryDealGetDouble(d, DEAL_COMMISSION);
   }
}

double CalcLots(double slDistance)
{
   double risk     = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double minLot   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step     = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(tickVal <= 0 || tickSize <= 0 || slDistance <= 0) return 0;

   double lossPerLot = slDistance / tickSize * tickVal;
   double lots = risk / lossPerLot;
   lots = MathFloor(lots / step) * step;
   lots = MathMax(minLot, MathMin(maxLot, lots));
   return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
void ManageBreakeven(ulong ticket)
{
   if(InpBE_ATR <= 0) return;
   double atr;
   if(!GetVal(hATR, 1, atr)) return;
   if(!PositionSelectByTicket(ticket)) return;

   long   type  = PositionGetInteger(POSITION_TYPE);
   double open  = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl    = PositionGetDouble(POSITION_SL);
   double tp    = PositionGetDouble(POSITION_TP);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double buf   = 2 * pipSize;

   if(type == POSITION_TYPE_BUY && bid - open >= atr * InpBE_ATR && sl < open)
      trade.PositionModify(ticket, NormalizeDouble(open + buf, _Digits), tp);
   else if(type == POSITION_TYPE_SELL && open - ask >= atr * InpBE_ATR && (sl > open || sl == 0))
      trade.PositionModify(ticket, NormalizeDouble(open - buf, _Digits), tp);
}

//+------------------------------------------------------------------+
void OnTick()
{
   ulong ticket;
   if(HasPosition(ticket)) { ManageBreakeven(ticket); return; }

   // run entry logic once per new entry-TF bar
   datetime barTime = iTime(_Symbol, InpEntryTF, 0);
   if(barTime == lastBar) return;
   lastBar = barTime;

   // session filter
   MqlDateTime now; TimeToStruct(TimeCurrent(), now);
   if(now.hour < InpStartHour || now.hour >= InpEndHour) return;

   // spread filter
   double spreadPips = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) -
                        SymbolInfoDouble(_Symbol, SYMBOL_BID)) / pipSize;
   if(spreadPips > InpMaxSpreadPips) return;

   // daily limits
   double dayPL; int dayTrades;
   DayStats(dayPL, dayTrades);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(dayTrades >= InpMaxTradesDay) return;
   if(InpDailyTargetPct > 0 && dayPL >=  bal * InpDailyTargetPct / 100.0) return;
   if(InpDailyLossPct   > 0 && dayPL <= -bal * InpDailyLossPct   / 100.0) return;

   // indicators (closed bars only)
   double fast, slow, rsi1, rsi2, atr;
   if(!GetVal(hFast, 1, fast) || !GetVal(hSlow, 1, slow) ||
      !GetVal(hRSI, 1, rsi1)  || !GetVal(hRSI, 2, rsi2)  ||
      !GetVal(hATR, 1, atr)) return;

   double close1 = iClose(_Symbol, InpEntryTF, 1);
   bool upTrend   = (fast > slow) && (close1 > slow);
   bool downTrend = (fast < slow) && (close1 < slow);

   bool buySignal  = upTrend   && rsi2 < InpRSIBuyLevel  && rsi1 >= InpRSIBuyLevel;
   bool sellSignal = downTrend && rsi2 > InpRSISellLevel && rsi1 <= InpRSISellLevel;
   if(!buySignal && !sellSignal) return;

   double slDist = atr * InpSL_ATR;
   double tpDist = atr * InpTP_ATR;
   double lots   = CalcLots(slDist);
   if(lots <= 0) return;

   if(buySignal)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      trade.Buy(lots, _Symbol, ask,
                NormalizeDouble(ask - slDist, _Digits),
                NormalizeDouble(ask + tpDist, _Digits), "TPB buy");
   }
   else
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      trade.Sell(lots, _Symbol, bid,
                 NormalizeDouble(bid + slDist, _Digits),
                 NormalizeDouble(bid - tpDist, _Digits), "TPB sell");
   }
}
//+------------------------------------------------------------------+