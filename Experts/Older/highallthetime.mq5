//+------------------------------------------------------------------+
//|                                               highallthetime.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"


#include "highonlife/engine.mqh"


//+------------------------------------------------------------------+
//| GLOBAL SETTINGS                                                  |
//+------------------------------------------------------------------+
bool PrintPriceData = false;
bool PrintPricePhaseData = false;
bool PrintPriceLeveData = false;
bool PrintPriceAnalysis = false;
datetime lastM1Time;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    return(INIT_SUCCEEDED);
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
void OnTick()
{
   //============================================================
   // RUN ONLY WHEN A NEW M1 CANDLE STARTS
   //============================================================
    datetime currentM1Time = iTime(_Symbol, PERIOD_M1, 0);

    if(currentM1Time == lastM1Time)
    return;

    lastM1Time = currentM1Time;


   //============================================================
   // RUN ANALYSIS
   //============================================================
    Analysis();

   // makeorders();
}


//+------------------------------------------------------------------+
//| Run multi-timeframe market analysis                              |
//+------------------------------------------------------------------+
void Analysis()
{
   //============================================================
   // M1
   //============================================================
    AnalyzeTimeframe(
    PERIOD_M1,
    oneminrawdata
    );


   //============================================================
   // M5
   //============================================================
    AnalyzeTimeframe(
    PERIOD_M5,
    fiveminrawdata
    );


   //============================================================
   // M15
   //============================================================
    AnalyzeTimeframe(
    PERIOD_M15,
    fifteenminrawdata
    );


   //============================================================
   // H1
   //============================================================
    AnalyzeTimeframe(
    PERIOD_H1,
    onehourrawdata
    );


   //============================================================
   // H4
   //============================================================
    AnalyzeTimeframe(
    PERIOD_H4,
    fourhourrawdata
    );


   ////============================================================
   //// EXPORT NORMALIZED DATA
   ////============================================================
    ExportMLDataCSV(
    fourhourrawdata,
    onehourrawdata,
    fifteenminrawdata,
    fiveminrawdata,
    oneminrawdata
    );
}


//+------------------------------------------------------------------+
//| Analyze one timeframe                                            |
//+------------------------------------------------------------------+
void AnalyzeTimeframe(
ENUM_TIMEFRAMES timeframe,
rawdata &out[]
)
{
   //============================================================
   // PriceData performs:
   //
   // 1. Candle data retrieval
   // 2. OHLC processing
   // 3. Direction calculation
   // 4. Latest close normalization
   //
   // After this call:
   //
   // out[0].close == 0
   //
   // for every timeframe.
   //============================================================

    PriceData(
    timeframe,
    out,
    PrintPriceData
    );


   //============================================================
   // FUTURE PROCESSING
   //============================================================

   //PricePhaseData(
   //   out,
   //   data,
   //   PrintPricePhaseData
   //);

   //PriceLeveData(
   //   data,
   //   PrintPriceLeveData
   //);

   //PriceAnalysis(
   //   data,
   //   ma,
   //   PrintPriceAnalysis
   //);
}
