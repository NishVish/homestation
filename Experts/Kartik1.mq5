//+------------------------------------------------------------------+
//|                         BB_RSI_MeanReversion.mq5                 |
//|                         Fixed MQL5 EA                            |
//+------------------------------------------------------------------+
#property strict
#property copyright "Educational Template"
#property version   "1.10"

#include <Trade/Trade.mqh>

CTrade trade;

//--- Input Parameters
input double   InpLotSize       = 0.10;
input double   InpTakeProfit    = 300.0;     // Take Profit in points
input double   InpStopLoss      = 150.0;     // Stop Loss in points
input int      InpBandsPeriod   = 20;
input double   InpBandsDev      = 2.0;
input int      InpRsiPeriod     = 14;
input double   InpOversold      = 30.0;
input double   InpOverbought    = 70.0;
input ulong    InpMagicNumber   = 777888;

//--- Indicator handles
int handle_bands = INVALID_HANDLE;
int handle_rsi   = INVALID_HANDLE;

//--- New bar tracking
datetime LastBarTime = 0;


//+------------------------------------------------------------------+
//| Check for new candle                                             |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBar = iTime(_Symbol, _Period, 0);

   if(currentBar == 0)
      return false;

   if(currentBar != LastBarTime)
   {
      LastBarTime = currentBar;
      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| Check if this EA already has a position                          |
//+------------------------------------------------------------------+
bool HasOurPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      ulong magic   = (ulong)PositionGetInteger(POSITION_MAGIC);

      if(symbol == _Symbol && magic == InpMagicNumber)
         return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| Open BUY                                                         |
//+------------------------------------------------------------------+
void OpenBuy()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(ask <= 0)
      return;

   double sl = 0.0;
   double tp = 0.0;

   if(InpStopLoss > 0)
   {
      sl = NormalizeDouble(
         ask - InpStopLoss * _Point,
         _Digits
      );
   }

   if(InpTakeProfit > 0)
   {
      tp = NormalizeDouble(
         ask + InpTakeProfit * _Point,
         _Digits
      );
   }

   trade.SetExpertMagicNumber(InpMagicNumber);

   if(trade.Buy(
      InpLotSize,
      _Symbol,
      ask,
      sl,
      tp,
      "BB RSI BUY"
   ))
   {
      Print(
         "BUY opened | Price: ",
         DoubleToString(ask, _Digits),
         " | SL: ",
         DoubleToString(sl, _Digits),
         " | TP: ",
         DoubleToString(tp, _Digits)
      );
   }
   else
   {
      Print(
         "BUY failed | Retcode: ",
         trade.ResultRetcode(),
         " | ",
         trade.ResultRetcodeDescription()
      );
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

   double sl = 0.0;
   double tp = 0.0;

   if(InpStopLoss > 0)
   {
      sl = NormalizeDouble(
         bid + InpStopLoss * _Point,
         _Digits
      );
   }

   if(InpTakeProfit > 0)
   {
      tp = NormalizeDouble(
         bid - InpTakeProfit * _Point,
         _Digits
      );
   }

   trade.SetExpertMagicNumber(InpMagicNumber);

   if(trade.Sell(
      InpLotSize,
      _Symbol,
      bid,
      sl,
      tp,
      "BB RSI SELL"
   ))
   {
      Print(
         "SELL opened | Price: ",
         DoubleToString(bid, _Digits),
         " | SL: ",
         DoubleToString(sl, _Digits),
         " | TP: ",
         DoubleToString(tp, _Digits)
      );
   }
   else
   {
      Print(
         "SELL failed | Retcode: ",
         trade.ResultRetcode(),
         " | ",
         trade.ResultRetcodeDescription()
      );
   }
}


//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20);

   //--- Bollinger Bands
   handle_bands = iBands(
      _Symbol,
      _Period,
      InpBandsPeriod,
      0,
      InpBandsDev,
      PRICE_CLOSE
   );

   //--- RSI
   handle_rsi = iRSI(
      _Symbol,
      _Period,
      InpRsiPeriod,
      PRICE_CLOSE
   );

   if(handle_bands == INVALID_HANDLE)
   {
      Print(
         "Failed to create Bollinger Bands handle. Error: ",
         GetLastError()
      );

      return INIT_FAILED;
   }

   if(handle_rsi == INVALID_HANDLE)
   {
      Print(
         "Failed to create RSI handle. Error: ",
         GetLastError()
      );

      return INIT_FAILED;
   }

   //--- Prevent immediate entry when EA is attached
   LastBarTime = iTime(
      _Symbol,
      _Period,
      0
   );

   Print("----------------------------------------");
   Print("BB + RSI Mean Reversion EA Started");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: ", EnumToString(_Period));
   Print("BB Period: ", InpBandsPeriod);
   Print("BB Deviation: ", InpBandsDev);
   Print("RSI Period: ", InpRsiPeriod);
   Print("Oversold: ", InpOversold);
   Print("Overbought: ", InpOverbought);
   Print("SL: ", InpStopLoss, " points");
   Print("TP: ", InpTakeProfit, " points");
   Print("----------------------------------------");

   return INIT_SUCCEEDED;
}


//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(handle_bands != INVALID_HANDLE)
      IndicatorRelease(handle_bands);

   if(handle_rsi != INVALID_HANDLE)
      IndicatorRelease(handle_rsi);
}


//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Only evaluate once per new candle
   if(!IsNewBar())
      return;

   //--- Only one position for this EA and symbol
   if(HasOurPosition())
      return;

   //--- Make sure enough bars are available
   int minimumBars = MathMax(
      InpBandsPeriod,
      InpRsiPeriod
   ) + 10;

   if(Bars(_Symbol, _Period) < minimumBars)
      return;

   //--- Indicator arrays
   double upperBand[];
   double lowerBand[];
   double rsi[];

   ArraySetAsSeries(upperBand, true);
   ArraySetAsSeries(lowerBand, true);
   ArraySetAsSeries(rsi, true);

   //--- Use CLOSED candles
   //--- Shift 1 = latest completed candle

   if(CopyBuffer(
      handle_bands,
      1,
      1,
      1,
      upperBand
   ) != 1)
   {
      return;
   }

   if(CopyBuffer(
      handle_bands,
      2,
      1,
      1,
      lowerBand
   ) != 1)
   {
      return;
   }

   if(CopyBuffer(
      handle_rsi,
      0,
      1,
      1,
      rsi
   ) != 1)
   {
      return;
   }

   //--- Latest CLOSED candle
   double closePrice = iClose(
      _Symbol,
      _Period,
      1
   );

   if(closePrice <= 0)
      return;

   //==============================================================
   // BUY
   // Closed candle below lower Bollinger Band
   // RSI oversold
   //==============================================================
   bool buySignal =
      closePrice < lowerBand[0] &&
      rsi[0] < InpOversold;

   //==============================================================
   // SELL
   // Closed candle above upper Bollinger Band
   // RSI overbought
   //==============================================================
   bool sellSignal =
      closePrice > upperBand[0] &&
      rsi[0] > InpOverbought;

   if(buySignal)
   {
      Print(
         "BUY SIGNAL | Close: ",
         DoubleToString(closePrice, _Digits),
         " | Lower BB: ",
         DoubleToString(lowerBand[0], _Digits),
         " | RSI: ",
         DoubleToString(rsi[0], 2)
      );

      OpenBuy();
   }
   else if(sellSignal)
   {
      Print(
         "SELL SIGNAL | Close: ",
         DoubleToString(closePrice, _Digits),
         " | Upper BB: ",
         DoubleToString(upperBand[0], _Digits),
         " | RSI: ",
         DoubleToString(rsi[0], 2)
      );

      OpenSell();
   }
}
//+------------------------------------------------------------------+
