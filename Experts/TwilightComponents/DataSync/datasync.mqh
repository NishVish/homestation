void CandleSync(MqlRates &fifteen[], MqlRates &onehour[])
{
    if(ArraySize(fifteen)==0 || ArraySize(onehour)==0)
        return;

    MqlRates hour = onehour[0];


    double originalOpen = hour.open;


    Print("OLD H1:",
          " Time=",TimeToString(hour.time,TIME_DATE|TIME_MINUTES),
          " O=",hour.open,
          " H=",hour.high,
          " L=",hour.low,
          " C=",hour.close);


    bool firstFound=false;


    for(int i=0; i<ArraySize(fifteen); i++)
    {
        if(fifteen[i].time >= hour.time &&
           fifteen[i].time < hour.time + 3600)
        {

            // only set open from first M15 candle
            if(!firstFound)
            {
                hour.open = fifteen[i].open;
                hour.high = fifteen[i].high;
                hour.low  = fifteen[i].low;
                firstFound=true;
            }
            else
            {
                if(fifteen[i].high > hour.high)
                    hour.high = fifteen[i].high;

                if(fifteen[i].low < hour.low)
                    hour.low = fifteen[i].low;
            }

            // close always moves
            hour.close = fifteen[i].close;
        }
    }


    Print("NEW H1:",
          " Time=",TimeToString(hour.time,TIME_DATE|TIME_MINUTES),
          " O=",hour.open,
          " H=",hour.high,
          " L=",hour.low,
          " C=",hour.close);
}