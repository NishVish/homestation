void exportPriceData(ENUM_TIMEFRAMES timeframe, rawdata &out[])
{
    string filename = "";

    filename = filename + _Symbol;
    filename = filename + "_";
    filename = filename + EnumToString(timeframe);
    filename = filename + "_rawdata.csv";


    Print("========================================");
    Print("exportRaw()");
    Print("Filename: [", filename, "]");
    Print("Symbol: [", _Symbol, "]");
    Print("Timeframe: [", EnumToString(timeframe), "]");
    Print("Array size: ", ArraySize(out));
    Print("========================================");


    ResetLastError();


    int handle = FileOpen(
    filename,
    FILE_WRITE |
    FILE_CSV |
    FILE_ANSI,
    ', '
    );


    int error = GetLastError();


    if(handle == INVALID_HANDLE)
    {
        Print("FileOpen FAILED");
        Print("Error: ", error);
        Print("Filename: [", filename, "]");

        return;
    }


    Print("File opened successfully");
    Print("Handle: ", handle);


    // ==================================================
    // HEADER
    // ==================================================

    FileWrite(
    handle,
    "time",
    "open",
    "high",
    "low",
    "close",
    "direction",
    "groupid"
    );


    // ==================================================
    // DATA
    // ==================================================

    for(int i = 0; i < ArraySize(out); i++)
    {
        FileWrite(
        handle,
        TimeToString(
        out[i].time,
        TIME_DATE | TIME_SECONDS
        ),

        DoubleToString(
        out[i].open,
        _Digits
        ),

        DoubleToString(
        out[i].high,
        _Digits
        ),

        DoubleToString(
        out[i].low,
        _Digits
        ),

        DoubleToString(
        out[i].close,
        _Digits
        ),

        out[i].direction,

        IntegerToString(
        out[i].groupid
        )
        );
    }


    // ==================================================
    // CLOSE
    // ==================================================

    FileClose(handle);


    Print("CSV export completed");
    Print("Rows exported: ", ArraySize(out));
    Print("File: [", filename, "]");
}


// // Raw Data Variables
// MqlRates fourhour[], onehour[], fifteenmin[];


// // Custom Struct
// struct rawdata
// {
//     datetime time;

//     double open;
//     double high;
//     double low;
//     double close;

//     string direction;

//     int groupid;

//     double range;
//     double body;

//     double upperwick;
//     double lowerwick;

//     double bodyratio;
//     double upperwickratio;
//     double lowerwickratio;

//     string momentum;
// };

// rawdata fourhourrawdata[], onehourrawdata[], fifteenminrawdata[];



// // Group Struct
// struct ContinuousCandleGroup
// {
//     double open;
//     double high;
//     double low;
//     double close;

//     double highesthigh;
//     datetime highesthightime;

//     double highestclose;
//     datetime highestclosetime;

//     double secondhighesthigh;
//     datetime secondhighesthightime;

//     double secondhighestclose;
//     datetime secondhighestclosetime;

//     double lowestlow;
//     datetime lowestlowtime;

//     double lowestclose;
//     datetime lowestclosetime;

//     double secondlowestlow;
//     datetime secondlowestlowtime;

//     double secondlowestclose;
//     datetime secondlowestclosetime;

//     string direction;
//     int groupid;
//     int count;
//     string levelstatus;
// };

// ContinuousCandleGroup fourhourgroupdata[], onehourgroupdata[], fifteenmingroupdata[];


//
//write code to export this data in json format
//
//{[ raw_data][continuous_candle_group][market_analysis]}
//
//    keep adding data on top of previous data