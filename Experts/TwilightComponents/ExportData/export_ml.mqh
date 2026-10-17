// ============================================================
// CSV EXPORT & FLATTENING
// ============================================================

// ------------------------------------------------------------
// CSV escaping for strings (wraps in quotes and escapes internal quotes)
// ------------------------------------------------------------
string CsvEscape(string value)
{
    StringReplace(value, "\"", "\"\"");
    return "\"" + value + "\"";
}

// ------------------------------------------------------------
// Convert datetime to CSV formatted string
// ------------------------------------------------------------
string CsvTime(datetime value)
{
    return "\"" + TimeToString(value, TIME_DATE | TIME_SECONDS) + "\"";
}



// ------------------------------------------------------------
// Build CSV Header (Only Time, Open, High, Low, Close, Direction)
// ------------------------------------------------------------
string BuildCsvHeader(rawdata &raw[], string prefix)
{
    string header = "";
    int rawTotal = ArraySize(raw);

    for(int i = 0; i < rawTotal; i++)
    {
        string idx = IntegerToString(i + 1);
        if(StringLen(header) > 0) header += ",";
        
        header += prefix + "_raw_time_" + idx + "," +
                  prefix + "_raw_open_" + idx + "," +
                  prefix + "_raw_high_" + idx + "," +
                  prefix + "_raw_low_" + idx + "," +
                  prefix + "_raw_close_" + idx + "," +
                  prefix + "_raw_direction_" + idx;
    }

    return header;
}

// ------------------------------------------------------------
// Build CSV Data Row (Only matching fields)
// ------------------------------------------------------------
string BuildCsvRow(rawdata &raw[])
{
    string row = "";
    int rawTotal = ArraySize(raw);

    for(int i = 0; i < rawTotal; i++)
    {
        if(StringLen(row) > 0) row += ",";

        row += CsvTime(raw[i].time) + "," +
               DoubleToString(raw[i].open, _Digits) + "," +
               DoubleToString(raw[i].high, _Digits) + "," +
               DoubleToString(raw[i].low, _Digits) + "," +
               DoubleToString(raw[i].close, _Digits) + "," +
               CsvEscape(raw[i].direction);
    }

    return row;
}




// ------------------------------------------------------------
// Master Export Function (Updated signature & calls)
// ------------------------------------------------------------
void ExportMLDataCSV(rawdata &raw_4hour[], rawdata &raw_1hour[], rawdata &raw_15min[] , rawdata &raw_5min[] , rawdata &raw_1min[] )
{
   string filename = _Symbol + "_" + EnumToString(PERIOD_CURRENT) + "_ml_dataset.csv";

   Print("========================================");
   Print("ExportMLDataCSV()");
   Print("Filename: [", filename, "]");
   Print("========================================");

   bool fileExists = FileIsExist(filename);
   
   string csvRow = 
   //BuildCsvRow(raw_4hour) + "," +
   //                BuildCsvRow(raw_1hour) + "," +
                   BuildCsvRow(raw_15min) + "," +
                   BuildCsvRow(raw_5min)  + "," +
                   BuildCsvRow(raw_1min);
                   
   string fileContent = "";
   string header = 
   //BuildCsvHeader(raw_4hour, "4hour") + "," +
   //                BuildCsvHeader(raw_1hour, "1hour") + "," +
                   BuildCsvHeader(raw_15min, "15min") + "," +
                   BuildCsvHeader(raw_5min,  "5min")  + "," +
                   BuildCsvHeader(raw_1min,  "1min");

   if(!fileExists)
   {
      fileContent = header + "\n" + csvRow;
   }
   else
   {
      int read_handle = FileOpen(filename, FILE_READ | FILE_TXT | FILE_ANSI);
      string existingData = "";
      bool headerSkipped = false;
      
      if(read_handle != INVALID_HANDLE)
      {
         while(!FileIsEnding(read_handle))
         {
            string line = FileReadString(read_handle);
            if(!headerSkipped)
            {
               headerSkipped = true;
               continue;
            }
            
            if(StringLen(line) > 0)
            {
               if(StringLen(existingData) > 0)
                  existingData += "\n";
               existingData += line;
            }
         }
         FileClose(read_handle);
      }

      StringTrimRight(existingData);
      
      fileContent = header + "\n" + csvRow;
      if(StringLen(existingData) > 0)
      {
         fileContent += "\n" + existingData;
      }
   }

   ResetLastError();
   int handle = FileOpen(filename, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      Print("CSV FileOpen FAILED. Error: ", GetLastError());
      return;
   }

   FileWriteString(handle, fileContent);
   FileClose(handle);

   Print("CSV export completed successfully.");
}


//
//// ------------------------------------------------------------
//// Build CSV Header (Run once when file doesn't exist)
//// ------------------------------------------------------------
//string BuildCsvHeader(rawdata &raw[], ContinuousCandleGroup &groups[])
//{
//    string header = "";
//    int rawTotal = ArraySize(raw);
//    int groupTotal = ArraySize(groups);
//
//    // 1. Raw Data Headers
//    for(int i = 0; i < rawTotal; i++)
//    {
//        string idx = IntegerToString(i + 1);
//        if(StringLen(header) > 0) header += ",";
//        
//        header += "raw_time_" + idx + "," +
//                  "raw_open_" + idx + "," +
//                  "raw_high_" + idx + "," +
//                  "raw_low_" + idx + "," +
//                  "raw_close_" + idx + "," +
//                  "raw_direction_" + idx + "," +
//                  "raw_groupid_" + idx + "," +
//                  "raw_range_" + idx + "," +
//                  "raw_body_" + idx + "," +
//                  "raw_upperwick_" + idx + "," +
//                  "raw_lowerwick_" + idx + "," +
//                  "raw_bodyratio_" + idx + "," +
//                  "raw_upperwickratio_" + idx + "," +
//                  "raw_lowerwickratio_" + idx + "," +
//                  "raw_momentum_" + idx;
//    }
//
//    // 2. Group Data Headers
//    for(int j = 0; j < groupTotal; j++)
//    {
//        string idx = IntegerToString(j + 1);
//        if(StringLen(header) > 0) header += ",";
//        
//        header += "group_open_" + idx + "," +
//                  "group_high_" + idx + "," +
//                  "group_low_" + idx + "," +
//                  "group_close_" + idx + "," +
//                  "group_highesthigh_" + idx + "," +
//                  "group_highesthightime_" + idx + "," +
//                  "group_highestclose_" + idx + "," +
//                  "group_highestclosetime_" + idx + "," +
//                  "group_secondhighesthigh_" + idx + "," +
//                  "group_secondhighesthightime_" + idx + "," +
//                  "group_secondhighestclose_" + idx + "," +
//                  "group_secondhighestclosetime_" + idx + "," +
//                  "group_lowestlow_" + idx + "," +
//                  "group_lowestlowtime_" + idx + "," +
//                  "group_lowestclose_" + idx + "," +
//                  "group_lowestclosetime_" + idx + "," +
//                  "group_secondlowestlow_" + idx + "," +
//                  "group_secondlowestlowtime_" + idx + "," +
//                  "group_secondlowestclose_" + idx + "," +
//                  "group_secondlowestclosetime_" + idx + "," +
//                  "group_direction_" + idx + "," +
//                  "group_groupid_" + idx + "," +
//                  "group_count_" + idx + "," +
//                  "group_levelstatus_" + idx;
//    }
//
//    return header;
//}
//
//
//// ------------------------------------------------------------
//// Build CSV Data Row (Flattened single sample row)
//// ------------------------------------------------------------
//string BuildCsvRow(rawdata &raw[], ContinuousCandleGroup &groups[])
//{
//    string row = "";
//    int rawTotal = ArraySize(raw);
//    int groupTotal = ArraySize(groups);
//
//    // 1. Raw Data Values
//    for(int i = 0; i < rawTotal; i++)
//    {
//        if(StringLen(row) > 0) row += ",";
//
//        row += CsvTime(raw[i].time) + "," +
//               DoubleToString(raw[i].open, _Digits) + "," +
//               DoubleToString(raw[i].high, _Digits) + "," +
//               DoubleToString(raw[i].low, _Digits) + "," +
//               DoubleToString(raw[i].close, _Digits) + "," +
//               CsvEscape(raw[i].direction) + "," +
//               IntegerToString(raw[i].groupid) + "," +
//               DoubleToString(raw[i].range, _Digits) + "," +
//               DoubleToString(raw[i].body, _Digits) + "," +
//               DoubleToString(raw[i].upperwick, _Digits) + "," +
//               DoubleToString(raw[i].lowerwick, _Digits) + "," +
//               DoubleToString(raw[i].bodyratio, 8) + "," +
//               DoubleToString(raw[i].upperwickratio, 8) + "," +
//               DoubleToString(raw[i].lowerwickratio, 8) + "," +
//               CsvEscape(raw[i].momentum);
//    }
//
//    // 2. Group Data Values
//    for(int j = 0; j < groupTotal; j++)
//    {
//        if(StringLen(row) > 0) row += ",";
//
//        row += DoubleToString(groups[j].open, _Digits) + "," +
//               DoubleToString(groups[j].high, _Digits) + "," +
//               DoubleToString(groups[j].low, _Digits) + "," +
//               DoubleToString(groups[j].close, _Digits) + "," +
//               DoubleToString(groups[j].highesthigh, _Digits) + "," +
//               CsvTime(groups[j].highesthightime) + "," +
//               DoubleToString(groups[j].highestclose, _Digits) + "," +
//               CsvTime(groups[j].highestclosetime) + "," +
//               DoubleToString(groups[j].secondhighesthigh, _Digits) + "," +
//               CsvTime(groups[j].secondhighesthightime) + "," +
//               DoubleToString(groups[j].secondhighestclose, _Digits) + "," +
//               CsvTime(groups[j].secondhighestclosetime) + "," +
//               DoubleToString(groups[j].lowestlow, _Digits) + "," +
//               CsvTime(groups[j].lowestlowtime) + "," +
//               DoubleToString(groups[j].lowestclose, _Digits) + "," +
//               CsvTime(groups[j].lowestclosetime) + "," +
//               DoubleToString(groups[j].secondlowestlow, _Digits) + "," +
//               CsvTime(groups[j].secondlowestlowtime) + "," +
//               DoubleToString(groups[j].secondlowestclose, _Digits) + "," +
//               CsvTime(groups[j].secondlowestclosetime) + "," +
//               CsvEscape(groups[j].direction) + "," +
//               IntegerToString(groups[j].groupid) + "," +
//               IntegerToString(groups[j].count) + "," +
//               CsvEscape(groups[j].levelstatus);
//    }
//
//    return row;
//}
//
//// ============================================================
//// EXPORT SAMPLE TO CSV
//// ============================================================
//
//void ExportMLDataCSV(rawdata &raw_4hour[], ContinuousCandleGroup &groups_1hour[],rawdata &raw_1hour[], ContinuousCandleGroup &groups_15min[],rawdata &raw_15min[], ContinuousCandleGroup &groups_15min[])
//{
//    string filename = _Symbol + "_" + EnumToString(PERIOD_CURRENT) + "_ml_dataset.csv";
//
//    Print("========================================");
//    Print("ExportMLDataCSV()");
//    Print("Filename: [", filename, "]");
//    Print("Raw rows: ", ArraySize(raw));
//    Print("Groups: ", ArraySize(groups));
//    Print("========================================");
//
//    bool fileExists = FileIsExist(filename);
//    string csvRow = BuildCsvRow(raw, groups);
//    string fileContent = "";
//
//    if(!fileExists)
//    {
//        // If file doesn't exist, create header first, then add the first row
//        fileContent = BuildCsvHeader(raw, groups) + "\n" + csvRow;
//    }
//    else
//    {
//        // Read existing file content so we can append the new row (or prepend depending on your preference)
//        // Here we append the new row at the end (standard CSV dataset behavior)
//        int read_handle = FileOpen(filename, FILE_READ | FILE_TXT | FILE_ANSI);
//        if(read_handle != INVALID_HANDLE)
//        {
//            while(!FileIsEnding(read_handle))
//            {
//                fileContent += FileReadString(read_handle);
//                if(!FileIsEnding(read_handle))
//                    fileContent += "\n";
//            }
//            FileClose(read_handle);
//        }
//
//        StringTrimRight(fileContent);
//        fileContent += "\n" + csvRow;
//    }
//
//    // Write back complete CSV file
//    ResetLastError();
//    int handle = FileOpen(filename, FILE_WRITE | FILE_TXT | FILE_ANSI);
//    if(handle == INVALID_HANDLE)
//    {
//        Print("CSV FileOpen FAILED. Error: ", GetLastError());
//        return;
//    }
//
//    FileWriteString(handle, fileContent);
//    FileClose(handle);
//
//    Print("CSV export completed successfully.");
//}