
#property strict
#include <Trade/Trade.mqh>

CTrade trade;

input double Lots = 0.01;
input ulong Magic = 2601023;
input int FastEMA = 9;
input int SlowEMA = 21;
input int ADXPeriod = 14;
input double MinADX = 20.0;
input int ATRPeriod = 14;
input int Lookback = 5;
input int EntryBufferPoints = 10;
input double SL_ATR = 2.0;
input double TrailStartATR = 1.0;
input double TrailDistanceATR = 1.5;
input int MaxSpreadPoints = 30;

int fastHandle, slowHandle, adxHandle, atrHandle;
datetime lastBar = 0;

int OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   trade.SetTypeFillingBySymbol(_Symbol);

   fastHandle = iMA(_Symbol, _Period, FastEMA, 0,
                    MODE_EMA, PRICE_CLOSE);
   slowHandle = iMA(_Symbol, _Period, SlowEMA, 0,
                    MODE_EMA, PRICE_CLOSE);
   adxHandle = iADX(_Symbol, _Period, ADXPeriod);
   atrHandle = iATR(_Symbol, _Period, ATRPeriod);

   if(fastHandle == INVALID_HANDLE ||
      slowHandle == INVALID_HANDLE ||
      adxHandle == INVALID_HANDLE ||
      atrHandle == INVALID_HANDLE)
      return INIT_FAILED;

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   IndicatorRelease(fastHandle);
   IndicatorRelease(slowHandle);
   IndicatorRelease(adxHandle);
   IndicatorRelease(atrHandle);
}

bool ReadValue(int handle, int buffer, double &value)
{
   double data[1];
   if(CopyBuffer(handle, buffer, 1, 1, data) != 1)
      return false;
   value = data[0];
   return true;
}

double Price(double p)
{
   double tickSize = SymbolInfoDouble(
      _Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize > 0)
      p = MathRound(p / tickSize) * tickSize;
   return NormalizeDouble(p, _Digits);
}

bool NewBar()
{
   datetime t = iTime(_Symbol, _Period, 0);
   if(t == 0 || t == lastBar)
      return false;
   lastBar = t;
   return true;
}

bool HasPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 &&
         PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC) == Magic)
         return true;
   }
   return false;
}

bool HasPending()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (ulong)OrderGetInteger(ORDER_MAGIC) != Magic)
         continue;

      ENUM_ORDER_TYPE t =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      if(t == ORDER_TYPE_BUY_STOP ||
         t == ORDER_TYPE_SELL_STOP)
         return true;
   }
   return false;
}

void CancelPending()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (ulong)OrderGetInteger(ORDER_MAGIC) != Magic)
         continue;

      ENUM_ORDER_TYPE t =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      if(t == ORDER_TYPE_BUY_STOP ||
         t == ORDER_TYPE_SELL_STOP)
      {
         if(!trade.OrderDelete(ticket))
            Print("Cancel failed: ",
                  trade.ResultRetcodeDescription());
      }
   }
}

void TrailStops(double atr)
{
   if(atr <= 0)
      return;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double minDist =
      (double)SymbolInfoInteger(
         _Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;

   double tickSize = SymbolInfoDouble(
      _Symbol, SYMBOL_TRADE_TICK_SIZE);

   minDist += MathMax(tickSize, point);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != Magic)
         continue;

      ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double oldSL = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double newSL = 0;
      bool change = false;

      if(type == POSITION_TYPE_BUY)
      {
         if(tick.bid - open < atr * TrailStartATR)
            continue;

         newSL = Price(tick.bid -
                       MathMax(atr * TrailDistanceATR, minDist));

         if((oldSL == 0 || newSL > oldSL + tickSize * 0.5) &&
            tick.bid - newSL >= minDist - tickSize * 0.1)
            change = true;
      }
      else if(type == POSITION_TYPE_SELL)
      {
         if(open - tick.ask < atr * TrailStartATR)
            continue;

         newSL = Price(tick.ask +
                       MathMax(atr * TrailDistanceATR, minDist));

         if((oldSL == 0 || newSL < oldSL - tickSize * 0.5) &&
            newSL - tick.ask >= minDist - tickSize * 0.1)
            change = true;
      }

      if(change && !trade.PositionModify(ticket, newSL, tp))
         Print("Trailing failed: ",
               trade.ResultRetcodeDescription());
   }
}

void OnTick()
{
   double atr;
   if(ReadValue(atrHandle, 0, atr))
      TrailStops(atr);

   if(!NewBar())
      return;

   double fast, slow, adx, plusDI, minusDI;

   if(!ReadValue(fastHandle, 0, fast) ||
      !ReadValue(slowHandle, 0, slow) ||
      !ReadValue(adxHandle, 0, adx) ||
      !ReadValue(adxHandle, 1, plusDI) ||
      !ReadValue(adxHandle, 2, minusDI) ||
      !ReadValue(atrHandle, 0, atr))
      return;

   int signal = 0;

   if(adx >= MinADX && fast > slow && plusDI > minusDI)
      signal = 1;
   else if(adx >= MinADX && fast < slow && minusDI > plusDI)
      signal = -1;

   // Cancel pending orders when momentum disappears
   // or changes direction.
   if(signal == 0)
   {
      CancelPending();
      return;
   }

   // Cancel pending orders in the opposite direction.
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;

      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (ulong)OrderGetInteger(ORDER_MAGIC) != Magic)
         continue;

      ENUM_ORDER_TYPE t =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      if((signal == 1 && t == ORDER_TYPE_SELL_STOP) ||
         (signal == -1 && t == ORDER_TYPE_BUY_STOP))
      {
         if(!trade.OrderDelete(ticket))
            Print("Delete failed: ",
                  trade.ResultRetcodeDescription());
      }
   }

   if(HasPosition() || HasPending() || atr <= 0)
      return;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;

   double spread = (tick.ask - tick.bid) / _Point;
   if(spread > MaxSpreadPoints)
      return;

   double minDist =
      (double)SymbolInfoInteger(
         _Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;

   double tickSize = SymbolInfoDouble(
      _Symbol, SYMBOL_TRADE_TICK_SIZE);

   minDist += MathMax(tickSize, _Point);

   double lots = Lots;
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(step <= 0)
      return;

   lots = MathMin(lots, maxLot);
   lots = MathFloor(lots / step + 1e-8) * step;

   if(lots < minLot)
      return;

   double slDistance = MathMax(atr * SL_ATR, minDist);
   double entry, sl;

   if(signal == 1)
   {
      int shift = iHighest(_Symbol, _Period,
                           MODE_HIGH, Lookback, 1);
      if(shift < 0)
         return;

      entry = MathMax(
         iHigh(_Symbol, _Period, shift) +
            EntryBufferPoints * _Point,
         tick.ask + minDist);

      entry = Price(entry);
      sl = Price(entry - slDistance);

      if(entry - sl < minDist)
         sl = Price(entry - minDist);

      if(!trade.BuyStop(lots, entry, _Symbol, sl, 0,
                        ORDER_TIME_GTC, 0, "Momentum Buy"))
         Print("Buy Stop failed: ",
               trade.ResultRetcodeDescription());
   }
   else
   {
      int shift = iLowest(_Symbol, _Period,
                          MODE_LOW, Lookback, 1);
      if(shift < 0)
         return;

      entry = MathMin(
         iLow(_Symbol, _Period, shift) -
            EntryBufferPoints * _Point,
         tick.bid - minDist);

      entry = Price(entry);
      sl = Price(entry + slDistance);

      if(sl - entry < minDist)
         sl = Price(entry + minDist);

      if(!trade.SellStop(lots, entry, _Symbol, sl, 0,
                         ORDER_TIME_GTC, 0, "Momentum Sell"))
         Print("Sell Stop failed: ",
               trade.ResultRetcodeDescription());
   }
}
