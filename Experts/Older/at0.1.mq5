//+------------------------------------------------------------------+
//|                    Candle Buy/Sell 0.1 / -1 Pip EA              |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>

CTrade trade;

//--- Inputs
input double LotSize          = 0.10;
input double ProfitTargetPips = 0.1;   // Close trade at +0.1 pip
input double MaxLossPips      = 1.0;   // Close trade at -1.0 pip
input ulong  MagicNumber      = 20260911;

//--- Track candle
datetime LastBarTime = 0;


//+------------------------------------------------------------------+
//| Pip size                                                         |
//+------------------------------------------------------------------+
double PipSize()
{
   if(_Digits == 3 || _Digits == 5)
      return _Point * 10.0;

   return _Point;
}


//+------------------------------------------------------------------+
//| Check for new candle                                             |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime barTime = iTime(_Symbol, PERIOD_M1, 0);

   if(barTime == 0)
      return false;

   if(barTime != LastBarTime)
   {
      LastBarTime = barTime;
      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| Count our positions                                              |
//+------------------------------------------------------------------+
int OurPositionCount()
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

      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      count++;
   }

   return count;
}


//+------------------------------------------------------------------+
//| Close positions at +0.1 / -1 pip                                 |
//+------------------------------------------------------------------+
void ManagePositions()
{
   double pip = PipSize();

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(bid <= 0 || ask <= 0)
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

      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      long type = PositionGetInteger(POSITION_TYPE);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);

      double profitPips = 0.0;

      //--- BUY
      if(type == POSITION_TYPE_BUY)
      {
         profitPips = (bid - entry) / pip;
      }

      //--- SELL
      else if(type == POSITION_TYPE_SELL)
      {
         profitPips = (entry - ask) / pip;
      }

      //--- Close at +0.1 pip
      if(profitPips >= ProfitTargetPips)
      {
         if(trade.PositionClose(ticket))
         {
            Print("PROFIT CLOSE | Ticket: ", ticket,
                  " | Profit: ",
                  DoubleToString(profitPips, 2),
                  " pips");
         }
         else
         {
            Print("Profit close failed | Ticket: ", ticket,
                  " | Retcode: ",
                  trade.ResultRetcode(),
                  " | ",
                  trade.ResultRetcodeDescription());
         }

         continue;
      }

      //--- Close at -1 pip
      if(profitPips <= -MaxLossPips)
      {
         if(trade.PositionClose(ticket))
         {
            Print("LOSS CLOSE | Ticket: ", ticket,
                  " | Loss: ",
                  DoubleToString(profitPips, 2),
                  " pips");
         }
         else
         {
            Print("Loss close failed | Ticket: ", ticket,
                  " | Retcode: ",
                  trade.ResultRetcode(),
                  " | ",
                  trade.ResultRetcodeDescription());
         }
      }
   }
}


//+------------------------------------------------------------------+
//| Open BUY                                                         |
//+------------------------------------------------------------------+
void OpenBuy()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(ask <= 0)
      return;

   trade.SetExpertMagicNumber(MagicNumber);

   if(trade.Buy(
      LotSize,
      _Symbol,
      ask,
      0,
      0,
      "New Candle BUY"
   ))
   {
      Print("BUY opened at ", ask);
   }
   else
   {
      Print("BUY failed | Retcode: ",
            trade.ResultRetcode(),
            " | ",
            trade.ResultRetcodeDescription());
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

   trade.SetExpertMagicNumber(MagicNumber);

   if(trade.Sell(
      LotSize,
      _Symbol,
      bid,
      0,
      0,
      "New Candle SELL"
   ))
   {
      Print("SELL opened at ", bid);
   }
   else
   {
      Print("SELL failed | Retcode: ",
            trade.ResultRetcode(),
            " | ",
            trade.ResultRetcodeDescription());
   }
}


//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(20);

   //--- Start from current candle so EA doesn't immediately
   //--- open an old candle trade when attached
   LastBarTime = iTime(_Symbol, PERIOD_M1, 0);

   Print("========================================");
   Print("Candle Buy/Sell EA Started");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: M1");
   Print("Profit Target: +", ProfitTargetPips, " pip");
   Print("Maximum Loss: -", MaxLossPips, " pip");
   Print("Lot Size: ", LotSize);
   Print("========================================");

   return INIT_SUCCEEDED;
}


//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Manage every open position on every tick
   ManagePositions();

   //--- Open BUY + SELL at every new M1 candle
   if(IsNewBar())
   {
      OpenBuy();
      OpenSell();
   }
}
//+------------------------------------------------------------------+