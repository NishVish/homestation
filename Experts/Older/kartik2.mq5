//+------------------------------------------------------------------+
//|                                                NiftyBeesBot.mq5  |
//|   Conversion of Python NiftyBeesTradingBot to MQL5              |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"

#include <Trade/Trade.mqh>

CTrade trade;

//-------------------------------------------------------------------
// Inputs
//-------------------------------------------------------------------
input double InitialCapital       = 10000.0; // Reference capital
input double RiskPerTradePct      = 2.0;     // 2%
input int    ATR_Period           = 10;
input int    EMA_Fast_Period      = 3;
input int    EMA_Slow_Period      = 8;
input int    EMA_Macro_Period     = 15;

input double ATR_Stop_Multiplier  = 2.0;
input double ATR_BE_Trigger       = 1.0;
input double ATR_BE_Buffer        = 0.05;

input int    StaleBars            = 8;
input double StaleProfitATR       = 0.3;

input ulong  MagicNumber          = 20260918;

//-------------------------------------------------------------------
// Indicator handles
//-------------------------------------------------------------------
int atrHandle;
int emaFastHandle;
int emaSlowHandle;
int emaMacroHandle;

//-------------------------------------------------------------------
// State
//-------------------------------------------------------------------
double entryPrice    = 0.0;
double highestPrice  = 0.0;
int    barsInTrade   = 0;

datetime lastBarTime = 0;

//-------------------------------------------------------------------
//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   atrHandle =
      iATR(_Symbol, _Period, ATR_Period);

   emaFastHandle =
      iMA(_Symbol, _Period, EMA_Fast_Period, 0,
          MODE_EMA, PRICE_CLOSE);

   emaSlowHandle =
      iMA(_Symbol, _Period, EMA_Slow_Period, 0,
          MODE_EMA, PRICE_CLOSE);

   emaMacroHandle =
      iMA(_Symbol, _Period, EMA_Macro_Period, 0,
          MODE_EMA, PRICE_CLOSE);

   if(atrHandle == INVALID_HANDLE ||
      emaFastHandle == INVALID_HANDLE ||
      emaSlowHandle == INVALID_HANDLE ||
      emaMacroHandle == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles.");
      return(INIT_FAILED);
   }

   trade.SetExpertMagicNumber(MagicNumber);

   Print("NiftyBeesBot initialized.");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: ", EnumToString(_Period));

   return(INIT_SUCCEEDED);
}

//-------------------------------------------------------------------
//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);

   if(emaFastHandle != INVALID_HANDLE)
      IndicatorRelease(emaFastHandle);

   if(emaSlowHandle != INVALID_HANDLE)
      IndicatorRelease(emaSlowHandle);

   if(emaMacroHandle != INVALID_HANDLE)
      IndicatorRelease(emaMacroHandle);
}

//-------------------------------------------------------------------
//+------------------------------------------------------------------+
//| Check if new candle                                               |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBarTime = iTime(_Symbol, _Period, 0);

   if(currentBarTime == 0)
      return false;

   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }

   return false;
}

//-------------------------------------------------------------------
//+------------------------------------------------------------------+
//| Get indicator value                                               |
//+------------------------------------------------------------------+
bool GetIndicatorValue(
   int handle,
   int shift,
   double &value
)
{
   double buffer[];

   ArraySetAsSeries(buffer, true);

   if(CopyBuffer(handle, 0, shift, 1, buffer) != 1)
      return false;

   value = buffer[0];

   return true;
}

//-------------------------------------------------------------------
//+------------------------------------------------------------------+
//| Get account capital                                               |
//-------------------------------------------------------------------+
double GetCapital()
{
   // In live trading, use current equity as the dynamically
   // updated capital balance.
   return AccountInfoDouble(ACCOUNT_EQUITY);
}

//-------------------------------------------------------------------
//+------------------------------------------------------------------+
//| Calculate position size                                           |
//-------------------------------------------------------------------+
double CalculatePositionSize(
   double entry,
   double stopDistance
)
{
   if(stopDistance <= 0.0)
      return 0.0;

   double capital =
      GetCapital();

   double riskAmount =
      capital * (RiskPerTradePct / 100.0);

   //----------------------------------------------------------------
   // Determine value of one point for one lot
   //----------------------------------------------------------------
   double tickSize =
      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   double tickValue =
      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   if(tickSize <= 0.0 || tickValue <= 0.0)
      return 0.0;

   //----------------------------------------------------------------
   // Risk per 1 lot
   //----------------------------------------------------------------
   double riskPerLot =
      (stopDistance / tickSize) * tickValue;

   if(riskPerLot <= 0.0)
      return 0.0;

   //----------------------------------------------------------------
   // Raw lot size
   //----------------------------------------------------------------
   double lots =
      riskAmount / riskPerLot;

   //----------------------------------------------------------------
   // Normalize to broker's volume constraints
   //----------------------------------------------------------------
   double minLot =
      SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double maxLot =
      SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   double lotStep =
      SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(lotStep <= 0.0)
      return 0.0;

   lots =
      MathFloor(lots / lotStep) * lotStep;

   lots =
      NormalizeDouble(lots, 2);

   if(lots < minLot)
      return 0.0;

   if(lots > maxLot)
      lots = maxLot;

   return lots;
}

//-------------------------------------------------------------------
//+------------------------------------------------------------------+
//| Check whether our position exists                                |
//-------------------------------------------------------------------+
bool HasOurPosition()
{
   if(!PositionSelect(_Symbol))
      return false;

   ulong magic =
      (ulong)PositionGetInteger(POSITION_MAGIC);

   return magic == MagicNumber;
}

//-------------------------------------------------------------------
//+------------------------------------------------------------------+
//| Update internal state from existing position                      |
//-------------------------------------------------------------------+
void SynchronizePositionState()
{
   if(!HasOurPosition())
   {
      entryPrice   = 0.0;
      highestPrice = 0.0;
      barsInTrade  = 0;
      return;
   }

   entryPrice =
      PositionGetDouble(POSITION_PRICE_OPEN);

   double currentHigh =
      iHigh(_Symbol, _Period, 1);

   if(highestPrice <= 0.0)
      highestPrice = currentHigh;
}

//-------------------------------------------------------------------
//+------------------------------------------------------------------+
//| Open long position                                                |
//-------------------------------------------------------------------+
void OpenLong(double closePrice, double highPrice, double atr)
{
   if(atr <= 0.0)
      return;

   double stopDistance =
      ATR_Stop_Multiplier * atr;

   double lots =
      CalculatePositionSize(
         closePrice,
         stopDistance
      );

   if(lots <= 0.0)
   {
      Print("Position size too small for broker requirements.");
      return;
   }

   //----------------------------------------------------------------
   // Check available margin
   //----------------------------------------------------------------
   double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double marginRequired = 0.0;

   if(!OrderCalcMargin(
      ORDER_TYPE_BUY,
      _Symbol,
      lots,
      ask,
      marginRequired))
   {
      Print("Could not calculate margin.");
      return;
   }

   double freeMargin =
      AccountInfoDouble(ACCOUNT_MARGIN_FREE);

   if(marginRequired > freeMargin)
   {
      Print("Insufficient margin.");
      return;
   }

   //----------------------------------------------------------------
   // Entry
   //----------------------------------------------------------------
   if(trade.Buy(
      lots,
      _Symbol,
      0.0,
      0.0,
      0.0,
      "NiftyBees EMA Entry"))
   {
      if(PositionSelect(_Symbol))
      {
         entryPrice =
            PositionGetDouble(POSITION_PRICE_OPEN);

         highestPrice =
            highPrice;

         barsInTrade = 0;

         Print(
            "ENTRY | Price=",
            DoubleToString(entryPrice, _Digits),
            " | Lots=",
            DoubleToString(lots, 2),
            " | ATR=",
            DoubleToString(atr, _Digits)
         );
      }
   }
   else
   {
      Print(
         "Buy failed: ",
         trade.ResultRetcodeDescription()
      );
   }
}

//-------------------------------------------------------------------
//+------------------------------------------------------------------+
//| Close long position                                               |
//-------------------------------------------------------------------+
void CloseLong(string reason, double closePrice)
{
   if(!HasOurPosition())
      return;

   double volume =
      PositionGetDouble(POSITION_VOLUME);

   double positionEntry =
      PositionGetDouble(POSITION_PRICE_OPEN);

   double pnl =
      PositionGetDouble(POSITION_PROFIT);

   if(trade.PositionClose(_Symbol))
   {
      Print(
         "EXIT | Reason=",
         reason,
         " | Entry=",
         DoubleToString(positionEntry, _Digits),
         " | Exit=",
         DoubleToString(closePrice, _Digits),
         " | Volume=",
         DoubleToString(volume, 2),
         " | PnL=",
         DoubleToString(pnl, 2)
      );

      entryPrice   = 0.0;
      highestPrice = 0.0;
      barsInTrade  = 0;
   }
   else
   {
      Print(
         "Close failed: ",
         trade.ResultRetcodeDescription()
      );
   }
}

//-------------------------------------------------------------------
//+------------------------------------------------------------------+
//| Main strategy                                                     |
//-------------------------------------------------------------------+
void OnTick()
{
   //----------------------------------------------------------------
   // Execute strategy once per completed candle
   //----------------------------------------------------------------
   if(!IsNewBar())
      return;

   //----------------------------------------------------------------
   // Need enough historical bars
   //----------------------------------------------------------------
   if(Bars(_Symbol, _Period) < 50)
      return;

   //----------------------------------------------------------------
   // We use completed candle = shift 1
   // Previous candle = shift 2
   //----------------------------------------------------------------
   double closeCurrent =
      iClose(_Symbol, _Period, 1);

   double highCurrent =
      iHigh(_Symbol, _Period, 1);

   double lowCurrent =
      iLow(_Symbol, _Period, 1);

   double fastCurrent;
   double fastPrevious;

   double slowCurrent;
   double slowPrevious;

   double macroEMA;
   double atr;

   if(!GetIndicatorValue(
      emaFastHandle, 1, fastCurrent))
      return;

   if(!GetIndicatorValue(
      emaFastHandle, 2, fastPrevious))
      return;

   if(!GetIndicatorValue(
      emaSlowHandle, 1, slowCurrent))
      return;

   if(!GetIndicatorValue(
      emaSlowHandle, 2, slowPrevious))
      return;

   if(!GetIndicatorValue(
      emaMacroHandle, 1, macroEMA))
      return;

   if(!GetIndicatorValue(
      atrHandle, 1, atr))
      return;

   if(atr <= 0.0)
      return;

   //----------------------------------------------------------------
   // Synchronize with actual MT5 position
   //----------------------------------------------------------------
   SynchronizePositionState();

   //----------------------------------------------------------------
   // EXIT LOGIC
   //----------------------------------------------------------------
   if(HasOurPosition())
   {
      barsInTrade++;

      //----------------------------------------------------------------
      // Update highest price
      //----------------------------------------------------------------
      if(highestPrice <= 0.0)
         highestPrice = highCurrent;

      highestPrice =
         MathMax(highestPrice, highCurrent);

      //----------------------------------------------------------------
      // Dynamic trailing stop
      //----------------------------------------------------------------
      double sl =
         highestPrice -
         (ATR_Stop_Multiplier * atr);

      //----------------------------------------------------------------
      // Breakeven + buffer after 1 ATR favorable movement
      //----------------------------------------------------------------
      double unrealizedProfit =
         highestPrice - entryPrice;

      if(unrealizedProfit >=
         (ATR_BE_Trigger * atr))
      {
         double breakevenSL =
            entryPrice +
            (ATR_BE_Buffer * atr);

         sl =
            MathMax(sl, breakevenSL);
      }

      //----------------------------------------------------------------
      // Stale trade
      //----------------------------------------------------------------
      bool isStale =
         (barsInTrade >= StaleBars) &&
         ((closeCurrent - entryPrice) <
          (StaleProfitATR * atr));

      //----------------------------------------------------------------
      // Strategy-level SL check
      //
      // Python checks close <= SL rather than intrabar Low <= SL.
      //----------------------------------------------------------------
      bool isSLHit =
         closeCurrent <= sl;

      //----------------------------------------------------------------
      // EMA reversal
      //----------------------------------------------------------------
      bool isReversal =
         (fastPrevious > slowPrevious) &&
         (fastCurrent < slowCurrent);

      //----------------------------------------------------------------
      // Exit
      //----------------------------------------------------------------
      if(isStale || isSLHit || isReversal)
      {
         string reason;

         if(isStale)
            reason = "STALE";
         else if(isSLHit)
            reason = "SL";
         else
            reason = "REVERSAL";

         CloseLong(
            reason,
            closeCurrent
         );

         //----------------------------------------------------------------
         // Same behavior as Python:
         // after exiting, the strategy can evaluate an entry
         // on the same candle.
         //----------------------------------------------------------------
      }
   }

   //----------------------------------------------------------------
   // ENTRY LOGIC
   //----------------------------------------------------------------
   if(!HasOurPosition())
   {
      barsInTrade = 0;

      //----------------------------------------------------------------
      // Bullish EMA crossover + macro filter
      //----------------------------------------------------------------
      bool bullishCross =
         (fastPrevious <= slowPrevious) &&
         (fastCurrent > slowCurrent);

      bool aboveMacro =
         closeCurrent > macroEMA;

      if(bullishCross && aboveMacro)
      {
         OpenLong(
            closeCurrent,
            highCurrent,
            atr
         );
      }
   }
}
//+------------------------------------------------------------------+
