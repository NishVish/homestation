//+------------------------------------------------------------------+
//| Process candle data and normalize prices to pips                 |
//| Latest close = 0                                                 |
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
    20,
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
   // RESIZE OUTPUT
   //============================================================
    ArrayResize(out, copied);
    ArraySetAsSeries(out, true);


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


      //========================================================
      // USE LATEST COMPLETED M1 CANDLE FOR INDEX 0
      //========================================================
        if(i == 0 && period != PERIOD_M1)
        {
            MqlRates m1_rates[];

            ArraySetAsSeries(m1_rates, true);

            if(CopyRates(
            _Symbol,
            PERIOD_M1,
            1,
            1,
            m1_rates
            ) > 0)
            {
                close = m1_rates[0].close;
                ctime = m1_rates[0].time;

                if(high < close)
                high = close;

                if(low > close)
                low = close;
            }
        }


      //========================================================
      // COPY ORIGINAL DATA
      //========================================================
        out[i].time = ctime;
        out[i].open = open;
        out[i].high = high;
        out[i].low = low;
        out[i].close = close;


      //========================================================
      // CANDLE DIRECTION
      //========================================================
        if(close > open)
        out[i].direction = "bullish";
        else if(close < open)
        out[i].direction = "bearish";
        else
        out[i].direction = "neutral";
    }


   //============================================================
   // NORMALIZATION BASE
   // Latest candle close becomes ZERO
   //============================================================
    const double baseClose = out[0].close;


   //============================================================
   // GET SYMBOL PIP SIZE
   //============================================================
    double pipSize;

    if(_Digits == 3 || _Digits == 5)
    pipSize = _Point * 10.0;
    else
    pipSize = _Point;


   //============================================================
   // NORMALIZE ALL VALUES TO PIPS
   //
   // Example:
   //
   // EURUSD:
   // 0.00010 = 1 pip
   // 0.00004 = 0.4 pips
   //
   // USDJPY:
   // 0.010 = 1 pip
   // 0.004 = 0.4 pips
   //
   // No rounding is performed here.
   //============================================================
    for(int i = 0; i < copied; i++)
    {
        out[i].open =
        (out[i].open - baseClose) / pipSize;

        out[i].high =
        (out[i].high - baseClose) / pipSize;

        out[i].low =
        (out[i].low - baseClose) / pipSize;

        out[i].close =
        (out[i].close - baseClose) / pipSize;
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
        "NORMALIZED PRICE DATA | Symbol: ",
        _Symbol,
        " | Period: ",
        EnumToString(period),
        " | Candles: ",
        copied,
        " | Base Close: ",
        DoubleToString(baseClose, _Digits),
        " | Pip Size: ",
        DoubleToString(pipSize, _Digits)
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
            DoubleToString(out[i].open, 2),
            " pips",

            " | High: ",
            DoubleToString(out[i].high, 2),
            " pips",

            " | Low: ",
            DoubleToString(out[i].low, 2),
            " pips",

            " | Close: ",
            DoubleToString(out[i].close, 2),
            " pips",

            " | Direction: ",
            out[i].direction
            );
        }


        Print(
        "============================================================"
        );
    }


    return copied;
}
