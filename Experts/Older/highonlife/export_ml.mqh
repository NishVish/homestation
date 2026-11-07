// ============================================================
// CSV EXPORT & FLATTENING
// ============================================================

// ------------------------------------------------------------
// CSV escaping for strings
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
// Build CSV Header
// ------------------------------------------------------------
string BuildCsvHeader(rawdata &raw[], string prefix)
{
    string header = "";
    int rawTotal = ArraySize(raw);

    for(int i = 0; i < rawTotal; i++)
    {
        string idx = IntegerToString(i + 1);

        if(StringLen(header) > 0)
            header += ",";

        header += prefix + "_raw_time_" + idx + "," +
                  prefix + "_raw_open_" + idx + "," +
                  prefix + "_raw_high_" + idx + "," +
                  prefix + "_raw_low_" + idx + "," +
                  prefix + "_raw_close_" + idx;
    }

    return header;
}




// ------------------------------------------------------------
// Build CSV Data Row
// Values are written with exactly 2 decimal places
// ------------------------------------------------------------
string BuildCsvRow(rawdata &raw[])
{
    string row = "";
    int rawTotal = ArraySize(raw);

    for(int i = 0; i < rawTotal; i++)
    {
        if(StringLen(row) > 0)
            row += ",";

        row += CsvTime(raw[i].time) + "," +
               DoubleToString(raw[i].open, 10) + "," +
               DoubleToString(raw[i].high, 10) + "," +
               DoubleToString(raw[i].low, 10) + "," +
               DoubleToString(raw[i].close, 10);
    }

    return row;
}
// ------------------------------------------------------------
// Master Export Function
// ------------------------------------------------------------
void ExportMLDataCSV(
    rawdata &raw_4hour[],
    rawdata &raw_1hour[],
    rawdata &raw_15min[],
    rawdata &raw_5min[],
    rawdata &raw_1min[]
)
{
    string filename =
        _Symbol + "_" +
        EnumToString(PERIOD_CURRENT) +
        "_ml_dataset.csv";

    Print("========================================");
    Print("ExportMLDataCSV()");
    Print("Filename: [", filename, "]");
    Print("========================================");


    // ========================================================
    // BUILD HEADER (Added "id" as the first column)
    // ========================================================

    string header =
        "id," +
        BuildCsvHeader(raw_15min, "15min") + "," +
        BuildCsvHeader(raw_5min,  "5min")  + "," +
        BuildCsvHeader(raw_1min,  "1min");


    // ========================================================
    // CHECK FILE & READ EXISTING DATA
    // ========================================================

    bool fileExists = FileIsExist(filename);
    string existingData = "";
    int existingRowCount = 0;

    if(fileExists)
    {
        int read_handle =
            FileOpen(
                filename,
                FILE_READ |
                FILE_TXT |
                FILE_ANSI
            );

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
                    existingRowCount++;

                    if(StringLen(existingData) > 0)
                        existingData += "\n";

                    existingData += line;
                }
            }

            FileClose(read_handle);
        }

        StringTrimRight(existingData);
    }


    // ========================================================
    // BUILD CURRENT ROW (ID = existing rows + 1)
    // ========================================================

    int newId = existingRowCount + 1;

    string csvRow =
        IntegerToString(newId) + "," +
        BuildCsvRow(raw_15min) + "," +
        BuildCsvRow(raw_5min)  + "," +
        BuildCsvRow(raw_1min);


    // ========================================================
    //ASSEMBLE FILE CONTENT (Header -> Existing Data -> New Row at Bottom)
    // ========================================================

    string fileContent = header;

    if(StringLen(existingData) > 0)
    {
        fileContent += "\n" + existingData;
    }

    fileContent += "\n" + csvRow;


    // ========================================================
    // WRITE FILE
    // ========================================================

    ResetLastError();

    int handle =
        FileOpen(
            filename,
            FILE_WRITE |
            FILE_TXT |
            FILE_ANSI
        );


    if(handle == INVALID_HANDLE)
    {
        Print(
            "CSV FileOpen FAILED. Error: ",
            GetLastError()
        );

        return;
    }


    FileWriteString(
        handle,
        fileContent
    );


    FileClose(handle);


    Print(
        "CSV export completed successfully."
    );
}