
#ifndef DATA_PREP_MQH
#define DATA_PREP_MQH

//+------------------------------------------------------------------+
//| Copy completed candles and set the latest close to the M1 close  |
//+------------------------------------------------------------------+


bool CopyData(const ENUM_TIMEFRAMES timeframe,
              ohlc_data &destination[])
{
   MqlRates rates[];
   MqlRates lower_rates[];

   // 1. Select lower timeframe.
   ENUM_TIMEFRAMES lower_timeframe;

if(timeframe == PERIOD_M15)      lower_timeframe = PERIOD_M5;
else if(timeframe == PERIOD_H1)  lower_timeframe = PERIOD_M5;
else if(timeframe == PERIOD_H4)  lower_timeframe = PERIOD_M5;
else if(timeframe == PERIOD_M5)  lower_timeframe = PERIOD_M1;
else                             lower_timeframe = PERIOD_CURRENT;

   // 2. M1 (or unsupported): just use closed candles, no reconstruction.
   if(lower_timeframe == PERIOD_CURRENT)
      return CopyClosed(timeframe, rates, destination);

   // 3. Copy HTF candles INCLUDING the forming one (shift 0).
   ResetLastError();
   int copied = CopyRates(_Symbol, timeframe, 0, CANDLE_COUNT, rates);

   if(copied != CANDLE_COUNT)
   {
      Print("CopyRates failed for ", EnumToString(timeframe),
            ". Copied=", copied, ", error=", GetLastError());
      return false;
   }

   int last = CANDLE_COUNT - 1;            // forming HTF candle
   datetime now          = TimeCurrent();
   datetime htf_start    = rates[last].time;
   int      lower_secs   = PeriodSeconds(lower_timeframe);

   if(lower_secs <= 0)
      return false;

   // 4. Get lower timeframe candles from HTF open up to now.
   ResetLastError();
   int lower_copied = CopyRates(_Symbol, lower_timeframe,
                                htf_start, now, lower_rates);

   if(lower_copied <= 0)
   {
      // nothing available yet -> use last closed HTF candle
      return CopyClosed(timeframe, rates, destination);
   }

   // 5. Rebuild OHLC from CLOSED lower candles only.
   double o = 0, h = -DBL_MAX, l = DBL_MAX, c = 0;
   int valid = 0;

   for(int i = 0; i < lower_copied; i++)       // oldest -> newest
   {
      if(lower_rates[i].time < htf_start)
         continue;

      // skip lower candle that is still open
      if(lower_rates[i].time + lower_secs > now)
         continue;

      if(valid == 0)
         o = lower_rates[i].open;

      h = MathMax(h, lower_rates[i].high);
      l = MathMin(l, lower_rates[i].low);
      c = lower_rates[i].close;
      valid++;
   }

   // 6. No closed lower candle yet -> forming HTF candle doesn't exist
   //    in the simulation, so use last fully closed HTF candles.
   if(valid == 0)
      return CopyClosed(timeframe, rates, destination);

   // 7. Output: older candles as-is, last one = simulated.
   ArrayResize(destination, CANDLE_COUNT);
   for(int i = 0; i < CANDLE_COUNT; i++)
   {
      destination[i].time  = rates[i].time;
      destination[i].open  = rates[i].open;
      destination[i].high  = rates[i].high;
      destination[i].low   = rates[i].low;
      destination[i].close = rates[i].close;
   }

   destination[last].open  = o;
   destination[last].high  = h;
   destination[last].low   = l;
   destination[last].close = c;

   return true;
}

// Helper: last CANDLE_COUNT fully closed candles (shift 1 onward).
bool CopyClosed(const ENUM_TIMEFRAMES timeframe,
                MqlRates &rates[],
                ohlc_data &destination[])
{
   ResetLastError();
   int copied = CopyRates(_Symbol, timeframe, 1, CANDLE_COUNT, rates);

   if(copied != CANDLE_COUNT)
   {
      Print("CopyRates (closed) failed for ", EnumToString(timeframe),
            ". Copied=", copied, ", error=", GetLastError());
      return false;
   }

   ArrayResize(destination, CANDLE_COUNT);
   for(int i = 0; i < CANDLE_COUNT; i++)
   {
      destination[i].time  = rates[i].time;
      destination[i].open  = rates[i].open;
      destination[i].high  = rates[i].high;
      destination[i].low   = rates[i].low;
      destination[i].close = rates[i].close;
   }
   return true;
}


//+------------------------------------------------------------------+
//| Normalize OHLC using the first candle's close as the anchor      |
//| 100 symbol points = 1.00 normalized unit                         |
//+------------------------------------------------------------------+
void NormalizeData(const ohlc_data &source[],
                   ohlc_data &destination[])
{
   int count = ArraySize(source);

   if(count <= 0)
      return;

   ArrayResize(destination, count);
   ArraySetAsSeries(destination, true);

   // Anchor: close of the first candle.
   double anchor = source[19].close;

   // 100 symbol points = 1.00 normalized unit.
   double scale = 1.0 / (100.0 * _Point);

   for(int i = 0; i < count; i++)
   {
      destination[i].time = source[i].time;

      destination[i].open =
         (source[i].open - anchor) * scale;

      destination[i].high =
         (source[i].high - anchor) * scale;

      destination[i].low =
         (source[i].low - anchor) * scale;

      destination[i].close =
         (source[i].close - anchor) * scale;
   }

   // First candle's normalized close is exactly zero.
   destination[19].close = 0.0;
}

//+------------------------------------------------------------------+
//| Create indexed text labels from normalized OHLC values           |
//+------------------------------------------------------------------+
void CreateLabeledText(const ohlc_data &source[],
                       numeric_text &destination[])
{
   int count = ArraySize(source);

   ArrayResize(destination, count);
   ArraySetAsSeries(destination, false);
   
   string delimitter ="|";

   for(int i = 0; i < count; i++)
   {
      destination[i].time = source[i].time;

      destination[i].open =
    
         DoubleToString(source[i].open, 2);

      destination[i].high =

         DoubleToString(source[i].high, 2);

      destination[i].low =

         DoubleToString(source[i].low, 2);

      destination[i].close =

         DoubleToString(source[i].close, 2);
   }
}

//+------------------------------------------------------------------+
//| Copy, normalize and label all timeframes                         |
//+------------------------------------------------------------------+
bool CopyAllData()
{
   // 1. Copy completed candles for all timeframes.
   if(!CopyData(PERIOD_H4, real_4hour))
      return false;

   if(!CopyData(PERIOD_H1, real_1hour))
      return false;

   if(!CopyData(PERIOD_M15, real_15min))
      return false;

   if(!CopyData(PERIOD_M5, real_5min))
      return false;

   if(!CopyData(PERIOD_M1, real_1min))
      return false;

   // 2. Set the common anchor price to the latest completed M1 close.
   int m1_count = ArraySize(real_1min);

   if(m1_count <= 0)
   {
      Print("Error: M1 candle data is empty.");
      return false;
   }

  

   // 3. Normalize each timeframe using its own first candle close.
   NormalizeData(real_4hour, normalized_4hour);
   NormalizeData(real_1hour, normalized_1hour);
   NormalizeData(real_15min, normalized_15min);
   NormalizeData(real_5min, normalized_5min);
   NormalizeData(real_1min, normalized_1min);

   // 4. Generate text labels from normalized OHLC values.
   CreateLabeledText(normalized_4hour, labeled_text_4hour);
   CreateLabeledText(normalized_1hour, labeled_text_1hour);
   CreateLabeledText(normalized_15min, labeled_text_15min);
   CreateLabeledText(normalized_5min, labeled_text_5min);
   CreateLabeledText(normalized_1min, labeled_text_1min);

   return true;
}

#endif
