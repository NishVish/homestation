//+------------------------------------------------------------------+
//|                                                Twilight.mq5      |
//|                                  Copyright 2026, MetaTrader 5    |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property link      "https://www.mql5.com"
#property version   "1.00"

int OnInit()
{


   Print("Twilight EA loaded successfully. Setting timer...");
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason)
{
   EventKillTimer();
}
void OnTimer()
{
   string url = "http://127.0.0.1:8080/data";
   string headers = "Content-Type: application/json\r\n";
   
   // Gather market data
   string time_str = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
   string symbol = _Symbol;
   string bid = DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   string ask = DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   
   // Construct JSON payload
   string json_payload = "{\"time\":\"" + time_str + "\",\"symbol\":\"" + symbol + "\",\"bid\":\"" + bid + "\",\"ask\":\"" + ask + "\"}";
   
   char data[];
   char result[];
   string resultHeaders;
   
   StringToCharArray(json_payload, data);
   if(ArraySize(data) > 0)
      ArrayResize(data, ArraySize(data) - 1); // Strip trailing null terminator
      
   ResetLastError();
   int res = WebRequest("POST", url, headers, 3000, data, result, resultHeaders);
   
   if(res == -1)
   {
      Print("WebRequest failed with error: ", GetLastError());
   }
   else
   {
      Print("Data sent successfully! Response code: ", res);
   }
}