void DrawGroups(ContinuousCandleGroup &groups[])
{
    for(int i = 0; i < ArraySize(groups); i++)
    {
       
        if(groups[i].direction == "bullish")
        {
            string name = "grp_" + IntegerToString(i);
            ObjectDelete(0, name);

            double price = groups[i].highesthigh;
            datetime time = groups[i].highesthightime;

            int shift = iBarShift(_Symbol, _Period, time, true);
            if(shift < 0) continue;

            datetime aligned_time = iTime(_Symbol, _Period, shift);

            if(!ObjectCreate(0, name, OBJ_TEXT, 0, aligned_time, price))
            continue;

            ObjectSetString(0, name, OBJPROP_TEXT, groups[i].levelstatus);
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
            ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
        }
        else if(groups[i].direction == "bearish")
        {
            string name = "grp_" + IntegerToString(i);
            ObjectDelete(0, name);

            double price = groups[i].lowestlow;
            datetime time = groups[i].lowestlowtime;

            int shift = iBarShift(_Symbol, _Period, time, true);
            if(shift < 0) continue;

            datetime aligned_time = iTime(_Symbol, _Period, shift);

            if(!ObjectCreate(0, name, OBJ_TEXT, 0, aligned_time, price))
            continue;

            ObjectSetString(0, name, OBJPROP_TEXT, groups[i].levelstatus);
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
            ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
        }
    }
}
void ClearGroups()
{
    int total = ObjectsTotal(0);

    for(int i = total - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i);

      // delete only your group objects
        if(StringFind(name, "grp_") == 0)
        {
            ObjectDelete(0, name);
        }
    }
}