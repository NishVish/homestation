#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.50"
#property strict

#define CANDLE_COUNT 20

#define Export_D1  false
#define Export_H4  true
#define Export_H1  true
#define Export_M15 true
#define Export_M5  true
#define Export_M1  false

#define SnapshotFrequencyMinutes 5
#define SNAPSHOT_COUNT 6


//time remaing to 4hour_close this should be in minuites
//time_remaining to 1hour_close
//time_remaining to 15min_colse

#include <Trade/Trade.mqh>

#include "variables.mqh"
#include "data_prep.mqh"
#include "export_flatdata.mqh"
#include "export_labeled_flatdata.mqh"

// Trading object
CTrade trade;

// Trading volume
input double LotSize = 0.01;

// Tracks the last processed M5 candle
datetime last_processed_m5_time = 0;

// Snapshot timestamps
datetime snapshot_times[SNAPSHOT_COUNT] =
{
   D'2020.01.02 23:10',
   D'2020.01.03 02:05',
   D'2020.01.03 04:20',
   D'2020.01.03 05:20',
   D'2020.01.03 06:40',
   D'2020.01.03 10:40'
};

// Snapshot decisions
string snapshot_decisions[SNAPSHOT_COUNT] =
{
   "",
   "buy",
   "",
   "",
   "sell",
   "sell"
};

// Track processed snapshots
bool snapshot_processed[SNAPSHOT_COUNT] = {false};

//+------------------------------------------------------------------+
//| Execute trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(string decision)
{
   bool result = false;

   if(decision == "buy")
   {
      result = trade.Buy(
         LotSize,
         _Symbol,
         0,
         0,
         0,
         "Snapshot BUY"
      );
   }
   else if(decision == "sell")
   {
      result = trade.Sell(
         LotSize,
         _Symbol,
         0,
         0,
         0,
         "Snapshot SELL"
      );
   }

   if(result)
   {
      Print(decision,
            " order submitted. Volume: ",
            LotSize,
            " | Retcode: ",
            trade.ResultRetcode(),
            " | ",
            trade.ResultRetcodeDescription());
   }
   else
   {
      Print(decision,
            " order failed. Retcode: ",
            trade.ResultRetcode(),
            " | ",
            trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Process snapshot decision                                        |
//+------------------------------------------------------------------+
void ProcessSnapshotDecision(datetime current_time)
{
   for(int i = 0; i < SNAPSHOT_COUNT; i++)
   {
      if(snapshot_processed[i])
         continue;

      if(current_time == snapshot_times[i])
      {
         string decision = snapshot_decisions[i];

         Print("Snapshot matched: ",
               TimeToString(current_time),
               " | Decision: ",
               decision);

         if(decision == "buy" || decision == "sell")
         {
            ExecuteTrade(decision);
         }
         else
         {
            Print("No trade required for this snapshot.");
         }

         snapshot_processed[i] = true;
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("H4 Export: ", Export_H4);
   Print("H1 Export: ", Export_H1);
   Print("M15 Export: ", Export_M15);
   Print("M5 Export: ", Export_M5);
   Print("M1 Export: ", Export_M1);

   Print("Snapshot frequency: ", SnapshotFrequencyMinutes);

   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetExpertMagicNumber(20261114);
   trade.SetDeviationInPoints(20);

   if(!InitializeLabeledExporter())
      return INIT_FAILED;

   last_processed_m5_time = iTime(_Symbol, PERIOD_M5, 1);

   if(!CopyAllData())
   {
      Print("Initial data copy failed.");
      return INIT_SUCCEEDED;
   }

   ExportFlatData();
   ExportLabeledFlatData();

   return INIT_SUCCEEDED;
}



//+------------------------------------------------------------------+
//| Calculate remaining minutes until timeframe candle closes       |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Calculate remaining minutes until timeframe candle closes       |
//+------------------------------------------------------------------+
double GetTimeRemainingMinutes(
   ENUM_TIMEFRAMES timeframe,
   datetime reference_time
)
{
   int timeframe_seconds = PeriodSeconds(timeframe);

   if(timeframe_seconds <= 0)
      return -1.0;

   // Find the candle containing the reference timestamp
   datetime candle_open_time =
      (datetime)((long)reference_time -
      ((long)reference_time % timeframe_seconds));

   datetime candle_close_time =
      candle_open_time + timeframe_seconds;

   long remaining_seconds =
      (long)candle_close_time - (long)reference_time;

   return (double)remaining_seconds / 60.0;
}

//+------------------------------------------------------------------+
//| Get remaining time for all required timeframes                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Get remaining time for all required timeframes                  |
//+------------------------------------------------------------------+
void GetTimeRemaining(
   datetime reference_time,
   double &h4_minutes,
   double &h1_minutes,
   double &m15_minutes
)
{
   h4_minutes = GetTimeRemainingMinutes(
      PERIOD_H4, reference_time
   );

   h1_minutes = GetTimeRemainingMinutes(
      PERIOD_H1, reference_time
   );

   m15_minutes = GetTimeRemainingMinutes(
      PERIOD_M15, reference_time
   );
}




//+------------------------------------------------------------------+
//| Tick                                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Get latest completed M5 candle
   datetime current_m5_time = iTime(_Symbol, PERIOD_M5, 1);

   if(current_m5_time == 0)
      return;

   // Process only once per new completed M5 candle
   if(current_m5_time == last_processed_m5_time)
      return;

   // Update tracking
   last_processed_m5_time = current_m5_time;

   // Check snapshot decision and execute trade
   ProcessSnapshotDecision(current_m5_time);

   // Copy and prepare market data
   if(!CopyAllData())
      return;

   // Export
   // ExportFlatData();
   ExportLabeledFlatData();
}

