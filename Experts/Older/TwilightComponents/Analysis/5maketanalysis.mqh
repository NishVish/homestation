// marketanalysis
// {
//     string bias;
//     string phase;
//     string momentum;
//     string structure;
//     string volatility;
//     string liquidity;
//     string candlePattern;
//     string strength;
//     string narrative;
//     int score;
//     string levels[];
//     string patterntext[];
// };

// Group Struct
// struct ContinuousCandleGroup
// {
//     double open;
//     double high;
//     double low;
//     double close;
//
//     double highesthigh;
//     datetime highesthightime;
//
//     double highestclose;
//     datetime highestclosetime;
//
//     double secondhighesthigh;
//     datetime secondhighesthightime;
//
//     double secondhighestclose;
//     datetime secondhighestclosetime;
//
//     double lowestlow;
//     datetime lowestlowtime;
//
//     double lowestclose;
//     datetime lowestclosetime;
//
//     double secondlowestlow;
//     datetime secondlowestlowtime;
//
//     double secondlowestclose;
//     datetime secondlowestclosetime;
//
//     string direction;
//     int groupid;
//     int count;
//     string levelstatus;
// };

//============================================================
// MAIN ENTRY POINT
//============================================================
void PriceAnalysis(ContinuousCandleGroup &timeframegroupdata[], marketanalysis &ma, bool logs = false)
{
    ContinuousCandleGroup lastpoint = timeframegroupdata[0];
    ContinuousCandleGroup secondlastpoint = timeframegroupdata[1];
    ContinuousCandleGroup thirdpoint = timeframegroupdata[2];

    // Order matters: Bias must be set before Momentum/Phase/Structure,
    // since those all read ma.bias rather than recomputing it.
    SetBias(lastpoint, secondlastpoint, thirdpoint, ma);
    SetPhase(lastpoint, secondlastpoint, thirdpoint, ma);
    SetMomentum(lastpoint, secondlastpoint, thirdpoint, ma);
    SetStructure(lastpoint, secondlastpoint, thirdpoint, ma);
    SetLiquidity(lastpoint, secondlastpoint, thirdpoint, ma);
    SetVolatility(lastpoint, secondlastpoint, thirdpoint, ma);
    SetCandles(lastpoint, secondlastpoint, thirdpoint, ma);
    SetStrength(lastpoint, secondlastpoint, thirdpoint, ma);
    GenerateNarrative(lastpoint, secondlastpoint, thirdpoint, ma);
}

//string WhatHappend(){}
//
//string WhatisHappening(){}
//
//string WhatwillHappen(){}


//============================================================
// BIAS
//============================================================
string SetBias(const ContinuousCandleGroup &lastpoint,
const ContinuousCandleGroup &secondlastpoint,
const ContinuousCandleGroup &thirdpoint,
marketanalysis &ma)
{
    if(lastpoint.levelstatus == "HL" && secondlastpoint.levelstatus == "HH")
    {
        ma.bias = "Bullish";
    }
    else if(lastpoint.levelstatus == "LH" && secondlastpoint.levelstatus == "LL")
    {
        ma.bias = "Bearish";
    }
    else
    {
        // No clean HH/HL or LL/LH sequence yet -> don't force a side.
        ma.bias = "Neutral";
    }
    return ma.bias;
}

//============================================================
// PHASE
//============================================================
string SetPhase(const ContinuousCandleGroup &lastpoint,
const ContinuousCandleGroup &secondlastpoint,
const ContinuousCandleGroup &thirdpoint,
marketanalysis &ma)
{
    // Phase describes where price sits in the broader cycle:
    // Trending / Reversal / Consolidation / Accumulation-Distribution.

    bool sameDirection = (lastpoint.direction == secondlastpoint.direction);
    bool directionFlip = (lastpoint.direction != secondlastpoint.direction &&
    secondlastpoint.direction == thirdpoint.direction);

    if(ma.bias == "Neutral")
    {
        ma.phase = "Consolidation";
    }
    else if(directionFlip)
    {
        ma.phase = "Reversal";
    }
    else if(sameDirection)
    {
        ma.phase = "Trending";
    }
    else
    {
        ma.phase = "Pullback";
    }

    return ma.phase;
}

//============================================================
// MOMENTUM
//============================================================
string GetMomentum(const ContinuousCandleGroup &lastpoint,
const ContinuousCandleGroup &secondlastpoint,
const ContinuousCandleGroup &thirdpoint,
const string bias)
{
    // NOTE: bias is now passed in (read-only) instead of being
    // hardcoded to "Neutral" and overwriting ma.bias. This was the
    // bug in the original version: it silently wiped out whatever
    // SetBias() had already determined.
    string momentum = "";

    bool currentPush=
    (bias == "Bullish" && lastpoint.direction == "bullish") ||
    (bias == "Bearish" && lastpoint.direction == "bearish");

    bool previousPush=
    (bias == "Bullish" && secondlastpoint.direction == "bullish") ||
    (bias == "Bearish" && secondlastpoint.direction == "bearish");

    bool thirdPush=
    (bias == "Bullish" && thirdpoint.direction == "bullish") ||
    (bias == "Bearish" && thirdpoint.direction == "bearish");

    if(bias == "Neutral")
    {
        momentum = "Flat";
    }
    else if(currentPush)
    {
        if(previousPush && thirdPush)
        momentum = "Strong Push";
        else if(previousPush)
        momentum = "Weak Push 2";
        else
        momentum = "Weak Push";
    }
    else
    {
        if(!previousPush && !thirdPush)
        momentum = "Strong Pull";
        else if(!previousPush)
        momentum = "Weak Pull 2";
        else
        momentum = "Weak Pull";
    }

    return momentum;
}

string SetMomentum(const ContinuousCandleGroup &lastpoint,
const ContinuousCandleGroup &secondlastpoint,
const ContinuousCandleGroup &thirdpoint,
marketanalysis &ma)
{
    // ma.bias is already set by SetBias() at this point — use it,
    // don't recompute/reset it.
    ma.momentum = GetMomentum(lastpoint, secondlastpoint, thirdpoint, ma.bias);
    return ma.momentum;
}

//============================================================
// STRUCTURE
//============================================================
string SetStructure(const ContinuousCandleGroup &lastpoint,
const ContinuousCandleGroup &secondlastpoint,
const ContinuousCandleGroup &thirdpoint,
marketanalysis &ma)
{
    if(lastpoint.levelstatus == "HH" && secondlastpoint.levelstatus == "HL")
    ma.structure = "Higher Highs / Higher Lows";
    else if(lastpoint.levelstatus == "LL" && secondlastpoint.levelstatus == "LH")
    ma.structure = "Lower Highs / Lower Lows";
    else if(lastpoint.levelstatus == "HL" && secondlastpoint.levelstatus == "LH")
    ma.structure = "Possible Bullish Shift(BOS)";
    else if(lastpoint.levelstatus == "LH" && secondlastpoint.levelstatus == "HL")
    ma.structure = "Possible Bearish Shift(BOS)";
    else
    ma.structure = "Range - Bound";

    // Track the key swing levels that define current structure.
    ArrayResize(ma.levels, 4);
    ma.levels[0] = "HH: " + DoubleToString(lastpoint.highesthigh, _Digits);
    ma.levels[1] = "HL: " + DoubleToString(lastpoint.highestclose, _Digits);
    ma.levels[2] = "LL: " + DoubleToString(lastpoint.lowestlow, _Digits);
    ma.levels[3] = "LH: " + DoubleToString(lastpoint.lowestclose, _Digits);

    return ma.structure;
}

//============================================================
// LIQUIDITY
//============================================================
string SetLiquidity(const ContinuousCandleGroup &lastpoint,
const ContinuousCandleGroup &secondlastpoint,
const ContinuousCandleGroup &thirdpoint,
marketanalysis &ma)
{
    // Did the latest group sweep the prior swing's liquidity
    // (take out the high/low) and then fail to close beyond it?
    bool sweptHigh = (lastpoint.high > secondlastpoint.highesthigh &&
    lastpoint.close < secondlastpoint.highesthigh);
    bool sweptLow = (lastpoint.low < secondlastpoint.lowestlow &&
    lastpoint.close > secondlastpoint.lowestlow);

    if(sweptHigh)
    ma.liquidity = "Buy - Side Liquidity Swept";
    else if(sweptLow)
    ma.liquidity = "Sell - Side Liquidity Swept";
    else if(lastpoint.high >= secondlastpoint.highesthigh)
    ma.liquidity = "Approaching Buy - Side Liquidity";
    else if(lastpoint.low <= secondlastpoint.lowestlow)
    ma.liquidity = "Approaching Sell - Side Liquidity";
    else
    ma.liquidity = "No Liquidity Event";

    return ma.liquidity;
}

//============================================================
// VOLATILITY
//============================================================
string SetVolatility(const ContinuousCandleGroup &lastpoint,
const ContinuousCandleGroup &secondlastpoint,
const ContinuousCandleGroup &thirdpoint,
marketanalysis &ma)
{
    double currentRange = lastpoint.high - lastpoint.low;
    double previousRange = secondlastpoint.high - secondlastpoint.low;

    if(previousRange <= 0)
    {
        ma.volatility = "Undefined";
        return ma.volatility;
    }

    double ratio = currentRange / previousRange;

    if(ratio >= 1.3)
    ma.volatility = "Expanding";
    else if(ratio <= 0.7)
    ma.volatility = "Contracting";
    else
    ma.volatility = "Stable";

    return ma.volatility;
}

//============================================================
// CANDLE PATTERN
//============================================================
string SetCandles(const ContinuousCandleGroup &lastpoint,
const ContinuousCandleGroup &secondlastpoint,
const ContinuousCandleGroup &thirdpoint,
marketanalysis &ma)
{
    double body = MathAbs(lastpoint.close - lastpoint.open);
    double prevBody = MathAbs(secondlastpoint.close - secondlastpoint.open);
    double range = lastpoint.high - lastpoint.low;

    bool isEngulfing=
    (lastpoint.direction != secondlastpoint.direction) &&
    (body > prevBody) &&
    ((lastpoint.direction == "bullish" && lastpoint.close > secondlastpoint.open && lastpoint.open < secondlastpoint.close) ||
    (lastpoint.direction == "bearish" && lastpoint.close < secondlastpoint.open && lastpoint.open > secondlastpoint.close));

    bool isDoji = (range > 0 && body / range < 0.1);

    ArrayResize(ma.patterntext, 0);

    if(isEngulfing)
    {
        ma.candlePattern = (lastpoint.direction == "bullish") ? "Bullish Engulfing" : "Bearish Engulfing";
        ArrayResize(ma.patterntext, 1);
        ma.patterntext[0] = ma.candlePattern + " detected at group " + IntegerToString(lastpoint.groupid);
    }
    else if(isDoji)
    {
        ma.candlePattern = "Doji / Indecision";
    }
    else if(range > 0 && body / range > 0.7)
    {
        ma.candlePattern = (lastpoint.direction == "bullish") ? "Strong Bullish Candle" : "Strong Bearish Candle";
    }
    else
    {
        ma.candlePattern = "No Clear Pattern";
    }

    return ma.candlePattern;
}




//============================================================
// STRENGTH / SCORE
//============================================================
string SetStrength(
const ContinuousCandleGroup &lastpoint,
const ContinuousCandleGroup &secondlastpoint,
const ContinuousCandleGroup &thirdpoint,
marketanalysis &ma
)
{
    int score = 0;

    //============================================================
    // BIAS
    //============================================================
    if(ma.bias == "Bullish")
    {
        score = score + 1;
    }

    if(ma.bias == "Bearish")
    {
        score = score - 1;
    }


    //============================================================
    // MOMENTUM
    //============================================================
    if(StringFind(ma.momentum, "Strong") >= 0)
    {
        if(ma.bias == "Bullish")
        {
            score = score + 2;
        }

        if(ma.bias == "Bearish")
        {
            score = score - 2;
        }
    }

    if(StringFind(ma.momentum, "Weak") >= 0)
    {
        if(ma.bias == "Bullish")
        {
            score = score + 1;
        }

        if(ma.bias == "Bearish")
        {
            score = score - 1;
        }
    }


    //============================================================
    // STRUCTURE
    //============================================================
    if(ma.structure == "Higher Highs / Higher Lows")
    {
        score = score + 2;
    }

    if(ma.structure == "Lower Highs / Lower Lows")
    {
        score = score - 2;
    }


    //============================================================
    // LIQUIDITY
    //============================================================
    if(ma.liquidity == "Buy - Side Liquidity Swept")
    {
        score = score + 1;
    }

    if(ma.liquidity == "Sell - Side Liquidity Swept")
    {
        score = score - 1;
    }


    //============================================================
    // VOLATILITY
    //============================================================
    if(ma.volatility == "Expanding")
    {
        if(ma.bias == "Bullish")
        {
            score = score + 1;
        }

        if(ma.bias == "Bearish")
        {
            score = score - 1;
        }
    }


    //============================================================
    // STORE SCORE
    //============================================================
    ma.score = score;


    //============================================================
    // DETERMINE STRENGTH
    //============================================================
    int absScore = MathAbs(score);

    if(absScore >= 5)
    {
        ma.strength = "Strong";
    }
    else if(absScore >= 2)
    {
        ma.strength = "Moderate";
    }
    else
    {
        ma.strength = "Weak";
    }


    return ma.strength;
}
//============================================================
// NARRATIVE
//============================================================
string GenerateNarrative(
const ContinuousCandleGroup &lastpoint,
const ContinuousCandleGroup &secondlastpoint,
const ContinuousCandleGroup &thirdpoint,
marketanalysis &ma
)
{
    string text = "";

    //============================================================
    // BIAS
    //============================================================
    text = text + "Bias: " + ma.bias + " | ";


    //============================================================
    // PHASE
    //============================================================
    text = text + "Phase: " + ma.phase + " | ";


    //============================================================
    // MOMENTUM
    //============================================================
    text = text + "Momentum: " + ma.momentum + " | ";


    //============================================================
    // STRUCTURE
    //============================================================
    text = text + "Structure: " + ma.structure + " | ";


    //============================================================
    // LIQUIDITY
    //============================================================
    text = text + "Liquidity: " + ma.liquidity + " | ";


    //============================================================
    // VOLATILITY
    //============================================================
    text = text + "Volatility: " + ma.volatility + " | ";


    //============================================================
    // CANDLE PATTERN
    //============================================================
    text = text + "Candle: " + ma.candlePattern + " | ";


    //============================================================
    // STRENGTH
    //============================================================
    text = text + "Strength: " + ma.strength;


    //============================================================
    // SCORE
    //============================================================
    text = text + " (score " + IntegerToString(ma.score) + ")";


    //============================================================
    // STORE NARRATIVE
    //============================================================
    ma.narrative = text;


    return ma.narrative;
}
