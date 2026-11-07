//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+


#include "imports.mqh"
//#include "MarketAnnotation/3levelannotation.mqh"

//+------------------------------------------------------------------+
//|                                                                  |
//+----------------s--------------------------------------------------+
void ExportMultiGridData()
  {
// m15_first = fifteenminrawdata[0];
// h1_first = onehourrawdata[0];
// h4_first = fourhourrawdata[0];
// updateAnalysis(fourhourmarketAnalysis, h4_first);
// updateAnalysis(onehourmarketAnalysis, h1_first);
// updateAnalysis(fifteenminmarketAnalysis, m15_first);

   m15_first = fifteenminrawdata[0];
   fifteenminalldata.basicdata = m15_first;
   fifteenminalldata.analysis = fifteenminmarketAnalysis;

   h1_first = onehourrawdata[0];
   onehouralldata.basicdata = h1_first;
   onehouralldata.analysis = onehourmarketAnalysis;

   h4_first = fourhourrawdata[0];
   fourhouralldata.basicdata = h4_first;
   fourhouralldata.analysis = fourhourmarketAnalysis;

   MultitimeframeSync current;
   current.lowesttf = fifteenminalldata;
   current.middletf = onehouralldata;
   current.highesttf = fourhouralldata;
   SaveMultitimeframeSnapshotCSV(current);


  }






//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+








//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string trigger()
  {
   bool bias = false;
   bool phase = false;
   bool momentum = false;

// BIAS check
   if(fourhourmarketAnalysis.bias == onehourmarketAnalysis.bias &&
      fourhourmarketAnalysis.bias == fifteenminmarketAnalysis.bias)
     {
      bias = true;
     }

// PHASE check (ALL PUSH)
   if(fourhourmarketAnalysis.phase == "push" &&
      onehourmarketAnalysis.phase == "push" &&
      fifteenminmarketAnalysis.phase == "push")
     {
      phase = true;
     }

// MOMENTUM check
   if(fourhourmarketAnalysis.momentum == "strong" &&
      onehourmarketAnalysis.momentum == "strong" &&
      fifteenminmarketAnalysis.momentum == "strong")
     {
      momentum = true;
     }

   if(bias && phase)
     {

      return tradingDirection = fourhourmarketAnalysis.bias;
     }
   return tradingDirection = "Neutral";// && momentum);
  }
