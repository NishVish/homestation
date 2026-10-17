// ============================================================
// JSON EXPORT
// ============================================================

// ------------------------------------------------------------
// Your existing structures
// ------------------------------------------------------------

// ------------------------------------------------------------
// JSON escaping
// ------------------------------------------------------------

string JsonEscape(string value)
{
    StringReplace(value, "\\","\\\\");
    StringReplace(value, "\"","\\\"");
    StringReplace(value, "\r","\\r");
    StringReplace(value, "\n","\\n");
    StringReplace(value, "\t","\\t");

    return value;
}


// ------------------------------------------------------------
// Convert datetime to JSON string
// ------------------------------------------------------------

string JsonTime(datetime value)
{
    return "\"" +
    TimeToString(
    value,
    TIME_DATE | TIME_SECONDS
    )
    + "\"";
}


// ------------------------------------------------------------
// RAW DATA → JSON
// ------------------------------------------------------------

string RawDataToJson(rawdata &data[])
{
    string json = "[";

    int total = ArraySize(data);

    for(int i = 0; i < total; i++)
    {
        if(i > 0)
        json += ",";

        json += " {";

            json += "\"time\":" +
            JsonTime(data[i].time) + ",";

            json += "\"open\":" +
            DoubleToString(data[i].open, _Digits) + ",";

            json += "\"high\":" +
            DoubleToString(data[i].high, _Digits) + ",";

            json += "\"low\":" +
            DoubleToString(data[i].low, _Digits) + ",";

            json += "\"close\":" +
            DoubleToString(data[i].close, _Digits) + ",";

            json += "\"direction\":\"" +
            JsonEscape(data[i].direction) + "\",";

            json += "\"groupid\":" +
            IntegerToString(data[i].groupid) + ",";

            json += "\"range\":" +
            DoubleToString(data[i].range, _Digits) + ",";

            json += "\"body\":" +
            DoubleToString(data[i].body, _Digits) + ",";

            json += "\"upperwick\":" +
            DoubleToString(data[i].upperwick, _Digits) + ",";

            json += "\"lowerwick\":" +
            DoubleToString(data[i].lowerwick, _Digits) + ",";

            json += "\"bodyratio\":" +
            DoubleToString(data[i].bodyratio, 8) + ",";

            json += "\"upperwickratio\":" +
            DoubleToString(data[i].upperwickratio, 8) + ",";

            json += "\"lowerwickratio\":" +
            DoubleToString(data[i].lowerwickratio, 8) + ",";

            json += "\"momentum\":\"" +
            JsonEscape(data[i].momentum) + "\"";

            json += "}";
        }

        json += "]";

        return json;
    }


// ------------------------------------------------------------
// GROUP DATA → JSON
// ------------------------------------------------------------

    string GroupDataToJson(ContinuousCandleGroup &data[])
    {
        string json = "[";

        int total = ArraySize(data);

        for(int i = 0; i < total; i++)
        {
            if(i > 0)
            json += ",";

            json += " {";

                json += "\"open\":" +
                DoubleToString(data[i].open, _Digits) + ",";

                json += "\"high\":" +
                DoubleToString(data[i].high, _Digits) + ",";

                json += "\"low\":" +
                DoubleToString(data[i].low, _Digits) + ",";

                json += "\"close\":" +
                DoubleToString(data[i].close, _Digits) + ",";


                json += "\"highesthigh\":" +
                DoubleToString(data[i].highesthigh, _Digits) + ",";

                json += "\"highesthightime\":" +
                JsonTime(data[i].highesthightime) + ",";


                json += "\"highestclose\":" +
                DoubleToString(data[i].highestclose, _Digits) + ",";

                json += "\"highestclosetime\":" +
                JsonTime(data[i].highestclosetime) + ",";


                json += "\"secondhighesthigh\":" +
                DoubleToString(data[i].secondhighesthigh, _Digits) + ",";

                json += "\"secondhighesthightime\":" +
                JsonTime(data[i].secondhighesthightime) + ",";


                json += "\"secondhighestclose\":" +
                DoubleToString(data[i].secondhighestclose, _Digits) + ",";

                json += "\"secondhighestclosetime\":" +
                JsonTime(data[i].secondhighestclosetime) + ",";


                json += "\"lowestlow\":" +
                DoubleToString(data[i].lowestlow, _Digits) + ",";

                json += "\"lowestlowtime\":" +
                JsonTime(data[i].lowestlowtime) + ",";


                json += "\"lowestclose\":" +
                DoubleToString(data[i].lowestclose, _Digits) + ",";

                json += "\"lowestclosetime\":" +
                JsonTime(data[i].lowestclosetime) + ",";


                json += "\"secondlowestlow\":" +
                DoubleToString(data[i].secondlowestlow, _Digits) + ",";

                json += "\"secondlowestlowtime\":" +
                JsonTime(data[i].secondlowestlowtime) + ",";


                json += "\"secondlowestclose\":" +
                DoubleToString(data[i].secondlowestclose, _Digits) + ",";

                json += "\"secondlowestclosetime\":" +
                JsonTime(data[i].secondlowestclosetime) + ",";


                json += "\"direction\":\"" +
                JsonEscape(data[i].direction) + "\",";

                json += "\"groupid\":" +
                IntegerToString(data[i].groupid) + ",";

                json += "\"count\":" +
                IntegerToString(data[i].count) + ",";

                json += "\"levelstatus\":\"" +
                JsonEscape(data[i].levelstatus) + "\"";

                json += "}";
            }

            json += "]";

            return json;
        }


// ------------------------------------------------------------
// MARKET ANALYSIS
//
// Placeholder for your future market-analysis structure.
// For now this can be an empty object.
//
// Later you can add your analysis struct here.
// ------------------------------------------------------------

        string MarketAnalysisToJson()
        {
            return " {}";
            }


// ------------------------------------------------------------
// Create ONE complete sample
// ------------------------------------------------------------

            string CreateSampleJson(
            rawdata &raw[],
            ContinuousCandleGroup &groups[]
            )
            {
                string json = " {";

                    json += "\"raw_data\":";
                    json += RawDataToJson(raw);
                    json += ",";

                    json += "\"continuous_candle_group\":";
                    json += GroupDataToJson(groups);
                    json += ",";

                    json += "\"market_analysis\":";
                    json += MarketAnalysisToJson();

                    json += "}";

                    return json;
                }


// ============================================================
// EXPORT SAMPLE
// ============================================================

                void ExportMLData(
                rawdata &raw[],
                ContinuousCandleGroup &groups[]
                )
                {
                    string filename =
                    _Symbol + "_" +
                    EnumToString(PERIOD_CURRENT) +
                    "_ml_dataset.json";


                    Print("========================================");
                    Print("ExportMLData()");
                    Print("Filename: [", filename, "]");
                    Print("Raw rows: ", ArraySize(raw));
                    Print("Groups: ", ArraySize(groups));
                    Print("========================================");


                    string new_sample =
                    CreateSampleJson(raw, groups);


    // --------------------------------------------------------
    // Read existing file
    // --------------------------------------------------------

                    string existing = "";

                    if(FileIsExist(filename))
                    {
                        int read_handle = FileOpen(
                        filename,
                        FILE_READ |
                        FILE_TXT |
                        FILE_ANSI
                        );

                        if(read_handle != INVALID_HANDLE)
                        {
                            while(!FileIsEnding(read_handle))
                            {
                                existing += FileReadString(read_handle);

                                if(!FileIsEnding(read_handle))
                                existing += "\n";
                            }

                            FileClose(read_handle);
                        }
                    }


    // --------------------------------------------------------
    // First export
    // --------------------------------------------------------

                    string final_json;


                    if(StringLen(existing) == 0)
                    {
                        final_json = " {\n";
                            final_json += " \"samples\": [\n";
                            final_json += " ";
                            final_json += new_sample;
                            final_json += "\n";
                            final_json += " ]\n";
                            final_json += "}";
                        }

    // --------------------------------------------------------
    // Existing dataset
    // --------------------------------------------------------

                        else
                        {
        // Remove final whitespace
                            StringTrimRight(existing);


        // Find closing array/object
                            int samples_end = StringFind(
                            existing,
                            "]\n}"
                            );


                            if(samples_end < 0)
                            {
                                samples_end = StringFind(
                                existing,
                                "]}"
                                );
                            }


                            if(samples_end < 0)
                            {
                                Print("ERROR: Existing JSON structure is invalid.");
                                return;
                            }


        // Everything before the closing ] is retained.
                            string before = StringSubstr(
                            existing,
                            0,
                            samples_end
                            );


        // Add new sample at the TOP of samples array
                            final_json = before;

                            final_json += "\n ";
                            final_json += new_sample;
                            final_json += ", \n ";


        // Remove the old opening portion so we can insert
        // the previous samples after the new one.
        //
        // Find:
        // {
        //   "samples": [
        //

                            int array_start = StringFind(
                            existing,
                            "["
                            );


                            if(array_start < 0)
                            {
                                Print("ERROR: samples array not found.");
                                return;
                            }


                            string old_samples = StringSubstr(
                            existing,
                            array_start + 1,
                            samples_end - array_start - 1
                            );


                            StringTrimLeft(old_samples);
                            StringTrimRight(old_samples);


                            final_json =
                            " {\n"
                                " \"samples\": [\n"
                                " "
                                + new_sample;


                                if(StringLen(old_samples) > 0)
                                {
                                    final_json += ", \n ";
                                    final_json += old_samples;
                                }


                                final_json +=
                                "\n"
                                " ]\n"
                                "}";
                            }


    // --------------------------------------------------------
    // Write complete JSON file
    // --------------------------------------------------------

                            ResetLastError();


                            int handle = FileOpen(
                            filename,
                            FILE_WRITE |
                            FILE_TXT |
                            FILE_ANSI
                            );


                            if(handle == INVALID_HANDLE)
                            {
                                Print("JSON FileOpen FAILED");
                                Print("Error: ", GetLastError());
                                return;
                            }


                            FileWriteString(
                            handle,
                            final_json
                            );


                            FileClose(handle);


                            Print("JSON export completed");
                            Print("Raw rows: ", ArraySize(raw));
                            Print("Groups: ", ArraySize(groups));
                            Print("File: [", filename, "]");
                        }
