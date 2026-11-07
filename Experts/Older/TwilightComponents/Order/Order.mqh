


void order(bool buy, double lotSize, double slPoints, double tpPoints)
{
    double price, sl, tp;

    string timeStr = TimeToString(iTime(_Symbol, PERIOD_M15, 0), TIME_DATE | TIME_MINUTES);

    string tpStr = IntegerToString(tpPoints); // or DoubleToString(tpPoints, 0)

    string comment = timeStr + " | " + tpPoints;



    if(buy)
    {
        price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        sl = price - slPoints * _Point;
        tp = price + tpPoints * _Point;

        trade.Buy(lotSize, _Symbol, price, sl, tp, comment);

        // saveOrderData(buy, lotSize, _Symbol, price, sl, tp,tpPoints, comment, TimeCurrent());
    }
    else
    {
        price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        sl = price + slPoints * _Point;
        tp = price - tpPoints * _Point;

        trade.Sell(lotSize, _Symbol, price, sl, tp, comment);
        // saveOrderData(buy, lotSize, _Symbol, price, sl, tp, comment, TimeCurrent());
    }
}

void ExportTradeJournalcsv()
{
   string fileName = "TradeJournal.csv";

   // Open as text file instead of FILE_CSV
   int file = FileOpen(fileName, FILE_WRITE | FILE_TXT | FILE_ANSI);

   if(file == INVALID_HANDLE)
   {
      Print("Failed to open file");
      return;
   }

   // Header
   FileWriteString(file, "Type,Profit,Comment\r\n");

   HistorySelect(0, TimeCurrent());

   int total = HistoryDealsTotal();

   for(int i = 0; i < total; i++)
   {
      ulong exitDeal = HistoryDealGetTicket(i);

      if(HistoryDealGetInteger(exitDeal, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;

      ulong posID = (ulong)HistoryDealGetInteger(exitDeal, DEAL_POSITION_ID);

      double profit = HistoryDealGetDouble(exitDeal, DEAL_PROFIT);

      string type = "";
      string comment = "";

      // Find entry deal for same position
      for(int j = 0; j < total; j++)
      {
         ulong entryDeal = HistoryDealGetTicket(j);

         if(HistoryDealGetInteger(entryDeal, DEAL_POSITION_ID) == posID &&
            HistoryDealGetInteger(entryDeal, DEAL_ENTRY) == DEAL_ENTRY_IN)
         {
            long dealType = HistoryDealGetInteger(entryDeal, DEAL_TYPE);

            type = (dealType == DEAL_TYPE_BUY) ? "BUY" : "SELL";

            comment = HistoryDealGetString(entryDeal, DEAL_COMMENT);

            // Escape commas and quotes in comment
            StringReplace(comment, "\"", "\"\"");

            break;
         }
      }

      string line =
         "\"" + type + "\"," +
         DoubleToString(profit, 2) + "," +
         "\"" + comment + "\"\r\n";

      FileWriteString(file, line);
   }

   FileClose(file);

   Print("Trade journal exported: ", fileName);
}


void ExportTradeJournal()
{

    // Simplified
    string fileName = "TradeJournal.csv";

    int file = FileOpen(fileName, FILE_WRITE | FILE_CSV | FILE_ANSI);
    if(file == INVALID_HANDLE)
    {
        Print("Failed to open file");
        return;
    }

    // Header (only required columns)
    FileWrite(file,
    "Type",
    "Profit",
    "Comment"
    );

    HistorySelect(0, TimeCurrent());

    int total = HistoryDealsTotal();

    for(int i = 0; i < total; i++)
    {
        ulong exitDeal = HistoryDealGetTicket(i);

        if(HistoryDealGetInteger(exitDeal, DEAL_ENTRY) != DEAL_ENTRY_OUT)
        continue;

        ulong posID = HistoryDealGetInteger(exitDeal, DEAL_POSITION_ID);

        double profit = HistoryDealGetDouble(exitDeal, DEAL_PROFIT);

        string type = "";
        string comment = "";

        // find entry deal for same position
        for(int j = 0; j < total; j++)
        {
            ulong entryDeal = HistoryDealGetTicket(j);

            if(HistoryDealGetInteger(entryDeal, DEAL_POSITION_ID) == posID &&
            HistoryDealGetInteger(entryDeal, DEAL_ENTRY) == DEAL_ENTRY_IN)
            {
                long dealType = HistoryDealGetInteger(entryDeal, DEAL_TYPE);
                type = (dealType == DEAL_TYPE_BUY) ? "BUY" : "SELL";

                comment = HistoryDealGetString(entryDeal, DEAL_COMMENT);
                break;
            }
        }

        FileWrite(file,
        type,
        DoubleToString(profit, 2),
        comment
        );
    }

    FileClose(file);
    Print("Trade journal exported: ", fileName);
}



// void ExportTradeJournal()
// {
//     string fileName = "TradeJournal.csv";

//     int file = FileOpen(fileName, FILE_WRITE | FILE_CSV | FILE_ANSI);
//     if(file == INVALID_HANDLE)
//     {
//         Print("Failed to open file");
//         return;
//     }

//     FileWrite(file,
//     "PositionID",
//     "Symbol",
//     "Type",
//     "Volume",
//     "EntryPrice",
//     "ExitPrice",
//     "Profit",
//     "OpenTime",
//     "CloseTime",
//     "Comment"
//     );

//     HistorySelect(0, TimeCurrent());

//     int total = HistoryDealsTotal();

//     for(int i = 0; i < total; i++)
//     {
//         ulong exitDeal = HistoryDealGetTicket(i);

//         if(HistoryDealGetInteger(exitDeal, DEAL_ENTRY) != DEAL_ENTRY_OUT)
//         continue;

//         ulong posID = HistoryDealGetInteger(exitDeal, DEAL_POSITION_ID);

//         string symbol = HistoryDealGetString(exitDeal, DEAL_SYMBOL);
//         double exitPrice = HistoryDealGetDouble(exitDeal, DEAL_PRICE);
//         double profit = HistoryDealGetDouble(exitDeal, DEAL_PROFIT);
//         datetime closeTime = (datetime)HistoryDealGetInteger(exitDeal, DEAL_TIME);

//         // defaults
//         double entryPrice = 0;
//         datetime openTime = 0;
//         double volume = 0;
//         string type = "";
//         string comment = "";

//         // find entry deal for same position
//         for(int j = 0; j < total; j++)
//         {
//             ulong entryDeal = HistoryDealGetTicket(j);

//             if(HistoryDealGetInteger(entryDeal, DEAL_POSITION_ID) == posID &&
//             HistoryDealGetInteger(entryDeal, DEAL_ENTRY) == DEAL_ENTRY_IN)
//             {
//                 entryPrice = HistoryDealGetDouble(entryDeal, DEAL_PRICE);
//                 openTime = (datetime)HistoryDealGetInteger(entryDeal, DEAL_TIME);
//                 volume = HistoryDealGetDouble(entryDeal, DEAL_VOLUME);

//                 long dealType = HistoryDealGetInteger(entryDeal, DEAL_TYPE);
//                 type = (dealType == DEAL_TYPE_BUY) ? "BUY" : "SELL";

//                 // ✅ IMPORTANT: take comment from ENTRY deal
//                 comment = HistoryDealGetString(entryDeal, DEAL_COMMENT);

//                 break;
//             }
//         }

//         FileWrite(file,
//         (string)posID,
//         symbol,
//         type,
//         DoubleToString(volume, 2),
//         DoubleToString(entryPrice, _Digits),
//         DoubleToString(exitPrice, _Digits),
//         DoubleToString(profit, 2),
//         TimeToString(openTime, TIME_DATE | TIME_SECONDS),
//         TimeToString(closeTime, TIME_DATE | TIME_SECONDS),
//         comment
//         );
//     }

//     FileClose(file);
//     Print("Trade journal exported: ", fileName);
// }





// void ExportTradeJournal()
// {
//     string fileName = "TradeJournal.csv";

//     int file = FileOpen(fileName, FILE_WRITE | FILE_CSV | FILE_ANSI);
//     if(file == INVALID_HANDLE) return;

//     FileWrite(file,
//     "PositionID",
//     "Symbol",
//     "Type",
//     "Volume",
//     "EntryPrice",
//     "ExitPrice",
//     "Profit",
//     "OpenTime",
//     "CloseTime",
//     "Comment"
//     );

//     HistorySelect(0, TimeCurrent());

//     int total = HistoryDealsTotal();

//     for(int i = 0; i < total; i++)
//     {
//         ulong deal = HistoryDealGetTicket(i);

//         if(HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT)
//         continue;

//         ulong posID = HistoryDealGetInteger(deal, DEAL_POSITION_ID);

//         string symbol = HistoryDealGetString(deal, DEAL_SYMBOL);
//         double exitPrice = HistoryDealGetDouble(deal, DEAL_PRICE);
//         double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
//         datetime closeTime = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
//         string comment = HistoryDealGetString(deal, DEAL_COMMENT);

//         double entryPrice = 0;
//         datetime openTime = 0;
//         double volume = 0;
//         string type = "";

//       // find entry deal
//         for(int j = 0; j < total; j++)
//         {
//             ulong d2 = HistoryDealGetTicket(j);

//             if(HistoryDealGetInteger(d2, DEAL_POSITION_ID) == posID && HistoryDealGetInteger(d2, DEAL_ENTRY) == DEAL_ENTRY_IN)
//             {
//                 entryPrice = HistoryDealGetDouble(d2, DEAL_PRICE);
//                 openTime = (datetime)HistoryDealGetInteger(d2, DEAL_TIME);
//                 volume = HistoryDealGetDouble(d2, DEAL_VOLUME);
//                 type = (HistoryDealGetInteger(d2, DEAL_TYPE) == DEAL_TYPE_BUY) ? "BUY" : "SELL";
//                 break;
//             }
//         }

//         FileWrite(file,
//         posID,
//         symbol,
//         type,
//         volume,
//         entryPrice,
//         exitPrice,
//         profit,
//         TimeToString(openTime, TIME_DATE|TIME_SECONDS),
//         TimeToString(closeTime, TIME_DATE|TIME_SECONDS),
//         comment
//         );
//     }

//     FileClose(file);
// }


