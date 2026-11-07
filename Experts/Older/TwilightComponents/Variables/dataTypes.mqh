// Raw Data Variables
MqlRates fourhour[], onehour[], fifteenmin[], fivemin[], onemin[];


// Custom Struct
struct rawdata
{
   datetime time;

   double open;
   double high;
   double low;
   double close;

   string direction;

   int groupid;

   double range;
   double body;

   double upperwick;
   double lowerwick;

   double bodyratio;
   double upperwickratio;
   double lowerwickratio;

   string momentum;
};

rawdata fourhourrawdata[], onehourrawdata[], fifteenminrawdata[], fiveminrawdata[], oneminrawdata[];

// Group Struct
struct ContinuousCandleGroup
{
    double open;
    double high;
    double low;
    double close;

    double highesthigh;
    datetime highesthightime;

    double highestclose;
    datetime highestclosetime;

    double secondhighesthigh;
    datetime secondhighesthightime;

    double secondhighestclose;
    datetime secondhighestclosetime;

    double lowestlow;
    datetime lowestlowtime;

    double lowestclose;
    datetime lowestclosetime;

    double secondlowestlow;
    datetime secondlowestlowtime;

    double secondlowestclose;
    datetime secondlowestclosetime;

    string direction;
    int groupid;
    int count;
    string levelstatus;
};

ContinuousCandleGroup fourhourgroupdata[], onehourgroupdata[], fifteenmingroupdata[];



struct marketanalysis
{
    string bias;
    string phase;
    string momentum;
    string structure;
    string volatility;
    string liquidity;
    string candlePattern;
    string strength;
    string narrative;
    string atr;
    string rsi;
    int score;
    string levels[];
    string patterntext[];
};
marketanalysis fourhourmarketAnalysis;
marketanalysis onehourmarketAnalysis;
marketanalysis fifteenminmarketAnalysis;



rawdata m15_first;
rawdata h1_first;
rawdata h4_first;



struct singletimeframealldata {
    rawdata basicdata;
    marketanalysis analysis;
};

singletimeframealldata fifteenminalldata;
singletimeframealldata onehouralldata;
singletimeframealldata fourhouralldata;

marketanalysis fifteenanalysis;
marketanalysis onehouranalysis;
marketanalysis fourhouranalysis;


struct MultitimeframeSync {
    singletimeframealldata highesttf;
    singletimeframealldata middletf;
    singletimeframealldata lowesttf;
};





