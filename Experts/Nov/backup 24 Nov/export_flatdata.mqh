
#ifndef EXPORT_FLATDATA_MQH
#define EXPORT_FLATDATA_MQH

#define FLATDATA_FILENAME "flatdata.csv"

// Track the last exported completed M1 candle.
datetime last_exported_m1_time = 0;

// Incremental row ID.
long last_exported_id = 0;

//+------------------------------------------------------------------+
//| Append a field to a CSV line                                     |
//+------------------------------------------------------------------+
void AppendCSVField(string &line, const string value)
{
   if(StringLen(line) > 0)
      line += ",";

   line += value;
}

//+------------------------------------------------------------------+
//| Generate headers for 20 candles (01 to 20)                       |
//+------------------------------------------------------------------+
void AppendOHLCHeaders(string &line, const string timeframe)
{
   for(int i = 0; i < CANDLE_COUNT; i++)
   {
      string index = StringFormat("%02d", i + 1);

      AppendCSVField(line, timeframe + "_" + index + "_time");
      AppendCSVField(line, timeframe + "_" + index + "_open");
      AppendCSVField(line, timeframe + "_" + index + "_high");
      AppendCSVField(line, timeframe + "_" + index + "_low");
      AppendCSVField(line, timeframe + "_" + index + "_close");
   }
}

//+------------------------------------------------------------------+
//| Append real timestamps and OHLC values                           |
//+------------------------------------------------------------------+
void AppendOHLCValues(string &line, const ohlc_data &data[])
{
   for(int i = 0; i < CANDLE_COUNT; i++)
   {
      AppendCSVField(
         line,
         TimeToString(data[i].time, TIME_DATE | TIME_MINUTES)
      );

      AppendCSVField(line, DoubleToString(data[i].open, _Digits));
      AppendCSVField(line, DoubleToString(data[i].high, _Digits));
      AppendCSVField(line, DoubleToString(data[i].low, _Digits));
      AppendCSVField(line, DoubleToString(data[i].close, _Digits));
   }
}

//+------------------------------------------------------------------+
//| Recover the last ID from the existing CSV                        |
//+------------------------------------------------------------------+
bool LoadLastExportID(int file)
{
   if(!FileSeek(file, 0, SEEK_SET))
      return false;

   last_exported_id = 0;

   if(FileSize(file) <= 0)
      return true;

   string contents = "";

   while(!FileIsEnding(file))
   {
      string part = FileReadString(file);

      if(StringLen(contents) > 0)
         contents += "\n";

      contents += part;
   }

   int length = StringLen(contents);

   // Find the last non-empty line.
   int end_pos = length - 1;

   while(end_pos >= 0 &&
         (StringGetCharacter(contents, end_pos) == '\n' ||
          StringGetCharacter(contents, end_pos) == '\r'))
   {
      end_pos--;
   }

   if(end_pos < 0)
      return true;

   int start_pos = end_pos;

   while(start_pos >= 0 &&
         StringGetCharacter(contents, start_pos) != '\n' &&
         StringGetCharacter(contents, start_pos) != '\r')
   {
      start_pos--;
   }

   string last_line = StringSubstr(contents,
                                   start_pos + 1,
                                   end_pos - start_pos);

   // First column is the ID.
   int comma_pos = StringFind(last_line, ",");

   if(comma_pos < 0)
      return true; // Header only.

   string id_text = StringSubstr(last_line, 0, comma_pos);

   if(StringLen(id_text) == 0)
      return true;

   for(int i = 0; i < StringLen(id_text); i++)
   {
      ushort ch = StringGetCharacter(id_text, i);

      if(ch < '0' || ch > '9')
         return true; // Header or invalid ID.
   }

   last_exported_id = (long)StringToInteger(id_text);

   return true;
}

//+------------------------------------------------------------------+
//| Export one flattened row using REAL OHLC prices                   |
//+------------------------------------------------------------------+
bool ExportFlatData()
{
   // Validate all real candle arrays.
   if(ArraySize(real_15min) != CANDLE_COUNT ||
      ArraySize(real_5min)  != CANDLE_COUNT ||
      ArraySize(real_1min)  != CANDLE_COUNT)
   {
      Print("Export failed: expected ",
            CANDLE_COUNT, " candles per timeframe.");

      return false;
   }

   // Latest completed M1 candle timestamp.
   datetime current_m1_time = real_1min[CANDLE_COUNT - 1].time;

   if(current_m1_time == 0)
   {
      Print("Export failed: invalid M1 candle timestamp.");
      return false;
   }

   // Export only once per completed M1 candle.
   if(current_m1_time == last_exported_m1_time)
      return true;

   ResetLastError();

   int file = FileOpen(FLATDATA_FILENAME,
                       FILE_READ | FILE_WRITE | FILE_TXT |
                       FILE_ANSI | FILE_SHARE_READ);

   if(file == INVALID_HANDLE)
   {
      Print("Cannot open ", FLATDATA_FILENAME,
            ". Error: ", GetLastError());

      return false;
   }

   // Create the header if the file is empty.
   if(FileSize(file) == 0)
   {
      string header = "id,symbol,m1_candle_time";

      AppendOHLCHeaders(header, "M15");
      AppendOHLCHeaders(header, "M5");
      AppendOHLCHeaders(header, "M1");

      uint header_written = FileWriteString(file, header + "\r\n");

      if(header_written == 0)
      {
         Print("Failed to write CSV header.");
         FileClose(file);
         return false;
      }

      last_exported_id = 0;
   }
   else
   {
      // Continue numbering from the existing file.
      if(!LoadLastExportID(file))
      {
         Print("Failed to recover the last CSV ID.");
         FileClose(file);
         return false;
      }
   }

   // Increment the ID for this row.
   long next_id = last_exported_id + 1;

   // Start row with ID and metadata.
   string row = IntegerToString(next_id);

   AppendCSVField(row, _Symbol);

   AppendCSVField(
      row,
      TimeToString(current_m1_time, TIME_DATE | TIME_MINUTES)
   );

   // Append timestamps and REAL OHLC values.
   AppendOHLCValues(row, real_15min);
   AppendOHLCValues(row, real_5min);
   AppendOHLCValues(row, real_1min);

   // Append the complete row.
   FileSeek(file, 0, SEEK_END);

   uint written = FileWriteString(file, row + "\r\n");

   FileFlush(file);
   FileClose(file);

   if(written == 0)
   {
      Print("Failed to write CSV row.");
      return false;
   }

   // Update state only after a successful write.
   last_exported_id = next_id;
   last_exported_m1_time = current_m1_time;

   Print("Real OHLC CSV exported: ", FLATDATA_FILENAME,
         " | ID: ", next_id,
         " | M1 time: ",
         TimeToString(current_m1_time, TIME_DATE | TIME_MINUTES),
         " | Candles: M15=20, M5=20, M1=20",
         " | Total columns: 303");

   return true;
}

#endif
