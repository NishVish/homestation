//+------------------------------------------------------------------+
//|                                                   QuickMoney.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "4.00"
#property strict

#include <Trade/Trade.mqh>

CTrade trade;

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input double InpLotSize             = 0.01;       // Lot size
input double InpMaxLoss             = 0.30;       // Hard maximum loss per trade
input double InpTrailStartProfit    = 10.00;      // Start trailing at profit
input double InpTrailDistanceMoney  = 2.00;       // Trailing distance in money
input double InpFloatingProfitPct   = 1.00;       // Close all at this % floating profit
input int    InpMaxOpenTrades       = 10;         // Maximum open trades
input ulong  InpMagicNumber         = 20260907;   // Magic number
input int    InpMaxSpreadPoints     = 0;          // Max spread (0 = disabled)

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
datetime LastCandleTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetAsyncMode(false);

   LastCandleTime = iTime(_Symbol, PERIOD_M1, 0);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }

//+------------------------------------------------------------------+
//| Count EA positions                                               |
//+------------------------------------------------------------------+
int CountOpenTrades()
  {
   int count = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;

      count++;
     }

   return count;
  }

//+------------------------------------------------------------------+
//| Spread check                                                     |
//+------------------------------------------------------------------+
bool SpreadOK()
  {
   if(InpMaxSpreadPoints <= 0)
      return true;

   MqlTick tick;

   if(!SymbolInfoTick(_Symbol, tick))
      return false;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(point <= 0)
      return false;

   double spread = (tick.ask - tick.bid) / point;

   return(spread <= InpMaxSpreadPoints);
  }

//+------------------------------------------------------------------+
//| Normalize lot                                                    |
//+------------------------------------------------------------------+
double NormalizeLot(double lots)
  {
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(step <= 0)
      return lots;

   lots = MathMax(lots, minLot);
   lots = MathMin(lots, maxLot);

   lots = MathFloor(lots / step) * step;

   return NormalizeDouble(lots, 8);
  }

//+------------------------------------------------------------------+
//| Convert money to price distance                                  |
//+------------------------------------------------------------------+
double MoneyToPriceDistance(double money, double volume)
  {
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   if(tickSize <= 0 || tickValue <= 0 || volume <= 0)
      return 0.0;

   return (money / (tickValue * volume)) * tickSize;
  }

//+------------------------------------------------------------------+
//| Close all EA trades                                              |
//+------------------------------------------------------------------+
void CloseAllTrades()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;

      if(!trade.PositionClose(ticket))
        {
         Print("Failed to close #", ticket,
               ": ",
               trade.ResultRetcodeDescription());
        }
     }
  }

//+------------------------------------------------------------------+
//| Check 1% floating profit target                                  |
//+------------------------------------------------------------------+
bool CheckFloatingProfitTarget()
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);

   if(balance <= 0)
      return false;

   // Current floating profit
   double floatingProfit = equity - balance;

   // 1% of current balance
   double targetProfit =
      balance * (InpFloatingProfitPct / 100.0);

   if(floatingProfit >= targetProfit)
     {
      Print("FLOATING PROFIT TARGET REACHED | Balance: ",
            DoubleToString(balance, 2),
            " | Floating Profit: ",
            DoubleToString(floatingProfit, 2),
            " | Target: ",
            DoubleToString(targetProfit, 2),
            " (",
            DoubleToString(InpFloatingProfitPct, 2),
            "%)");

      CloseAllTrades();

      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Open BUY                                                         |
//+------------------------------------------------------------------+
bool OpenBuy()
  {
   if(CountOpenTrades() >= InpMaxOpenTrades)
      return false;

   if(!SpreadOK())
      return false;

   double lots = NormalizeLot(InpLotSize);

   if(lots <= 0)
      return false;

   if(!trade.Buy(
      lots,
      _Symbol,
      0.0,
      0.0,
      0.0,
      "QuickMoney BUY"))
     {
      Print("BUY failed: ",
            trade.ResultRetcodeDescription());

      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Open SELL                                                        |
//+------------------------------------------------------------------+
bool OpenSell()
  {
   if(CountOpenTrades() >= InpMaxOpenTrades)
      return false;

   if(!SpreadOK())
      return false;

   double lots = NormalizeLot(InpLotSize);

   if(lots <= 0)
      return false;

   if(!trade.Sell(
      lots,
      _Symbol,
      0.0,
      0.0,
      0.0,
      "QuickMoney SELL"))
     {
      Print("SELL failed: ",
            trade.ResultRetcodeDescription());

      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Manage positions                                                 |
//+------------------------------------------------------------------+
void ManageTrades()
  {
   MqlTick tick;

   if(!SymbolInfoTick(_Symbol, tick))
      return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits   = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(point <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;

      double profit     = PositionGetDouble(POSITION_PROFIT);
      double volume     = PositionGetDouble(POSITION_VOLUME);
      double openPrice  = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL  = PositionGetDouble(POSITION_SL);
      double currentTP  = PositionGetDouble(POSITION_TP);

      ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      //==============================================================
      // HARD MAXIMUM LOSS
      //==============================================================
      if(profit <= -InpMaxLoss)
        {
         if(!trade.PositionClose(ticket))
            Print("LOSS CLOSE FAILED #", ticket,
                  ": ",
                  trade.ResultRetcodeDescription());

         continue;
        }

      //==============================================================
      // TRAILING PROFIT
      //==============================================================
      if(profit >= InpTrailStartProfit)
        {
         double distance =
            MoneyToPriceDistance(InpTrailDistanceMoney, volume);

         if(distance <= 0)
            continue;

         double newSL = 0.0;

         long stopsLevel =
            SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);

         double minDistance = stopsLevel * point;

         //===========================================================
         // BUY
         //===========================================================
         if(type == POSITION_TYPE_BUY)
           {
            newSL = tick.bid - distance;

            if(currentSL > 0 && newSL <= currentSL)
               continue;

            if(newSL < openPrice)
               newSL = openPrice;

            if((tick.bid - newSL) < minDistance)
               newSL = tick.bid - minDistance;

            newSL = NormalizeDouble(newSL, digits);

            if(newSL > 0 && newSL < tick.bid)
              {
               if(!trade.PositionModify(ticket, newSL, currentTP))
                 {
                  Print("BUY trailing failed #", ticket,
                        ": ",
                        trade.ResultRetcodeDescription());
                 }
              }
           }

         //===========================================================
         // SELL
         //===========================================================
         else if(type == POSITION_TYPE_SELL)
           {
            newSL = tick.ask + distance;

            if(currentSL > 0 && newSL >= currentSL)
               continue;

            if(newSL > openPrice)
               newSL = openPrice;

            if((newSL - tick.ask) < minDistance)
               newSL = tick.ask + minDistance;

            newSL = NormalizeDouble(newSL, digits);

            if(newSL > tick.ask)
              {
               if(!trade.PositionModify(ticket, newSL, currentTP))
                 {
                  Print("SELL trailing failed #", ticket,
                        ": ",
                        trade.ResultRetcodeDescription());
                 }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| New M1 candle                                                    |
//+------------------------------------------------------------------+
bool IsNewM1Candle()
  {
   datetime currentTime = iTime(_Symbol, PERIOD_M1, 0);

   if(currentTime <= 0)
      return false;

   if(currentTime != LastCandleTime)
     {
      LastCandleTime = currentTime;
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
  {
   //==============================================================
   // CLOSE ALL if floating profit reaches 1% of balance
   //==============================================================
   if(CheckFloatingProfitTarget())
      return;

   //==============================================================
   // Manage individual trades
   //==============================================================
   ManageTrades();

   //==============================================================
   // New M1 candle
   //==============================================================
   if(!IsNewM1Candle())
      return;

   // BUY
   if(CountOpenTrades() < InpMaxOpenTrades)
      OpenBuy();

   // SELL
   if(CountOpenTrades() < InpMaxOpenTrades)
      OpenSell();
  }
//+------------------------------------------------------------------+
