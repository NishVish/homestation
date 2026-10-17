
//+------------------------------------------------------------------+
//| Save all open positions to CSV                                   |
//+------------------------------------------------------------------+
void ExportOpenTradeData()
{
    string fileName = "Trades.csv";

    int fileHandle = FileOpen(
    fileName,
    FILE_WRITE | FILE_CSV | FILE_ANSI
    );

    if(fileHandle == INVALID_HANDLE)
    return;

    FileWrite(fileHandle,
    "DealTicket",
    "OrderTicket",
    "Symbol",
    "Comment",
    "Type",
    "Volume",
    "Price",
    "Profit",
    "Time"
    );

    HistorySelect(0, TimeCurrent());

    int total = HistoryDealsTotal();

    for(int i = 0; i < total; i++)
    {
        ulong deal = HistoryDealGetTicket(i);

        ulong order = HistoryDealGetInteger(deal, DEAL_ORDER);

        string comment = HistoryDealGetString(deal, DEAL_COMMENT);

        if(comment == "" && HistoryOrderSelect(order))
        comment = HistoryOrderGetString(order, ORDER_COMMENT);

        FileWrite(fileHandle,
        deal,
        order,
        HistoryDealGetString(deal, DEAL_SYMBOL),
        comment,
        EnumToString((ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE)),
        HistoryDealGetDouble(deal, DEAL_VOLUME),
        HistoryDealGetDouble(deal, DEAL_PRICE),
        HistoryDealGetDouble(deal, DEAL_PROFIT),
        TimeToString(
        (datetime)HistoryDealGetInteger(deal, DEAL_TIME),
        TIME_DATE | TIME_SECONDS
        )
        );
    }

    FileClose(fileHandle);
}


