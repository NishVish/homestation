// void annotateleveldata(ContinuousCandleGroup &data[])
// {
//     int total = ArraySize(data);
//     if(total == 0)
//     return;

//     ContinuousCandleGroup bullish[], bearish[];
//     int bullishIdx[], bearishIdx[];

//     int b = 0, s = 0;

// // collect last 4 bullish and bearish + keep original indices
//     for(int i = total - 1; i >= 0; i--)
//     {
//         if(data[i].direction == "bullish" && b < 4)
//         {
//             ArrayResize(bullish, b + 1);
//             ArrayResize(bullishIdx, b + 1);

//             bullish[b] = data[i];
//             bullishIdx[b] = i;
//             b++;
//         }
//         else
//         if(data[i].direction == "bearish" && s < 4)
//         {
//             ArrayResize(bearish, s + 1);
//             ArrayResize(bearishIdx, s + 1);

//             bearish[s] = data[i];
//             bearishIdx[s] = i;
//             s++;
//         }

//         if(b == 4 && s == 4)
//         break;
//     }

// // reverse to chronological order
//     ArraySetAsSeries(bullish, false);
//     ArraySetAsSeries(bearish, false);

// // --- Bullish ---
//     if(ArraySize(bullish) > 0)
//     data[bullishIdx[0]].levelstatus = "NA";

//     for(int i = 1; i < ArraySize(bullish); i++)
//     {
//         double currClose = bullish[i].highestclose;
//         double prevClose = bullish[i - 1].highestclose;
//         double currHigh = bullish[i].highesthigh;
//         double prevHigh = bullish[i - 1].highesthigh;

//         string status;

//         if(prevClose < currClose && prevHigh < currClose)
//         status = "HH";
//         else
//         if(prevClose < currClose && prevHigh > currClose)
//         status = "FH";
//         else
//         if(prevClose > currClose)
//         status = "LH";
//         else
//         status = "NA";

//         data[bullishIdx[i]].levelstatus = status;
//     }

// // --- Bearish ---
//     if(ArraySize(bearish) > 0)
//     data[bearishIdx[0]].levelstatus = "NA";

//     for(int i = 1; i < ArraySize(bearish); i++)
//     {
//         double currClose = bearish[i].lowestclose;
//         double prevClose = bearish[i - 1].lowestclose;
//         double currLow = bearish[i].lowestlow;
//         double prevLow = bearish[i - 1].lowestlow;

//         string status;

//         if(prevClose > currClose && prevLow > currClose)
//         status = "LL";
//         else
//         if(prevClose > currClose && prevLow < currClose)
//         status = "FL";
//         else
//         if(prevClose < currClose)
//         status = "HL";
//         else
//         status = "NA";

//         data[bearishIdx[i]].levelstatus = status;
//     }
// }
