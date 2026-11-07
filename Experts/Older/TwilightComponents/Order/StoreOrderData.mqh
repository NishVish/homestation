struct OrderRecord
{
    datetime timestamp;

    bool isBuy;
    double lotSize;

    string symbol;

    double entryPrice;
    double stopLoss;
    double takeProfit;

    string pips;
    string comment;
};


void ExportOrderRecord(const OrderRecord &record)
{
    string filename = "order_records.csv";

    bool fileExists = FileIsExist(filename);

    int handle = FileOpen(
    filename,
    FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI,
    ','
    );

    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open file: ", GetLastError());
        return;
    }

    FileSeek(handle, 0, SEEK_END);

   // Write header once
    if(FileSize(handle) == 0)
    {
        FileWrite(
        handle,
        "timestamp",
        "side",
        "lotSize",
        "symbol",
        "entryPrice",
        "stopLoss",
        "takeProfit",
        "pips",
        "comment"
        );
    }

    FileWrite(
    handle,
    TimeToString(record.timestamp, TIME_DATE|TIME_SECONDS),
    record.isBuy ? "BUY" : "SELL",
    record.lotSize,
    record.symbol,
    record.entryPrice,
    record.stopLoss,
    record.takeProfit,
    record.pips,
    record.comment
    );

    FileClose(handle);
}