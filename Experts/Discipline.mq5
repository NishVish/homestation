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
    Signal();
    Execution();
}

void OnStart()
{
    
}



//==================================================
// ANALYSIS
//==================================================
void Analysis()
{
    fourhour = StructureX(PERIOD_M4);
    onehour = StructureX(PERIOD_H1);
}


void Signal()
{

    Buy
    Sell

}

//==================================================
// ANALYSIS PROCESS
//==================================================

bool StructureX(ENUM_TIMEFRAMES timeframe)
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

    leveldata[] = LevelAnnotation();
    Bias(leveldata);
    Phase(leveldata);
    Momentum();



    
}

string leveldata[];

 


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
