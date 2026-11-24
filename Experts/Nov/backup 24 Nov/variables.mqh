
#ifndef VARIABLES_MQH
#define VARIABLES_MQH



//+------------------------------------------------------------------+
//| Numeric OHLC structure                                           |
//+------------------------------------------------------------------+
struct ohlc_data
{
   datetime time;
   double   open;
   double   high;
   double   low;
   double   close;
};

//+------------------------------------------------------------------+
//| Text OHLC structure                                              |
//+------------------------------------------------------------------+
struct numeric_text
{
   datetime time;
   string   open;
   string   high;
   string   low;
   string   close;
};

//+------------------------------------------------------------------+
//| Real price arrays                                                |
//+------------------------------------------------------------------+
ohlc_data real_1day[];
ohlc_data real_4hour[];
ohlc_data real_1hour[];
ohlc_data real_15min[];
ohlc_data real_5min[];
ohlc_data real_1min[];

//+------------------------------------------------------------------+
//| Normalized price arrays                                          |
//+------------------------------------------------------------------+
ohlc_data normalized_1day[];
ohlc_data normalized_4hour[];
ohlc_data normalized_1hour[];
ohlc_data normalized_15min[];
ohlc_data normalized_5min[];
ohlc_data normalized_1min[];

//+------------------------------------------------------------------+
//| Text-labeled arrays                                              |
//+------------------------------------------------------------------+
numeric_text labeled_text_1day[];
numeric_text labeled_text_4hour[];
numeric_text labeled_text_1hour[];
numeric_text labeled_text_15min[];
numeric_text labeled_text_5min[];
numeric_text labeled_text_1min[];

//+------------------------------------------------------------------+
//| Latest completed M1 close used as normalization anchor           |
//+------------------------------------------------------------------+
double anchor_price = 0.0;

#endif
