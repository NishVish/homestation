//+------------------------------------------------------------------+
//|                                                     Twilight.mq5 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Nishant Vishwakarma"
#property link      "https://nishvish.github.io/nishvish/"
#property version   "1.00"
#property strict

#include "TwilightComponents/engine.mqh"

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
datetime lastM15Time = 0;
datetime lastM1Time = 0;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
void OnInit()
{
// runviusals(true);
// Analysis();
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//void OnTick()
//{
//    datetime currentM15Time = iTime(_Symbol, PERIOD_M15, 0);
//// Run analysis only when a new M15 candle starts.
//    if(currentM15Time == lastM15Time)
//    return;
//    lastM15Time = currentM15Time;
//    Analysis();
//
//// makeorders();
//}


void OnTick()
{
   datetime currentM1Time = iTime(_Symbol, PERIOD_M1, 0);
// Run analysis only when a new M1 minute candle starts.
   if(currentM1Time == lastM1Time)
      return;
   lastM1Time = currentM1Time;
   Analysis();

// makeorders();
}

//+------------------------------------------------------------------+
//| Run multi-timeframe market analysis                              |
//+------------------------------------------------------------------+
void Analysis()
{
   AnalyzeTimeframe(
      PERIOD_M1,
      oneminrawdata
   );

   AnalyzeTimeframe(
      PERIOD_M5,
      fiveminrawdata
   );

   AnalyzeTimeframe(
      PERIOD_M15,
      fifteenminrawdata
      //fifteenmingroupdata,
      //fifteenminmarketAnalysis
   );

   AnalyzeTimeframe(
      PERIOD_H1,
      onehourrawdata
      //onehourgroupdata,
      //onehourmarketAnalysis
   );

   AnalyzeTimeframe(
      PERIOD_H4,
      fourhourrawdata
      //fourhourgroupdata,
      //fourhourmarketAnalysis
   );

   ExportMLDataCSV(fourhourrawdata, onehourrawdata, fifteenminrawdata, fiveminrawdata, oneminrawdata); // ExportData/export.mqh
   // ExportMultiGridData();
}

bool PrintPriceData = false;
bool PrintPricePhaseData = true;
bool PrintPriceLeveData = true;
bool PrintPriceAnalysis = false;

//+------------------------------------------------------------------+
//| Analyze one timeframe                                            |
//+------------------------------------------------------------------+
//void AnalyzeTimeframe(ENUM_TIMEFRAMES timeframe, rawdata &out[], ContinuousCandleGroup &data[], marketanalysis &ma)
//{

void AnalyzeTimeframe(ENUM_TIMEFRAMES timeframe, rawdata &out[])
{
    PriceData( timeframe, out , PrintPriceData);
    //PricePhaseData( out, data , PrintPricePhaseData);
    //PriceLeveData( data , PrintPriceLeveData);
    //PriceAnalysis( data, ma , PrintPriceAnalysis);
     // Export raw + group data

    //exportPriceData( timeframe, out);
    //exportPricePhaseData( timeframe, data);
    // exportPriceLeveData( timeframe, data);
     
}



//+------------------------------------------------------------------+
//| Strategy tester                                                  |
//+------------------------------------------------------------------+
// double OnTester()
// {
//     Print("file_exported");

// // ExportTradeJournal();
// // ExportTradeJournalcsv();
// // ExportOpenTradeData();
// // ExportTradeOutcomeData();

//     return 0.0;
// }
//+------------------------------------------------------------------+
