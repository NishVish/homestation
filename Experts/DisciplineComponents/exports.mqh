bool ExportCandlesToCSV(string filename)
{
   // Automatically ensure .csv extension is present
    if(StringFind(filename, ".csv") < 0)
    filename = filename + ".csv";

    string temp_file = "temp_" + filename;
   
   // Open temporary file for writing (saves to MQL5\Files\)
    int handle = FileOpen(temp_file, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open temp file. Error: ", GetLastError());
        return false;
    }
   
   // Write CSV header
    FileWrite(handle, "Time", "Open", "High", "Low", "Close", "Direction", "GroupID");
   
   // Write array contents from the global 'out' array
    int size = ArraySize(out);
    for(int i = 0; i < size; i++)
    {
        string time_str = TimeToString(out[i].time, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
        FileWrite(handle,
        time_str,
        DoubleToString(out[i].open, _Digits),
        DoubleToString(out[i].high, _Digits),
        DoubleToString(out[i].low, _Digits),
        DoubleToString(out[i].close, _Digits),
        out[i].direction,
        out[i].groupid);
    }
   
    FileClose(handle);
   
   // Atomic overwrite: Delete old file if it exists, then rename temp file instantly
    if(FileIsExist(filename))
    FileDelete(filename);
      
    if(!FileMove(temp_file, 0, filename, 0 | FILE_REWRITE))
    {
        Print("Failed to finalize file move. Error: ", GetLastError());
        return false;
    }
   
    return true;
}