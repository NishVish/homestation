
void ExportTradeOutcomeData()
{
    string file_name = "StrategyTest_Trades.csv";

    int handle = FileOpen(file_name,
    FILE_WRITE|FILE_CSV|FILE_ANSI,
    ',');

    if(handle == INVALID_HANDLE)
    {
        Print("Cannot create file");
        return;
    }

    FileWrite(handle,
    "DealTicket",
    "OrderTicket",
    "Time",
    "Symbol",
    "Type",
    "Volume",
    "Price",
    "Profit",
    "Commission",
    "Swap");

    HistorySelect(0, TimeCurrent());

    int deals = HistoryDealsTotal();

    for(int i = 0; i < deals; i++)
    {
        ulong deal_ticket = HistoryDealGetTicket(i);

        if(deal_ticket == 0)
        continue;

        ENUM_DEAL_ENTRY entry =
        (ENUM_DEAL_ENTRY)HistoryDealGetInteger(
        deal_ticket,
        DEAL_ENTRY);

      // Export only closing deals
        if(entry != DEAL_ENTRY_OUT)
        continue;

        FileWrite(
        handle,
        deal_ticket,
        HistoryDealGetInteger(deal_ticket, DEAL_ORDER),
        TimeToString(
        (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME),
        TIME_DATE|TIME_SECONDS),
        HistoryDealGetString(deal_ticket, DEAL_SYMBOL),
        EnumToString(
        (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE)),
        HistoryDealGetDouble(deal_ticket, DEAL_VOLUME),
        HistoryDealGetDouble(deal_ticket, DEAL_PRICE),
        HistoryDealGetDouble(deal_ticket, DEAL_PROFIT),
        HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION),
        HistoryDealGetDouble(deal_ticket, DEAL_SWAP)
        );
    }

    FileClose(handle);

    Print("Closed trades exported.");
}