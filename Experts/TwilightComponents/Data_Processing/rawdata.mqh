//+------------------------------------------------------------------+
//| Calculate Candle Momentum                                        |
//+------------------------------------------------------------------+
string momentum(const rawdata &data)
{
    const double range = data.range;

    if(range <= 0.0)
    return "depleting";

    const double body = data.body;
    const double upperWick = data.upperwick;
    const double lowerWick = data.lowerwick;

    const double bodyRatio = data.bodyratio;
    const double upperWickRatio = data.upperwickratio;
    const double lowerWickRatio = data.lowerwickratio;


    //============================================================
    // DOJI / VERY SMALL BODY
    //============================================================
    if(bodyRatio < 0.15)
    return "depleting";


    //============================================================
    // BULLISH CANDLE
    //============================================================
    if(data.close > data.open)
    {
        // Strong bullish momentum
        if(
        bodyRatio >= 0.60 &&
        upperWickRatio <= 0.20 &&
        lowerWickRatio <= 0.20
        )
        {
            return "strong";
        }


        // Bullish rejection
        if(
        lowerWickRatio >= 0.50 &&
        bodyRatio <= 0.40
        )
        {
            return "rejection";
        }


        // Buyer exhaustion / upper rejection
        if(
        upperWickRatio >= 0.40
        )
        {
            return "depleting";
        }


        return "depleting";
    }


    //============================================================
    // BEARISH CANDLE
    //============================================================
    if(data.close < data.open)
    {
        // Strong bearish momentum
        if(
        bodyRatio >= 0.60 &&
        upperWickRatio <= 0.20 &&
        lowerWickRatio <= 0.20
        )
        {
            return "strong";
        }


        // Bearish rejection
        if(
        upperWickRatio >= 0.50 &&
        bodyRatio <= 0.40
        )
        {
            return "rejection";
        }


        // Seller exhaustion / lower rejection
        if(
        lowerWickRatio >= 0.40
        )
        {
            return "depleting";
        }


        return "depleting";
    }


    return "depleting";
}

//+------------------------------------------------------------------+
//| Process candle type and assign continuous group IDs              |
//+------------------------------------------------------------------+
int PriceData(
const ENUM_TIMEFRAMES period,
rawdata &out[],
bool logs = false
)
{
    //============================================================
    // FETCH CANDLE DATA
    //============================================================
    MqlRates rates[];

    ArraySetAsSeries(rates, true);

    const int copied = CopyRates(
    _Symbol,
    period,
    1,
    35,
    rates
    );

    if(copied <= 0)
    {
        Print(
        "CopyRates failed | Period: ",
        EnumToString(period),
        " | Error: ",
        GetLastError()
        );

        ArrayResize(out, 0);

        return 0;
    }


    //============================================================
    // RESIZE OUTPUT & SET AS SERIES
    //============================================================
    ArrayResize(out, copied);
    ArraySetAsSeries(out, true);


    //============================================================
    // INITIALIZE GROUP DATA
    //============================================================
    int groupId = 1;
    string previousDirection = "";

    // Determine pip multiplier (_Point * 10 for 5-digit/3-digit symbols, _Point for 4-digit/2-digit)
    double pipSize = (_Digits == 3 || _Digits == 5) ? _Point * 10.0 : _Point;


    //============================================================
    // PROCESS CANDLES
    //============================================================
    for(int i = 0; i < copied; i++)
    {
        double open = rates[i].open;
        double high = rates[i].high;
        double low = rates[i].low;
        double close = rates[i].close;
        datetime ctime = rates[i].time;

        // Force index 0 (the currently forming candle on higher timeframes like 1H/4H) 
        // to use the latest completed 1-minute candle close and time data.
        if(i == 0 && period != PERIOD_M1)
        {
            MqlRates m1_rates[];
            ArraySetAsSeries(m1_rates, true);
            if(CopyRates(_Symbol, PERIOD_M1, 1, 1, m1_rates) > 0)
            {
                close = m1_rates[0].close;
                ctime = m1_rates[0].time;
                if(high < close) high = close;
                if(low > close) low = close;
            }
        }


        //========================================================
        // COPY OHLC
        //========================================================
        out[i].time = ctime;
        out[i].open = open;
        out[i].high = high;
        out[i].low = low;
        out[i].close = close;


        //========================================================
        // CANDLE DIRECTION
        //========================================================
        string direction = "";

        if(close > open)
        direction = "bullish";
        else if(close < open)
        direction = "bearish";
        else
        direction = "neutral";


        out[i].direction = direction;


        //========================================================
        // GROUP ID
        //========================================================
        if(i == 0)
        {
            out[i].groupid = groupId;

            previousDirection = direction;
        }
        else
        {
            if(direction != previousDirection)
            {
                groupId++;

                previousDirection = direction;
            }

            out[i].groupid = groupId;
        }


        //========================================================
        // CANDLE STRUCTURE (Converted to Pips)
        //========================================================
        out[i].range = (high - low) / pipSize;
        out[i].body = MathAbs(close - open) / pipSize;
        out[i].upperwick = (high - MathMax(open, close)) / pipSize;
        out[i].lowerwick = (MathMin(open, close) - low) / pipSize;


        //========================================================
        // RATIOS
        //========================================================
        if(out[i].range > 0.0)
        {
            out[i].bodyratio =
            out[i].body / out[i].range;

            out[i].upperwickratio =
            out[i].upperwick / out[i].range;

            out[i].lowerwickratio =
            out[i].lowerwick / out[i].range;
        }
        else
        {
            out[i].bodyratio = 0.0;
            out[i].upperwickratio = 0.0;
            out[i].lowerwickratio = 0.0;
        }


        //========================================================
        // MOMENTUM (Passing array element by reference using a local reference alias)
        //========================================================
        out[i].momentum = momentum(out[i]);
    }


    //============================================================
    // LOG DATA
    //============================================================
    if(logs == true)
    {
        Print(
        "============================================================"
        );

        Print(
        "PRICE DATA | Symbol: ",
        _Symbol,
        " | Period: ",
        EnumToString(period),
        " | Candles: ",
        copied,
        " | Groups: ",
        groupId
        );

        Print(
        "============================================================"
        );


        for(int i = 0; i < copied; i++)
        {
            Print(
            "Index: ", i,
            " | Time: ",
            TimeToString(
            out[i].time,
            TIME_DATE | TIME_MINUTES
            ),

            " | Open: ",
            DoubleToString(out[i].open, _Digits),

            " | High: ",
            DoubleToString(out[i].high, _Digits),

            " | Low: ",
            DoubleToString(out[i].low, _Digits),

            " | Close: ",
            DoubleToString(out[i].close, _Digits),

            " | Direction: ",
            out[i].direction,

            " | GroupID: ",
            out[i].groupid,

            " | Range (Pips): ",
            DoubleToString(out[i].range, 1),

            " | Body (Pips): ",
            DoubleToString(out[i].body, 1),

            " | UpperWick (Pips): ",
            DoubleToString(out[i].upperwick, 1),

            " | LowerWick (Pips): ",
            DoubleToString(out[i].lowerwick, 1),

            " | BodyRatio: ",
            DoubleToString(out[i].bodyratio, 3),

            " | UpperWickRatio: ",
            DoubleToString(out[i].upperwickratio, 3),

            " | LowerWickRatio: ",
            DoubleToString(out[i].lowerwickratio, 3),

            " | Momentum: ",
            out[i].momentum
            );
        }


        Print(
        "============================================================"
        );
    }


    return copied;
}


//
//
//+------------------------------------------------------------------+
//| Process candle type and assign continuous group IDs              |
//+------------------------------------------------------------------+
//int PriceData(
//const ENUM_TIMEFRAMES period,
//rawdata &out[],
//bool logs = false
//)
//{
//    ============================================================
//     FETCH CANDLE DATA
//    ============================================================
//    MqlRates rates[];
//
//    ArraySetAsSeries(rates, true);
//
//    const int copied = CopyRates(
//    _Symbol,
//    period,
//    1,
//    60,
//    rates
//    );
//
//    if(copied <= 0)
//    {
//        Print(
//        "CopyRates failed | Period: ",
//        EnumToString(period),
//        " | Error: ",
//        GetLastError()
//        );
//
//        ArrayResize(out, 0);
//
//        return 0;
//    }
//
//
//    ============================================================
//     RESIZE OUTPUT
//    ============================================================
//    ArrayResize(out, copied);
//
//
//    ============================================================
//     INITIALIZE GROUP DATA
//    ============================================================
//    int groupId = 1;
//    string previousDirection = "";
//
//     Determine pip multiplier (_Point * 10 for 5-digit/3-digit symbols, _Point for 4-digit/2-digit)
//    double pipSize = (_Digits == 3 || _Digits == 5) ? _Point * 10.0 : _Point;
//
//
//    ============================================================
//     PROCESS CANDLES
//    ============================================================
//    for(int i = 0; i < copied; i++)
//    {
//        const double open = rates[i].open;
//        const double high = rates[i].high;
//        const double low = rates[i].low;
//        const double close = rates[i].close;
//
//
//        ========================================================
//         COPY OHLC
//        ========================================================
//        out[i].time = rates[i].time;
//        out[i].open = open;
//        out[i].high = high;
//        out[i].low = low;
//        out[i].close = close;
//
//
//        ========================================================
//         CANDLE DIRECTION
//        ========================================================
//        string direction = "";
//
//        if(close > open)
//        direction = "bullish";
//        else if(close < open)
//        direction = "bearish";
//        else
//        direction = "neutral";
//
//
//        out[i].direction = direction;
//
//
//        ========================================================
//         GROUP ID
//        ========================================================
//        if(i == 0)
//        {
//            out[i].groupid = groupId;
//
//            previousDirection = direction;
//        }
//        else
//        {
//            if(direction != previousDirection)
//            {
//                groupId++;
//
//                previousDirection = direction;
//            }
//
//            out[i].groupid = groupId;
//        }
//
//
//        ========================================================
//         CANDLE STRUCTURE (Converted to Pips)
//        ========================================================
//        out[i].range = (high - low) / pipSize;
//        out[i].body = MathAbs(close - open) / pipSize;
//        out[i].upperwick = (high - MathMax(open, close)) / pipSize;
//        out[i].lowerwick = (MathMin(open, close) - low) / pipSize;
//
//
//        ========================================================
//         RATIOS
//        ========================================================
//        if(out[i].range > 0.0)
//        {
//            out[i].bodyratio =
//            out[i].body / out[i].range;
//
//            out[i].upperwickratio =
//            out[i].upperwick / out[i].range;
//
//            out[i].lowerwickratio =
//            out[i].lowerwick / out[i].range;
//        }
//        else
//        {
//            out[i].bodyratio = 0.0;
//            out[i].upperwickratio = 0.0;
//            out[i].lowerwickratio = 0.0;
//        }
//
//
//        ========================================================
//         MOMENTUM (Passing array element by reference using a local reference alias)
//        ========================================================
//        out[i].momentum = momentum(out[i]);
//    }
//
//
//    ============================================================
//     LOG DATA
//    ============================================================
//    if(logs == true)
//    {
//        Print(
//        "============================================================"
//        );
//
//        Print(
//        "PRICE DATA | Symbol: ",
//        _Symbol,
//        " | Period: ",
//        EnumToString(period),
//        " | Candles: ",
//        copied,
//        " | Groups: ",
//        groupId
//        );
//
//        Print(
//        "============================================================"
//        );
//
//
//        for(int i = 0; i < copied; i++)
//        {
//            Print(
//            "Index: ", i,
//            " | Time: ",
//            TimeToString(
//            out[i].time,
//            TIME_DATE | TIME_MINUTES
//            ),
//
//            " | Open: ",
//            DoubleToString(out[i].open, _Digits),
//
//            " | High: ",
//            DoubleToString(out[i].high, _Digits),
//
//            " | Low: ",
//            DoubleToString(out[i].low, _Digits),
//
//            " | Close: ",
//            DoubleToString(out[i].close, _Digits),
//
//            " | Direction: ",
//            out[i].direction,
//
//            " | GroupID: ",
//            out[i].groupid,
//
//            " | Range (Pips): ",
//            DoubleToString(out[i].range, 1),
//
//            " | Body (Pips): ",
//            DoubleToString(out[i].body, 1),
//
//            " | UpperWick (Pips): ",
//            DoubleToString(out[i].upperwick, 1),
//
//            " | LowerWick (Pips): ",
//            DoubleToString(out[i].lowerwick, 1),
//
//            " | BodyRatio: ",
//            DoubleToString(out[i].bodyratio, 3),
//
//            " | UpperWickRatio: ",
//            DoubleToString(out[i].upperwickratio, 3),
//
//            " | LowerWickRatio: ",
//            DoubleToString(out[i].lowerwickratio, 3),
//
//            " | Momentum: ",
//            out[i].momentum
//            );
//        }
//
//
//        Print(
//        "============================================================"
//        );
//    }
//
//
//    return copied;
//}