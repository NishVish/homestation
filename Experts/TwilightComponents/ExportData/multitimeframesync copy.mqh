// ==============================
// JSON EXPORT HELPERS (SAFE ADD-ON)
// ==============================

string Quote(string s)
{
    return "\"" + s + "\"";
}

string RawToJSON(const rawdata &r)
{
    string json = "{";

    json += "\"time\":" + IntegerToString((long)r.time) + ",";
    json += "\"open\":" + DoubleToString(r.open, 5) + ",";
    json += "\"high\":" + DoubleToString(r.high, 5) + ",";
    json += "\"low\":" + DoubleToString(r.low, 5) + ",";
    json += "\"close\":" + DoubleToString(r.close, 5) + ",";
    json += "\"direction\":" + Quote(r.direction) + ",";
    json += "\"groupid\":" + IntegerToString(r.groupid);

    json += "}";
    return json;
}

string AnalysisToJSON(const marketanalysis &a)
{
    string json = "{";

    json += "\"bias\":" + Quote(a.bias) + ",";
    json += "\"phase\":" + Quote(a.phase) + ",";
    json += "\"momentum\":" + Quote(a.momentum) + ",";
    json += "\"candlePattern\":" + Quote(a.candlePattern) + ",";
    json += "\"atr\":" + Quote(a.atr) + ",";
    json += "\"rsi\":" + Quote(a.rsi);

    json += "}";
    return json;
}

string MultitimeframeToJSON(const MultitimeframeSync &m)
{
    string json = "[";

    // 15m (lowest)
    json += "{";
    json += "\"tf\":\"15m\",";
    json += "\"basic\":" + RawToJSON(m.lowesttf.basicdata) + ",";
    json += "\"analysis\":" + AnalysisToJSON(m.lowesttf.analysis);
    json += "},";

    // 1h (middle)
    json += "{";
    json += "\"tf\":\"1h\",";
    json += "\"basic\":" + RawToJSON(m.middletf.basicdata) + ",";
    json += "\"analysis\":" + AnalysisToJSON(m.middletf.analysis);
    json += "},";

    // 4h (highest)
    json += "{";
    json += "\"tf\":\"4h\",";
    json += "\"basic\":" + RawToJSON(m.highesttf.basicdata) + ",";
    json += "\"analysis\":" + AnalysisToJSON(m.highesttf.analysis);
    json += "}";

    json += "]";

    return json;
}

// ==============================
// FILE EXPORT FUNCTION
// ==============================

void SaveMultitimeframeSnapshotJSON(const MultitimeframeSync &m)
{
    string json = MultitimeframeToJSON(m);

    int handle = FileOpen("multitimeframe_snapshot.json",
                          FILE_WRITE | FILE_TXT | FILE_ANSI);

    if(handle != INVALID_HANDLE)
    {
        FileWriteString(handle, json);
        FileClose(handle);
    }
}