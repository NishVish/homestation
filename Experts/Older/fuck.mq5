#include "DisciplineComponents/engine.mqh"


struct AnalysisData
{
    int bias;
    int phase;
};


AnalysisData fourhour;
AnalysisData onehour;


//==================================================
// MAIN
//==================================================
void OnTick()
{
    Analysis();
}

void OnStart()
{
    
}



//==================================================
// ANALYSIS
//==================================================
void Analysis()
{
    fourhour = AnalysisProcess(PERIOD_M4);
    onehour = AnalysisProcess(PERIOD_H1);
}


//==================================================
// ANALYSIS PROCESS
//==================================================
AnalysisData AnalysisProcess(ENUM_TIMEFRAMES timeframe)
{
    AnalysisData thistimeframe;

    thistimeframe.bias = 0;
    thistimeframe.phase = 0;

    RawData(timeframe);

     
    ExportCandlesToCSV("rawdata");
    

    if(ArraySize(rates) <= 0)
    return thistimeframe;

    SetCandleTypeAndID();
    ExportCandlesToCSV("datawithid");

    BuildGroupData(timeframe);

    LevelAnnotation();

    thistimeframe.bias = SingnalGernation();
    thistimeframe.phase = MomentumAnalysis();

    return thistimeframe;
}
