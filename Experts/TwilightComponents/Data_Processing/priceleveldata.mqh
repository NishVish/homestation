//==================================================
// Group Struct
//==================================================

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


//==================================================
// Compare High
//==================================================

string compareHigh(double close_a, double close_b, double b_highest)
{
    if(close_a > b_highest)
    return "HH";

    if(close_a > close_b && close_a < b_highest)
    return "FH";

    if(close_a < close_b)
    return "LH";

    return "Equal";
}


//==================================================
// Compare Low
//==================================================

string compareLow(double close_a, double close_b, double b_lowest)
{
    if(close_a > close_b)
    return "HL";

    if(close_a < close_b && close_a > b_lowest)
    return "FL";

    if(close_a < b_lowest)
    return "LL";

    return "Equal";
}


//==================================================
// Price Level Data
//==================================================

LevelResult PriceLeveData(ContinuousCandleGroup &data[], bool logs = false)
{
    LevelResult res;

    int size = ArraySize(data);

    if(size <= 0)
    {
        ArrayResize(res.levels, 0);
        return res;
    }


    // Reset Status

    for(int i = 0; i < size; i = i + 1)
    {
        data[i].levelstatus = "";
    }


    //==================================================
    // Bullish
    //==================================================

    if(data[0].direction == "bullish")
    {
        // Even indices = High comparisons

        for(int i = 0; i + 2 < size; i = i + 2)
        {
            data[i].levelstatus =
            compareHigh(
            data[i].close,
            data[i + 2].close,
            data[i + 2].high
            );
        }


        // Odd indices = Low comparisons

        for(int i = 1; i + 2 < size; i = i + 2)
        {
            data[i].levelstatus =
            compareLow(
            data[i].close,
            data[i + 2].close,
            data[i + 2].low
            );
        }
    }


    //==================================================
    // Bearish
    //==================================================

    else
    {
        // Even indices = Low comparisons

        for(int i = 0; i + 2 < size; i = i + 2)
        {
            data[i].levelstatus =
            compareLow(
            data[i].close,
            data[i + 2].close,
            data[i + 2].low
            );
        }


        // Odd indices = High comparisons

        for(int i = 1; i + 2 < size; i = i + 2)
        {
            data[i].levelstatus =
            compareHigh(
            data[i].close,
            data[i + 2].close,
            data[i + 2].high
            );
        }
    }


    //==================================================
    // Copy Results
    //==================================================

    ArrayResize(res.levels, size);

    for(int i = 0; i < size; i = i + 1)
    {
        res.levels[i] = data[i].levelstatus;
    }


    //==================================================
    // Logs
    //==================================================

    if(logs)
    {
        Print("========================================");

        PrintFormat(
        "PriceLeveData | Total Groups: % d",
        size
        );

        for(int i = 0; i < size; i = i + 1)
        {
            PrintFormat(
            "INDEX = % d | GROUP = % d | DIR = % s | LEVEL = % s",
            i,
            data[i].groupid,
            data[i].direction,
            data[i].levelstatus
            );
        }

        Print("========================================");
    }


    return res;
}

