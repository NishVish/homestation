
string GetCSVHeader()
{
    string header = "";

header += "id,";
    // 4H Headers
    header += "4h_time,4h_open,4h_high,4h_low,4h_close,4h_dir,4h_group,4h_bias,4h_phase,4h_momentum,4h_pattern,4h_atr,4h_rsi,";
    
    // 1H Headers
    header += "1h_time,1h_open,1h_high,1h_low,1h_close,1h_dir,1h_group,1h_bias,1h_phase,1h_momentum,1h_pattern,1h_atr,1h_rsi,";
    
    // 15M Headers
    header += "15m_time,15m_open,15m_high,15m_low,15m_close,15m_dir,15m_group,15m_bias,15m_phase,15m_momentum,15m_pattern,15m_atr,15m_rsi,";
header += "analysis,action,takeprofit,stoploss,verified_id,result\n";
    return header;
}
string MultitimeframeToCSV(const MultitimeframeSync &m)
{
    static long uniformId = 0;
    uniformId++;

    string csv = "";

    csv += IntegerToString(uniformId) + ",";  // <-- 1,2,3,4...


    // ---------------- 4H DATA ----------------
    csv += TimeToString(m.highesttf.basicdata.time, TIME_DATE|TIME_MINUTES) + ",";
    csv += DoubleToString(m.highesttf.basicdata.open, 5) + ",";
    csv += DoubleToString(m.highesttf.basicdata.high, 5) + ",";
    csv += DoubleToString(m.highesttf.basicdata.low, 5) + ",";
    csv += DoubleToString(m.highesttf.basicdata.close, 5) + ",";
    csv += m.highesttf.basicdata.direction + ",";
    csv += IntegerToString(m.highesttf.basicdata.groupid) + ",";
    csv += m.highesttf.analysis.bias + ",";
    csv += m.highesttf.analysis.phase + ",";
    csv += m.highesttf.analysis.momentum + ",";
    csv += m.highesttf.analysis.candlePattern + ",";
    csv += m.highesttf.analysis.atr + ",";
    csv += m.highesttf.analysis.rsi + ",";

    // ---------------- 1H DATA ----------------
    csv += TimeToString(m.middletf.basicdata.time, TIME_DATE|TIME_MINUTES) + ",";
    csv += DoubleToString(m.middletf.basicdata.open, 5) + ",";
    csv += DoubleToString(m.middletf.basicdata.high, 5) + ",";
    csv += DoubleToString(m.middletf.basicdata.low, 5) + ",";
    csv += DoubleToString(m.middletf.basicdata.close, 5) + ",";
    csv += m.middletf.basicdata.direction + ",";
    csv += IntegerToString(m.middletf.basicdata.groupid) + ",";
    csv += m.middletf.analysis.bias + ",";
    csv += m.middletf.analysis.phase + ",";
    csv += m.middletf.analysis.momentum + ",";
    csv += m.middletf.analysis.candlePattern + ",";
    csv += m.middletf.analysis.atr + ",";
    csv += m.middletf.analysis.rsi + ",";

    // ---------------- 15M DATA ----------------
    csv += TimeToString(m.lowesttf.basicdata.time, TIME_DATE|TIME_MINUTES) + ",";
    csv += DoubleToString(m.lowesttf.basicdata.open, 5) + ",";
    csv += DoubleToString(m.lowesttf.basicdata.high, 5) + ",";
    csv += DoubleToString(m.lowesttf.basicdata.low, 5) + ",";
    csv += DoubleToString(m.lowesttf.basicdata.close, 5) + ",";
    csv += m.lowesttf.basicdata.direction + ",";
    csv += IntegerToString(m.lowesttf.basicdata.groupid) + ",";
    csv += m.lowesttf.analysis.bias + ",";
    csv += m.lowesttf.analysis.phase + ",";
    csv += m.lowesttf.analysis.momentum + ",";
    csv += m.lowesttf.analysis.candlePattern + ",";
    csv += m.lowesttf.analysis.atr + ",";
    csv += m.lowesttf.analysis.rsi+ ","; 
csv += "" + ","; //Ananlysis
csv += "" + ","; //action
csv += "" + ","; //takeprofit
csv += "" + ","; //stoploss
csv += ""; //verified_id

    csv += "\n";

    return csv;
    //header += "analysis,action,takeprofit,stoploss,verified_id,\n";
}



void SaveMultitimeframeSnapshotCSV(const MultitimeframeSync &m)
{
    int handle = FileOpen(
        "multitimeframe_snapshot.csv",
        FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI
    );

    if(handle != INVALID_HANDLE)
    {
        FileSeek(handle, 0, SEEK_END);
        
        // Change 'long' to 'ulong' to match FileTell's return type
        ulong fileSize = FileTell(handle);

        if(fileSize == 0)
        {
            FileWriteString(handle, GetCSVHeader());
        }

        string csv = MultitimeframeToCSV(m);
        FileWriteString(handle, csv);
        
        FileClose(handle);
    }
}