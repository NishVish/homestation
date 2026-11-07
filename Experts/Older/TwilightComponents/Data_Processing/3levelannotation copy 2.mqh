// void annotateleveldata(ContinuousCandleGroup &data[])
// {
    
//     ContinuousCandleGroup l1, l2, l3, l4, l5, l6, l7, l8;

//     l1 = data[0];
//     l2 = data[1];
//     l3 = data[2];
//     l4 = data[3];
//     l5 = data[4];
//     l6 = data[5];
//     l7 = data[6];
//     l8 = data[7];

//     if(l1.direction == "bullish")
//     {
//    //  l1 to l3 
//    //  l3 to l5
//    //  l5 to l7
//         if(l1.highestclose > l3.highestclose)
//         {
//             data[0].levelstatus = "HH";
          
//         }

//         else if(l1.highestclose < l3.highestclose)
//         {
//             data[0].levelstatus = "LH";
           
//         }

//         else {
//             l1.levelstatus = "Equal";
//         }

//         if(l3.higestclose > l5.higestclose) {
//             data[2].levelstatus = "HH";
//         }

//         else if(l3.higestclose < l5.higestclose) {
//             data[2].levelstatus = "LH";
//         }

//         else {
//             data[2].levelstatus = "Equal";
//         }

//         if(l5.higestclose > l7.higestclose)
//         {
//             data[4].levelstatus = "HH";
//         }

//         else if(l5.higestclose < l7.higestclose)
//         {
//             data[4].levelstatus = "LH";
//         }

//         else {
//             data[4].levelstatus = "Equal";
//         }
        

//       //   l2 to l4
//       //   l4 to l6
//       //   l6 to l8
    

//         if(l2.lowestclose > l4.lowestclose)
//         {
//             data[1].levelstatus = "LL";
//         }

//         else if(l2.lowestclose < l4.lowestclose)
//         {
//             data[1].levelstatus = "HL";
//         }

//         else {
//             data[1].levelstatus = "Equal";
//         }

//         if(l4.lowestclose > l6.lowestclose)
//         {
//             data[3].levelstatus = "LL";
//         }

//         else if(l4.lowestclose < l6.lowestclose)
//         {
//             data[3].levelstatus = "HL";
//         }

//         else {
//             data[3].levelstatus = "Equal";
//         }

//         if(l6.lowestclose > l8.lowestclose)
//         {
//             data[5].levelstatus = "LL";
//         }

//         else if(l6.lowestclose < l8.lowestclose)
//         {
//             data[5].levelstatus = "HL";
//         }

//         else {
//             data[5].levelstatus = "Equal";
//         }

//         if()
       

//     }






//     Print("now bullish");
//    //  Print(data[0]);
//     PrintGroupSingle(l1);
//    //  PrintGroupSingle(l2);
//    //  PrintGroupSingle(l3);
//    //  PrintGroupSingle(l4);
//    //  PrintGroupSingle(l5);
//    //  PrintGroupSingle(l6);
//    //  PrintGroupSingle(l7);
//    //  PrintGroupSingle(l8);
//    //  Print("now BEaisuh");
//    //  PrintGroups(bearish);
//    //  Print("now data");
//    //  PrintGroups(data);
// }

// void PrintGroupSingle(ContinuousCandleGroup &g, int index = 0)
// {
//     Print("Group #", index,
//     " HighestHigh: ", g.highesthigh,
//     " HighestHighTime: ", TimeToString(g.highesthightime),

//     " HighestClose: ", g.highestclose,
//     " HighestCloseTime: ", TimeToString(g.highestclosetime),

//     " SecondHighestHigh: ", g.secondhighesthigh,
//     " SecondHighestClose: ", g.secondhighestclose,

//     " LowestLow: ", g.lowestlow,
//     " LowestLowTime: ", TimeToString(g.lowestlowtime),

//     " LowestClose: ", g.lowestclose,
//     " LowestCloseTime: ", TimeToString(g.lowestclosetime),

//     " SecondLowestLow: ", g.secondlowestlow,
//     " SecondLowestClose: ", g.secondlowestclose,

//     " Direction: ", g.direction,
//     " Group ID: ", g.groupid,
//     " Count: ", g.count,
//     " Level: ", g.levelstatus
//     );
// }

// void PrintGroups(ContinuousCandleGroup &data[])
// {
//     for(int i = 0; i < ArraySize(data); i++)
//     {
//         Print("Group #", i,
//         " HighestHigh: ", data[i].highesthigh,
//         " HighestHighTime: ", TimeToString(data[i].highesthightime),

//         " HighestClose: ", data[i].highestclose,
//         " HighestCloseTime: ", TimeToString(data[i].highestclosetime),

//         " SecondHighestHigh: ", data[i].secondhighesthigh,
//         " SecondHighestClose: ", data[i].secondhighestclose,

//         " LowestLow: ", data[i].lowestlow,
//         " LowestLowTime: ", TimeToString(data[i].lowestlowtime),

//         " LowestClose: ", data[i].lowestclose,
//         " LowestCloseTime: ", TimeToString(data[i].lowestclosetime),

//         " SecondLowestLow: ", data[i].secondlowestlow,
//         " SecondLowestClose: ", data[i].secondlowestclose,

//         " Direction: ", data[i].direction,
//         " Group ID: ", data[i].groupid,
//         " Count: ", data[i].count,
//         " Level: ", data[i].levelstatus
//         );
//     }
// }