
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

