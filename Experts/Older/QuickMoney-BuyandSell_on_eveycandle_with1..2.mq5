//+------------------------------------------------------------------+
//|                                             M1_BuySell_Trailing.mq5 |
//|                         Buy + Sell every M1 candle               |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>

CTrade trade;

//--- Inputs
input double LotSize              = 0.01;

// Dollar risk / target
input double StopLossMoney        = 1.00;
input double TakeProfitMoney      = 2.00;

// Trailing settings
input double TrailingStartMoney   = 0.50;   // Start trailing after $0.50 profit
input double TrailingDistanceMoney= 0.50;   // Keep $0.50 behind current profit

input ulong  MagicNumber          = 123456;

//--- Track last processed candle
datetime LastM1Candle = 0;


//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);

   Print("M1 Buy/Sell EA started.");

   return(INIT_SUCCEEDED);
}


//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Trail existing positions on every tick
   TrailPositions();

   //--- Get current M1 candle
   datetime currentCandle = iTime(_Symbol, PERIOD_M1, 0);

   if(currentCandle == 0)
      return;

   //--- Only trade once per new M1 candle
   if(currentCandle == LastM1Candle)
      return;

   LastM1Candle = currentCandle;

   //--- Open BUY
   OpenBuy();

   //--- Open SELL
   OpenSell();
}


//+------------------------------------------------------------------+
//| Calculate price distance from money amount                       |
//+------------------------------------------------------------------+
double MoneyToPriceDistance(double money)
{
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   if(tickSize <= 0 || tickValue <= 0 || LotSize <= 0)
      return 0;

   // Money value of one tick for our lot size
   double moneyPerTick = tickValue * LotSize;

   // Number of ticks required
   double ticks = money / moneyPerTick;

   // Price distance
   double distance = ticks * tickSize;

   return distance;
}


//+------------------------------------------------------------------+
//| Normalize price                                                  |
//+------------------------------------------------------------------+
double NormalizePrice(double price)
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   return NormalizeDouble(price, digits);
}


//+------------------------------------------------------------------+
//| Open BUY                                                         |
//+------------------------------------------------------------------+
void OpenBuy()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(ask <= 0)
      return;

   double slDistance = MoneyToPriceDistance(StopLossMoney);
   double tpDistance = MoneyToPriceDistance(TakeProfitMoney);

   if(slDistance <= 0 || tpDistance <= 0)
   {
      Print("Unable to calculate BUY SL/TP.");
      return;
   }

   double sl = ask - slDistance;
   double tp = ask + tpDistance;

   sl = NormalizePrice(sl);
   tp = NormalizePrice(tp);

   if(!trade.Buy(LotSize, _Symbol, ask, sl, tp, "M1 BUY"))
   {
      Print("BUY failed. Error: ", GetLastError());
   }
   else
   {
      Print("BUY opened. SL=$", StopLossMoney,
            " TP=$", TakeProfitMoney);
   }
}


//+------------------------------------------------------------------+
//| Open SELL                                                        |
//+------------------------------------------------------------------+
void OpenSell()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(bid <= 0)
      return;

   double slDistance = MoneyToPriceDistance(StopLossMoney);
   double tpDistance = MoneyToPriceDistance(TakeProfitMoney);

   if(slDistance <= 0 || tpDistance <= 0)
   {
      Print("Unable to calculate SELL SL/TP.");
      return;
   }

   double sl = bid + slDistance;
   double tp = bid - tpDistance;

   sl = NormalizePrice(sl);
   tp = NormalizePrice(tp);

   if(!trade.Sell(LotSize, _Symbol, bid, sl, tp, "M1 SELL"))
   {
      Print("SELL failed. Error: ", GetLastError());
   }
   else
   {
      Print("SELL opened. SL=$", StopLossMoney,
            " TP=$", TakeProfitMoney);
   }
}


//+------------------------------------------------------------------+
//| Trail profitable positions                                       |
//+------------------------------------------------------------------+
void TrailPositions()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double trailingDistance =
      MoneyToPriceDistance(TrailingDistanceMoney);

   double trailingStart =
      MoneyToPriceDistance(TrailingStartMoney);

   if(trailingDistance <= 0 || trailingStart <= 0)
      return;

   //--- Loop through all positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      //--- Only manage this EA's positions
      string symbol = PositionGetString(POSITION_SYMBOL);
      long magic    = PositionGetInteger(POSITION_MAGIC);

      if(symbol != _Symbol)
         continue;

      if((ulong)magic != MagicNumber)
         continue;

      long type = PositionGetInteger(POSITION_TYPE);

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);

      //==============================================================
      // BUY
      //==============================================================
      if(type == POSITION_TYPE_BUY)
      {
         double profitDistance = bid - openPrice;

         // Start trailing only after enough profit
         if(profitDistance < trailingStart)
            continue;

         double newSL = bid - trailingDistance;

         newSL = NormalizePrice(newSL);

         // Only move SL forward
         if(currentSL == 0 || newSL > currentSL)
         {
            // Don't place SL above current market price
            if(newSL < bid)
            {
               if(!trade.PositionModify(ticket, newSL, currentTP))
               {
                  Print("BUY trailing failed. Ticket: ",
                        ticket,
                        " Error: ",
                        GetLastError());
               }
            }
         }
      }

      //==============================================================
      // SELL
      //==============================================================
      if(type == POSITION_TYPE_SELL)
      {
         double profitDistance = openPrice - ask;

         // Start trailing only after enough profit
         if(profitDistance < trailingStart)
            continue;

         double newSL = ask + trailingDistance;

         newSL = NormalizePrice(newSL);

         // Only move SL forward/down
         if(currentSL == 0 || newSL < currentSL)
         {
            // Don't place SL below current market price
            if(newSL > ask)
            {
               if(!trade.PositionModify(ticket, newSL, currentTP))
               {
                  Print("SELL trailing failed. Ticket: ",
                        ticket,
                        " Error: ",
                        GetLastError());
               }
            }
         }
      }
   }
}


//+------------------------------------------------------------------+
