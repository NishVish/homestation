// //==================================================
// // Group Struct
// //==================================================

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


// ContinuousCandleGroup fourhourgroupdata[];
// ContinuousCandleGroup onehourgroupdata[];
// ContinuousCandleGroup fifteenmingroupdata[];

struct LevelResult
{
    string levels[];
};

// Fixed comparison functions
string compareHigh(double a, double b)
{
    if(a > b) return "HH";
    if(a < b) return "LH";
    return "Equal";
}

string compareLow(double a, double b)
{
    if(a > b) return "HL"; // Fixed: higher low
    if(a < b) return "LL"; // Fixed: lower low
    return "Equal";
}

LevelResult PriceLeveData(ContinuousCandleGroup &data[], bool logs = false)
{
    LevelResult res;
    int size = ArraySize(data);

    if(size <= 0)
    {
        ArrayResize(res.levels, 0);
        return res;
    }

    // Reset status
    for(int i = 0; i < size; i++)
    {
        data[i].levelstatus = "";
    }

    // Dynamic stride loops for all groups in buffer
    if(data[0].direction == "bullish")
    {
        // Even indices = High comparisons (Compare High against High)
        for(int i = 0; i + 2 < size; i + = 2)
        {
            data[i].levelstatus = compareHigh(data[i].highestclose, data[i + 2].highestclose);
        }

        // Odd indices = Low comparisons (Compare Low against Low)
        for(int i = 1; i + 2 < size; i + = 2)
        {
            data[i].levelstatus = compareLow(data[i].lowestclose, data[i + 2].lowestclose);
        }
    }
    else // bearish
    {
        // Even indices = Low comparisons
        for(int i = 0; i + 2 < size; i + = 2)
        {
            data[i].levelstatus = compareLow(data[i].lowestclose, data[i + 2].lowestclose);
        }

        // Odd indices = High comparisons
        for(int i = 1; i + 2 < size; i + = 2)
        {
            data[i].levelstatus = compareHigh(data[i].highestclose, data[i + 2].highestclose);
        }
    }

    // Post-processing mapping (HL -> FL, LH -> FH) across entire array
    for(int i = 0; i < size; i++)
    {
        if(data[i].levelstatus == "HL" && data[0].direction == "bullish")
        {
            data[i].levelstatus = "FL";
        }
        else if(data[i].levelstatus == "LH")
        {
            data[i].levelstatus = "FH";
        }
    }

    // Copy results
    ArrayResize(res.levels, size);
    for(int i = 0; i < size; i++)
    {
        res.levels[i] = data[i].levelstatus;
    }

    if(logs)
    {
        Print("========================================");
        PrintFormat("PriceLeveData | Total Groups: % d", size);
        for(int i = 0; i < size; i++)
        {
            PrintFormat("INDEX = % d | GROUP = % d | DIR = % s | LEVEL = % s",
            i, data[i].groupid, data[i].direction, data[i].levelstatus);
        }
        Print("========================================");
    }

    return res;
}


void PrintGroupSingle(ContinuousCandleGroup &g, int index = 0)
{
    Print("Group #", index,
    " HighestHigh: ", g.highesthigh,
    " HighestHighTime: ", TimeToString(g.highesthightime),

    " HighestClose: ", g.highestclose,
    " HighestCloseTime: ", TimeToString(g.highestclosetime),

    " SecondHighestHigh: ", g.secondhighesthigh,
    " SecondHighestClose: ", g.secondhighestclose,

    " LowestLow: ", g.lowestlow,
    " LowestLowTime: ", TimeToString(g.lowestlowtime),

    " LowestClose: ", g.lowestclose,
    " LowestCloseTime: ", TimeToString(g.lowestclosetime),

    " SecondLowestLow: ", g.secondlowestlow,
    " SecondLowestClose: ", g.secondlowestclose,

    " Direction: ", g.direction,
    " Group ID: ", g.groupid,
    " Count: ", g.count,
    " Level: ", g.levelstatus
    );
}

void PrintGroups(ContinuousCandleGroup &data[])
{
    for(int i = 0; i < ArraySize(data); i++)
    {
        Print("Group #", i,
        " HighestHigh: ", data[i].highesthigh,
        " HighestHighTime: ", TimeToString(data[i].highesthightime),

        " HighestClose: ", data[i].highestclose,
        " HighestCloseTime: ", TimeToString(data[i].highestclosetime),

        " SecondHighestHigh: ", data[i].secondhighesthigh,
        " SecondHighestClose: ", data[i].secondhighestclose,

        " LowestLow: ", data[i].lowestlow,
        " LowestLowTime: ", TimeToString(data[i].lowestlowtime),

        " LowestClose: ", data[i].lowestclose,
        " LowestCloseTime: ", TimeToString(data[i].lowestclosetime),

        " SecondLowestLow: ", data[i].secondlowestlow,
        " SecondLowestClose: ", data[i].secondlowestclose,

        " Direction: ", data[i].direction,
        " Group ID: ", data[i].groupid,
        " Count: ", data[i].count,
        " Level: ", data[i].levelstatus
        );
    }
}