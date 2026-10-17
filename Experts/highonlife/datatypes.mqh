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


};

rawdata fourhourrawdata[], onehourrawdata[], fifteenminrawdata[], fiveminrawdata[], oneminrawdata[];