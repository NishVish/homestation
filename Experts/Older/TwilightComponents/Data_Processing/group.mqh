void PricePhaseData(
const rawdata &data[],
ContinuousCandleGroup &result[],
bool logs = false
)
{
    int totalBars = ArraySize(data);

    if(totalBars <= 0)
    {
        ArrayResize(result, 0);
        return;
    }

    ArrayResize(result, 8);

    int resIdx = 0;
    const int MAX_GROUPS = 8;

    for(int i = 0; i < totalBars && resIdx < MAX_GROUPS; i++)
    {
        //==================================================
        // RESET GROUP
        //==================================================

        result[resIdx].open = data[i].open;
        result[resIdx].high = - DBL_MAX;
        result[resIdx].low = DBL_MAX;
        result[resIdx].close = data[i].close;

        result[resIdx].highesthigh = - DBL_MAX;
        result[resIdx].secondhighesthigh = - DBL_MAX;

        result[resIdx].highestclose = - DBL_MAX;
        result[resIdx].secondhighestclose = - DBL_MAX;

        result[resIdx].lowestlow = DBL_MAX;
        result[resIdx].secondlowestlow = DBL_MAX;

        result[resIdx].lowestclose = DBL_MAX;
        result[resIdx].secondlowestclose = DBL_MAX;

        result[resIdx].highesthightime = 0;
        result[resIdx].highestclosetime = 0;
        result[resIdx].lowestlowtime = 0;
        result[resIdx].lowestclosetime = 0;

        result[resIdx].direction = data[i].direction;
        result[resIdx].groupid = data[i].groupid;
        result[resIdx].count = 0;

        //==================================================
        // ACCUMULATE SAME GROUP
        //==================================================

        int j = i;

        while(
        j < totalBars &&
        data[j].groupid == result[resIdx].groupid &&
        data[j].direction == result[resIdx].direction
        )
        {
            //==================================================
            // GROUP HIGH
            //==================================================

            if(data[j].high > result[resIdx].high)
            {
                result[resIdx].high = data[j].high;
            }

            //==================================================
            // GROUP LOW
            //==================================================

            if(data[j].low < result[resIdx].low)
            {
                result[resIdx].low = data[j].low;
            }

            //==================================================
            // LAST CANDLE CLOSE
            //==================================================

            result[resIdx].close = data[j].close;

            //==================================================
            // HIGHEST HIGH
            //==================================================

            if(data[j].high > result[resIdx].highesthigh)
            {
                result[resIdx].secondhighesthigh =
                result[resIdx].highesthigh;

                result[resIdx].highesthigh =
                data[j].high;

                result[resIdx].highesthightime =
                data[j].time;
            }
            else if(
            data[j].high > result[resIdx].secondhighesthigh &&
            data[j].high < result[resIdx].highesthigh
            )
            {
                result[resIdx].secondhighesthigh =
                data[j].high;
            }

            //==================================================
            // HIGHEST CLOSE
            //==================================================

            if(data[j].close > result[resIdx].highestclose)
            {
                result[resIdx].secondhighestclose =
                result[resIdx].highestclose;

                result[resIdx].highestclose =
                data[j].close;

                result[resIdx].highestclosetime =
                data[j].time;
            }
            else if(
            data[j].close > result[resIdx].secondhighestclose &&
            data[j].close < result[resIdx].highestclose
            )
            {
                result[resIdx].secondhighestclose =
                data[j].close;
            }

            //==================================================
            // LOWEST LOW
            //==================================================

            if(data[j].low < result[resIdx].lowestlow)
            {
                result[resIdx].secondlowestlow =
                result[resIdx].lowestlow;

                result[resIdx].lowestlow =
                data[j].low;

                result[resIdx].lowestlowtime =
                data[j].time;
            }
            else if(
            data[j].low > result[resIdx].lowestlow &&
            data[j].low < result[resIdx].secondlowestlow
            )
            {
                result[resIdx].secondlowestlow =
                data[j].low;
            }

            //==================================================
            // LOWEST CLOSE
            //==================================================

            if(data[j].close < result[resIdx].lowestclose)
            {
                result[resIdx].secondlowestclose =
                result[resIdx].lowestclose;

                result[resIdx].lowestclose =
                data[j].close;

                result[resIdx].lowestclosetime =
                data[j].time;
            }
            else if(
            data[j].close > result[resIdx].lowestclose &&
            data[j].close < result[resIdx].secondlowestclose
            )
            {
                result[resIdx].secondlowestclose =
                data[j].close;
            }


         









            result[resIdx].count++;

            j++;
        }

        //==================================================
        // REMOVE DBL_MAX VALUES FROM SECOND VALUES
        //==================================================

        if(result[resIdx].secondhighesthigh == - DBL_MAX)
        {
            result[resIdx].secondhighesthigh =
            result[resIdx].highesthigh;
        }

        if(result[resIdx].secondhighestclose == - DBL_MAX)
        {
            result[resIdx].secondhighestclose =
            result[resIdx].highestclose;
        }

        if(result[resIdx].secondlowestlow == DBL_MAX)
        {
            result[resIdx].secondlowestlow =
            result[resIdx].lowestlow;
        }

        if(result[resIdx].secondlowestclose == DBL_MAX)
        {
            result[resIdx].secondlowestclose =
            result[resIdx].lowestclose;
        }

        i = j - 1;
        resIdx++;
    }

    ArrayResize(result, resIdx);

    //==================================================
    // LOGGING
    //==================================================

    if(logs)
    {
        Print("========================================");
        Print("PricePhaseData");
        PrintFormat("Total Groups: % d", resIdx);
        Print("========================================");

        for(int i = 0; i < resIdx; i++)
        {
            PrintFormat(
            "GROUP % d | ID = % d | Direction = % s | Count = % d",
            i,
            result[i].groupid,
            result[i].direction,
            result[i].count
            );

            PrintFormat(
            " OHLC: O = % .5f H = % .5f L = % .5f C = % .5f",
            result[i].open,
            result[i].high,
            result[i].low,
            result[i].close
            );

            PrintFormat(
            " High: % .5f | 2nd High: % .5f",
            result[i].highesthigh,
            result[i].secondhighesthigh
            );

            PrintFormat(
            " High Close: % .5f | 2nd High Close: % .5f",
            result[i].highestclose,
            result[i].secondhighestclose
            );

            PrintFormat(
            " Low: % .5f | 2nd Low: % .5f",
            result[i].lowestlow,
            result[i].secondlowestlow
            );

            PrintFormat(
            " Low Close: % .5f | 2nd Low Close: % .5f",
            result[i].lowestclose,
            result[i].secondlowestclose
            );

            Print("----------------------------------------");
        }
    }
}

void exportPricePhaseData(
ENUM_TIMEFRAMES timeframe,
ContinuousCandleGroup &data[]
)
{
    string filename = "";

    filename = filename + _Symbol;
    filename = filename + "_";
    filename = filename + EnumToString(timeframe);
    filename = filename + "_price_phase_data.csv";

    Print("========================================");
    Print("exportPricePhaseData()");
    Print("Filename: [", filename, "]");
    Print("Array size: ", ArraySize(data));
    Print("========================================");

    ResetLastError();

    int handle = FileOpen(
    filename,
    FILE_WRITE |
    FILE_CSV |
    FILE_ANSI,
    ','
    );

    int error = GetLastError();

    if(handle == INVALID_HANDLE)
    {
        Print("FileOpen FAILED");
        Print("Error: ", error);
        return;
    }

    Print("Handle: ", handle);

    //==================================================
    // Header
    //==================================================

    FileWrite(
    handle,
    "open",
    "high",
    "low",
    "close",

    "highesthigh",
    "secondhighesthigh",

    "highestclose",
    "secondhighestclose",

    "lowestlow",
    "secondlowestlow",

    "lowestclose",
    "secondlowestclose",

    "highesthightime",
    "highestclosetime",

    "lowestlowtime",
    "lowestclosetime",

    "direction",
    "groupid",
    "count",
    "levelstatus"
    );


    //==================================================
    // Data
    //==================================================

    for(int i = 0; i < ArraySize(data); i = i + 1)
    {
        FileWrite(
        handle,

        DoubleToString(
        data[i].open,
        _Digits
        ),

        DoubleToString(
        data[i].high,
        _Digits
        ),

        DoubleToString(
        data[i].low,
        _Digits
        ),

        DoubleToString(
        data[i].close,
        _Digits
        ),

        DoubleToString(
        data[i].highesthigh,
        _Digits
        ),

        DoubleToString(
        data[i].secondhighesthigh,
        _Digits
        ),

        DoubleToString(
        data[i].highestclose,
        _Digits
        ),

        DoubleToString(
        data[i].secondhighestclose,
        _Digits
        ),

        DoubleToString(
        data[i].lowestlow,
        _Digits
        ),

        DoubleToString(
        data[i].secondlowestlow,
        _Digits
        ),

        DoubleToString(
        data[i].lowestclose,
        _Digits
        ),

        DoubleToString(
        data[i].secondlowestclose,
        _Digits
        ),

        TimeToString(
        data[i].highesthightime,
        TIME_DATE | TIME_SECONDS
        ),

        TimeToString(
        data[i].highestclosetime,
        TIME_DATE | TIME_SECONDS
        ),

        TimeToString(
        data[i].lowestlowtime,
        TIME_DATE | TIME_SECONDS
        ),

        TimeToString(
        data[i].lowestclosetime,
        TIME_DATE | TIME_SECONDS
        ),

        data[i].direction,

        IntegerToString(
        data[i].groupid
        ),

        IntegerToString(
        data[i].count
        ),

        data[i].levelstatus
        );
    }


    //==================================================
    // Finish
    //==================================================

    FileFlush(handle);

    Print(
    "File size: ",
    FileSize(handle)
    );

    FileClose(handle);

    Print("CSV export completed");
    Print("Rows exported: ", ArraySize(data));
    Print("File: [", filename, "]");
}
