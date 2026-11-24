
#ifndef DATA_PREP_MQH
#define DATA_PREP_MQH

//+------------------------------------------------------------------+
//| Copy completed candles and set the latest close to the M1 close  |
//+------------------------------------------------------------------+
bool CopyData(const ENUM_TIMEFRAMES timeframe,
              ohlc_data &destination[])
{
   MqlRates rates[];
   MqlRates m1_rates[];



   ResetLastError();

   // 1. Copy the requested timeframe's completed candles.
   int copied = CopyRates(_Symbol,
                          timeframe,
                          1,
                          CANDLE_COUNT,
                          rates);

   if(copied != CANDLE_COUNT)
   {
      Print("CopyRates failed for ",
            EnumToString(timeframe),
            ". Copied=", copied,
            ", error=", GetLastError());

      return false;
   }

   // 2. Fetch the latest completed M1 candle.
   ResetLastError();

   int m1_copied = CopyRates(_Symbol,
                             PERIOD_M1,
                             1,
                             1,
                             m1_rates);

   if(m1_copied != 1)
   {
      Print("Failed to copy latest completed M1 candle. Error=",
            GetLastError());

      return false;
   }

   // 3. Get the latest completed M1 candle close.
   double last_m1_close = m1_rates[0].close;

   // 4. Copy OHLC data into the destination array.
   ArrayResize(destination, CANDLE_COUNT);
   ArraySetAsSeries(destination, true);

   // Index 0 = oldest candle.
   // Index CANDLE_COUNT-1 = latest completed candle.
   for(int i = 0; i < copied; i++)
   {
      destination[i].time  = rates[i].time;
      destination[i].open  = rates[i].open;
      destination[i].high  = rates[i].high;
      destination[i].low   = rates[i].low;
      destination[i].close = rates[i].close;
      
       Print("Candle: ", i + 1,
         " | Time: ", TimeToString(rates[i].time, TIME_DATE | TIME_MINUTES),
         " | Open: ", DoubleToString(rates[i].open, _Digits),
         " | High: ", DoubleToString(rates[i].high, _Digits),
         " | Low: ", DoubleToString(rates[i].low, _Digits),
         " | Close: ", DoubleToString(rates[i].close, _Digits)); 
   }

   // 5. Replace the latest candle's close with the latest M1 close.
   destination[CANDLE_COUNT - 1].close = last_m1_close;

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
