void GenerateFiles()
{
    // =========================
    // 1. CANDLE FILE
    // =========================
    int file1 = FileOpen(
    "fourhour_candles.csv",
    FILE_WRITE | FILE_CSV | FILE_ANSI
    );

    if(file1 != INVALID_HANDLE)
    {
        FileWrite(file1,
        "Index",
        "Time",
        "Open",
        "High",
        "Low",
        "Close");

        for(int i = 0; i < ArraySize(fourhour); i++)
        {
            FileWrite(file1,
            i,
            TimeToString(fourhour[i].time),
            fourhour[i].open,
            fourhour[i].high,
            fourhour[i].low,
            fourhour[i].close);
        }

        FileClose(file1);
    }

    // =========================
    // 2. RAW FILE
    // =========================
    int file2 = FileOpen(
    "fourhour_raw.csv",
    FILE_WRITE | FILE_CSV | FILE_ANSI
    );

    if(file2 != INVALID_HANDLE)
    {
        FileWrite(file2,
        "Index",
        "Time",
        "Open",
        "High",
        "Low",
        "Close",
        "Direction",
        "GroupID");

        for(int i = 0; i < ArraySize(fourhourrawdata); i++)
        {
            FileWrite(file2,
            i,
            TimeToString(fourhourrawdata[i].time),
            fourhourrawdata[i].open,
            fourhourrawdata[i].high,
            fourhourrawdata[i].low,
            fourhourrawdata[i].close,
            fourhourrawdata[i].direction,
            fourhourrawdata[i].groupid);
        }

        FileClose(file2);
    }

    // =========================
    // 3. GROUP FILE
    // =========================
    int file3 = FileOpen(
    "fourhour_groups.csv",
    FILE_WRITE | FILE_CSV | FILE_ANSI
    );

    if(file3 != INVALID_HANDLE)
    {
        FileWrite(file3,
        "Index",
        "Direction",
        "GroupID",
        "HighestHigh",
        "HighestHighTime",
        "HighestClose",
        "HighestCloseTime",
        "SecondHighestHigh",
        "SecondHighestClose",
        "LowestLow",
        "LowestLowTime",
        "LowestClose",
        "LowestCloseTime",
        "SecondLowestLow",
        "SecondLowestClose",
        "Count",
        "LevelStatus");

        for(int i = 0; i < ArraySize(fourhourgroupdata); i++)
        {
            FileWrite(file3,
            i,
            fourhourgroupdata[i].direction,
            fourhourgroupdata[i].groupid,
            fourhourgroupdata[i].highesthigh,
            TimeToString(fourhourgroupdata[i].highesthightime),
            fourhourgroupdata[i].highestclose,
            TimeToString(fourhourgroupdata[i].highestclosetime),
            fourhourgroupdata[i].secondhighesthigh,
            fourhourgroupdata[i].secondhighestclose,
            fourhourgroupdata[i].lowestlow,
            TimeToString(fourhourgroupdata[i].lowestlowtime),
            fourhourgroupdata[i].lowestclose,
            TimeToString(fourhourgroupdata[i].lowestclosetime),
            fourhourgroupdata[i].secondlowestlow,
            fourhourgroupdata[i].secondlowestclose,
            fourhourgroupdata[i].count,
            fourhourgroupdata[i].levelstatus);
        }

        FileClose(file3);
    }

    Print("CSV files overwritten successfully");
}