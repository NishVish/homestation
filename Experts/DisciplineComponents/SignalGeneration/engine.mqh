MqlRates rates[];


//==================================================
// INDIVIDUAL CANDLE
//==================================================
struct CandleData
{
    datetime time;
    double open;
    double high;
    double low;
    double close;

    string direction;
    int groupid;
};

CandleData out[];


//==================================================
// GROUPED CANDLE
//==================================================
struct GroupDataSingle
{
    datetime openTime;
    datetime closeTime;

    double open;
    double high;
    double low;
    double close;

    string direction;

    int groupid;
    int count;
    string level;
};

GroupDataSingle groupData[];


//==================================================
// LEVEL HISTORY
// [0] = oldest
// [last] = latest group
//==================================================
string levelData[];


//--------------------------------------------------
// Load raw candle data
//--------------------------------------------------
void RawData(ENUM_TIMEFRAMES timeframe)
{
    ArraySetAsSeries(rates, true);

    int copied = CopyRates(_Symbol, timeframe, 0, 100, rates);

    if(copied <= 0)
    {
        Print("CopyRates failed. Error: ", GetLastError());
        return;
    }
}


//--------------------------------------------------
// Set candle type and group ID
//--------------------------------------------------
void SetCandleTypeAndID()
{
    int length = ArraySize(rates);

    if(length <= 0)
    return;

    ArrayResize(out, length);

    int groupidcount = 0;
    string lastgrouptype = "";

    for(int i = 0; i < length; i++)
    {
        out[i].time = rates[i].time;
        out[i].open = rates[i].open;
        out[i].high = rates[i].high;
        out[i].low = rates[i].low;
        out[i].close = rates[i].close;

        if(rates[i].close > rates[i].open)
        out[i].direction = "bullish";
        else if(rates[i].close < rates[i].open)
        out[i].direction = "bearish";
        else
        out[i].direction = "neutral";

        if(i == 0)
        {
            out[i].groupid = groupidcount;
            lastgrouptype = out[i].direction;
            continue;
        }

        if(out[i].direction != lastgrouptype)
        {
            groupidcount++;
            lastgrouptype = out[i].direction;
        }

        out[i].groupid = groupidcount;
    }
}


//--------------------------------------------------
// Build grouped OHLC
//--------------------------------------------------
void BuildGroupData(ENUM_TIMEFRAMES timeframe)
{
    ArrayResize(groupData, 0);

    int length = ArraySize(out);

    if(length <= 0)
    return;

    int periodSeconds = PeriodSeconds(timeframe);

    for(int i = 0; i < length; i++)
    {
        int gid = out[i].groupid;
        int index = - 1;

        for(int g = 0; g < ArraySize(groupData); g++)
        {
            if(groupData[g].groupid == gid)
            {
                index = g;
                break;
            }
        }

        if(index == - 1)
        {
            index = ArraySize(groupData);

            ArrayResize(groupData, index + 1);

            groupData[index].groupid = gid;

            groupData[index].openTime = out[i].time;
            groupData[index].closeTime = out[i].time + periodSeconds;

            groupData[index].open = out[i].open;
            groupData[index].high = out[i].high;
            groupData[index].low = out[i].low;
            groupData[index].close = out[i].close;

            groupData[index].direction = out[i].direction;

            groupData[index].count = 1;
            groupData[index].level = "";
        }
        else
        {
            if(out[i].high > groupData[index].high)
            groupData[index].high = out[i].high;

            if(out[i].low < groupData[index].low)
            groupData[index].low = out[i].low;

            groupData[index].close = out[i].close;

            groupData[index].count++;

            datetime candleCloseTime =
            out[i].time + periodSeconds;

            if(candleCloseTime > groupData[index].closeTime)
            groupData[index].closeTime = candleCloseTime;
        }
    }
}


//--------------------------------------------------
// Level Annotation
//--------------------------------------------------
void LevelAnnotation()
{
    int total = ArraySize(groupData);

    ArrayResize(levelData, 0);

    if(total <= 0)
    return;

    double lastBullHigh = 0.0;
    double lastBullLow = 0.0;

    double lastBearHigh = 0.0;
    double lastBearLow = 0.0;

    bool bullFound = false;
    bool bearFound = false;


    // Oldest → latest
    for(int i = total - 1; i >= 0; i--)
    {
        string level = "";

        //==========================================
        // BULLISH
        //==========================================
        if(groupData[i].direction == "bullish")
        {
            if(!bullFound)
            {
                level = "HH";

                lastBullHigh = groupData[i].high;
                lastBullLow = groupData[i].low;

                bullFound = true;
            }
            else
            {
                if(groupData[i].high > lastBullHigh)
                level = "HH";
                else
                level = "HL";

                lastBullHigh = groupData[i].high;
                lastBullLow = groupData[i].low;
            }
        }

        //==========================================
        // BEARISH
        //==========================================
        else if(groupData[i].direction == "bearish")
        {
            if(!bearFound)
            {
                level = "LL";

                lastBearHigh = groupData[i].high;
                lastBearLow = groupData[i].low;

                bearFound = true;
            }
            else
            {
                if(groupData[i].low < lastBearLow)
                level = "LL";
                else
                level = "LH";

                lastBearHigh = groupData[i].high;
                lastBearLow = groupData[i].low;
            }
        }

        groupData[i].level = level;

        // Add to level array
        int size = ArraySize(levelData);

        ArrayResize(levelData, size + 1);

        levelData[size] = level;
    }
}
