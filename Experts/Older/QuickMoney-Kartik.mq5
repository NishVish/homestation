//+------------------------------------------------------------------+
//| Last Candle Direction EA - MQL5                                  |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>

CTrade trade;

input double Lots            = 0.10;
input int    StopLossPips    = 20;
input int    TakeProfitPips  = 40;   // 1:2
input int    TrailingPips    = 20;
input ulong  MagicNumber     = 20260911;

double Pip()
{
   if(_Digits == 3 || _Digits == 5)
      return _Point * 10.0;

   return _Point;
}

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(20);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{
   ManageTrailing();

   if(PositionSelect(_Symbol))
      return;

   OpenByLastCandle();
}

//+------------------------------------------------------------------+
void OpenByLastCandle()
{
   double open  = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double close = iClose(_Symbol, PERIOD_CURRENT, 1);

   if(open == 0 || close == 0)
      return;

   double pip = Pip();
   double sl, tp;

   if(close > open)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      sl = NormalizeDouble(ask - StopLossPips * pip, _Digits);
      tp = NormalizeDouble(ask + TakeProfitPips * pip, _Digits);

      trade.Buy(Lots, _Symbol, ask, sl, tp, "Bullish Candle BUY");
   }
   else if(close < open)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      sl = NormalizeDouble(bid + StopLossPips * pip, _Digits);
      tp = NormalizeDouble(bid - TakeProfitPips * pip, _Digits);

      trade.Sell(Lots, _Symbol, bid, sl, tp, "Bearish Candle SELL");
   }
}

//+------------------------------------------------------------------+
//| Trailing Stop - keeps 20 pip distance                             |
//+------------------------------------------------------------------+
void ManageTrailing()
{
   if(!PositionSelect(_Symbol))
      return;

   if(PositionGetInteger(POSITION_MAGIC) != (long)MagicNumber)
      return;

   ulong  ticket = PositionGetInteger(POSITION_TICKET);
   long   type   = PositionGetInteger(POSITION_TYPE);
   double sl     = PositionGetDouble(POSITION_SL);
   double tp     = PositionGetDouble(POSITION_TP);

   double pip = Pip();
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double newSL = sl;

   if(type == POSITION_TYPE_BUY)
   {
      newSL = NormalizeDouble(bid - TrailingPips * pip, _Digits);

      if(sl == 0 || newSL > sl)
      {
         if(newSL < bid)
            trade.PositionModify(ticket, newSL, tp);
      }
   }
   else if(type == POSITION_TYPE_SELL)
   {
      newSL = NormalizeDouble(ask + TrailingPips * pip, _Digits);

      if(sl == 0 || newSL < sl)
      {
         if(newSL > ask)
            trade.PositionModify(ticket, newSL, tp);
      }
   }
}

//+------------------------------------------------------------------+
//| Reverse trade when previous position is stopped out              |
//+------------------------------------------------------------------+
void OnTradeTransaction(
   const MqlTradeTransaction &trans,
   const MqlTradeRequest &request,
   const MqlTradeResult &result
)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   ulong deal = trans.deal;

   if(deal == 0)
      return;

   if(!HistoryDealSelect(deal))
      return;

   string symbol = HistoryDealGetString(deal, DEAL_SYMBOL);

   if(symbol != _Symbol)
      return;

   long magic = HistoryDealGetInteger(deal, DEAL_MAGIC);

   if(magic != (long)MagicNumber)
      return;

   long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
   long reason = HistoryDealGetInteger(deal, DEAL_REASON);
   long type  = HistoryDealGetInteger(deal, DEAL_TYPE);

   // Only reverse when the position was closed by Stop Loss
   if(entry != DEAL_ENTRY_OUT)
      return;

   if(reason != DEAL_REASON_SL)
      return;

   // Wait until the old position is completely closed
   if(PositionSelect(_Symbol))
      return;

   double pip = Pip();
   double sl, tp;

   // BUY was stopped -> open SELL
   if(type == DEAL_TYPE_SELL)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      sl = NormalizeDouble(bid + StopLossPips * pip, _Digits);
      tp = NormalizeDouble(bid - TakeProfitPips * pip, _Digits);

      trade.Sell(Lots, _Symbol, bid, sl, tp, "Reverse SELL");
   }

   // SELL was stopped -> open BUY
   else if(type == DEAL_TYPE_BUY)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      sl = NormalizeDouble(ask - StopLossPips * pip, _Digits);
      tp = NormalizeDouble(ask + TakeProfitPips * pip, _Digits);

      trade.Buy(Lots, _Symbol, ask, sl, tp, "Reverse BUY");
   }
}
//+------------------------------------------------------------------+
