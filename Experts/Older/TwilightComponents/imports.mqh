


//====================================================
// MetaTrader Includes
//====================================================

#include <Trade/Trade.mqh>

CTrade trade;


//====================================================
// Global Inputs & Data Structures
//====================================================

#include "Variables/input.mqh"
#include "Variables/dataTypes.mqh"


//====================================================
// Market Data Collection
// Fetch raw candle data from multiple timeframes
//====================================================

#include "Data_Processing/rawdata.mqh"


//====================================================
// Market Structure Annotation
// Continuous groups, levels, zones, etc.
//====================================================

#include "Data_Processing/group.mqh"
#include "Data_Processing/levelname.mqh"
// #include "MarketAnnotation/groupleveldata.mqh"


//====================================================
// Market Analysis Engine
// Generates higher-level market context
//====================================================

#include "Analysis/5maketanalysis.mqh"


//====================================================
// Export / Dataset Generation
// Feature matrices, training data, trade logs
//====================================================

#include "ExportData/generatefile.mqh"
#include "ExportData/MultiMatrix.mqh"
#include "ExportData/TradeOutcome.mqh"
#include "ExportData/OrderData.mqh"
#include "ExportData/export_ml.mqh"


//====================================================
// Order Execution & Management
//====================================================

#include "Order/Order.mqh"
#include "Order/MakeOrder.mqh"
#include "Order/StoreOrderData.mqh"


//====================================================
// Debugging & Visualization
//====================================================

#include "Print/4print.mqh"


//====================================================
// Data Syncing
//====================================================

#include "DataSync/datasync.mqh"





