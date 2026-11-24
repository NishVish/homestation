
#ifndef EXPORT_LABELED_FLATDATA_MQH
#define EXPORT_LABELED_FLATDATA_MQH

#define LABELED_FLATDATA_FILENAME "labeled_flatdata.csv"


//+------------------------------------------------------------------+
//| Export tracking                                                  |
//+------------------------------------------------------------------+
datetime last_labeled_exported_time = 0;
long last_labeled_export_id = 0;

//+------------------------------------------------------------------+
//| Append CSV field                                                 |
//+------------------------------------------------------------------+
void AppendLabeledCSVField(string &line, const string value)
{
   if(StringLen(line) > 0)
      line += ",";

   line += value;
}

//+------------------------------------------------------------------+
//| Generate headers for a timeframe                                 |
//+------------------------------------------------------------------+
void AppendLabeledHeaders(string &line, const string timeframe)
{
   for(int i = 0; i < CANDLE_COUNT; i++)
   {
      string index = StringFormat("%02d", i + 1);

      AppendLabeledCSVField(line, timeframe + "_" + index + "_time");
      AppendLabeledCSVField(line, timeframe + "_" + index + "_open");
      AppendLabeledCSVField(line, timeframe + "_" + index + "_high");
      AppendLabeledCSVField(line, timeframe + "_" + index + "_low");
      AppendLabeledCSVField(line, timeframe + "_" + index + "_close");
   }
}

//+------------------------------------------------------------------+
//| Append OHLC values for a timeframe                               |
//+------------------------------------------------------------------+
void AppendLabeledValues(string &line,
                         const numeric_text &data[],
                         const ohlc_data &real_data[])
{
   for(int i = 0; i < CANDLE_COUNT; i++)
   {
      AppendLabeledCSVField(
         line,
         TimeToString(real_data[i].time, TIME_DATE | TIME_MINUTES)
      );

      AppendLabeledCSVField(line, data[i].open);
      AppendLabeledCSVField(line, data[i].high);
      AppendLabeledCSVField(line, data[i].low);
      AppendLabeledCSVField(line, data[i].close);
   }
}

//+------------------------------------------------------------------+
//| Validate enabled timeframe arrays                                |
//+------------------------------------------------------------------+
bool ValidateLabeledArrays()
{
   bool at_least_one = false;

   if(Export_D1)
   {
      at_least_one = true;

      if(ArraySize(labeled_text_1day) != CANDLE_COUNT ||
         ArraySize(real_1day) != CANDLE_COUNT)
         return false;
   }

   if(Export_H4)
   {
      at_least_one = true;

      if(ArraySize(labeled_text_4hour) != CANDLE_COUNT ||
         ArraySize(real_4hour) != CANDLE_COUNT)
         return false;
   }

   if(Export_H1)
   {
      at_least_one = true;

      if(ArraySize(labeled_text_1hour) != CANDLE_COUNT ||
         ArraySize(real_1hour) != CANDLE_COUNT)
         return false;
   }

   if(Export_M15)
   {
      at_least_one = true;

      if(ArraySize(labeled_text_15min) != CANDLE_COUNT ||
         ArraySize(real_15min) != CANDLE_COUNT)
         return false;
   }

   if(Export_M5)
   {
      at_least_one = true;

      if(ArraySize(labeled_text_5min) != CANDLE_COUNT ||
         ArraySize(real_5min) != CANDLE_COUNT)
         return false;
   }

   if(Export_M1)
   {
      at_least_one = true;

      if(ArraySize(labeled_text_1min) != CANDLE_COUNT ||
         ArraySize(real_1min) != CANDLE_COUNT)
         return false;
   }

   if(!at_least_one)
   {
      Print("Labeled export: No timeframe enabled.");
      return false;
   }

   return true;
}


//+------------------------------------------------------------------+
//| Generate dynamic CSV headers                                     |
//+------------------------------------------------------------------+
void GenerateLabeledHeaders(string &header)
{
   header = "id,symbol,anchor_price,snapshot_time";

   // Time remaining until candle close (minutes)
   AppendLabeledCSVField(header, "time_remaining_H4_minutes");
   AppendLabeledCSVField(header, "time_remaining_H1_minutes");
   AppendLabeledCSVField(header, "time_remaining_M15_minutes");

   if(Export_D1)
      AppendLabeledHeaders(header, "D1");

   if(Export_H4)
      AppendLabeledHeaders(header, "H4");

   if(Export_H1)
      AppendLabeledHeaders(header, "H1");

   if(Export_M15)
      AppendLabeledHeaders(header, "M15");

   if(Export_M5)
      AppendLabeledHeaders(header, "M5");

   if(Export_M1)
      AppendLabeledHeaders(header, "M1");
}


//+------------------------------------------------------------------+
//| Generate dynamic CSV values                                      |
//+------------------------------------------------------------------+
void GenerateLabeledValues(string &row)
{
   if(Export_D1)
      AppendLabeledValues(row, labeled_text_1day, real_1day);

   if(Export_H4)
      AppendLabeledValues(row, labeled_text_4hour, real_4hour);

   if(Export_H1)
      AppendLabeledValues(row, labeled_text_1hour, real_1hour);

   if(Export_M15)
      AppendLabeledValues(row, labeled_text_15min, real_15min);

   if(Export_M5)
      AppendLabeledValues(row, labeled_text_5min, real_5min);

   if(Export_M1)
      AppendLabeledValues(row, labeled_text_1min, real_1min);
}

//+------------------------------------------------------------------+
//| Recover last exported ID from CSV                                |
//+------------------------------------------------------------------+

bool LoadLastLabeledExportID(int file)
{
   last_labeled_export_id = 0;

   ulong file_size = FileSize(file);

   if(file_size == 0)
      return true;

   // Read only the last 4096 bytes
   ulong read_size = (file_size < 4096) ? file_size : 4096;

   if(!FileSeek(file, (long)(file_size - read_size), SEEK_SET))
      return false;

   string contents = "";

   while(!FileIsEnding(file))
      contents += FileReadString(file);

   int length = StringLen(contents);

   if(length <= 0)
      return true;

   // Remove trailing newline characters
   int end_pos = length - 1;

   while(end_pos >= 0 &&
         (StringGetCharacter(contents, end_pos) == '\n' ||
          StringGetCharacter(contents, end_pos) == '\r'))
   {
      end_pos--;
   }

   if(end_pos < 0)
      return true;

   // Find beginning of last line
   int start_pos = end_pos;

   while(start_pos >= 0 &&
         StringGetCharacter(contents, start_pos) != '\n' &&
         StringGetCharacter(contents, start_pos) != '\r')
   {
      start_pos--;
   }

   string last_line = StringSubstr(
      contents,
      start_pos + 1,
      end_pos - start_pos
   );

   int comma_pos = StringFind(last_line, ",");

   if(comma_pos <= 0)
      return false;

   string id_text = StringSubstr(last_line, 0, comma_pos);

   for(int i = 0; i < StringLen(id_text); i++)
   {
      ushort ch = StringGetCharacter(id_text, i);

      if(ch < '0' || ch > '9')
         return false;
   }

   last_labeled_export_id = (long)StringToInteger(id_text);

   return true;
}


bool InitializeLabeledExporter()
{
   ResetLastError();

   int file = FileOpen(
      LABELED_FLATDATA_FILENAME,
      FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ
   );

   if(file == INVALID_HANDLE)
   {
      // File does not exist yet; first export will create it.
      last_labeled_export_id = 0;
      last_labeled_exported_time = 0;

      Print("Labeled CSV not found. Starting new file.");

      return true;
   }

   bool success = LoadLastLabeledExportID(file);

   FileClose(file);

   if(!success)
   {
      Print("Failed to recover last labeled export ID.");
      return false;
   }

   Print("Labeled exporter initialized. Last ID: ",
         last_labeled_export_id);

   return true;
}



//+------------------------------------------------------------------+
//| Export one dynamically configured labeled row                   |
//+------------------------------------------------------------------+
bool ExportLabeledFlatData()
{
   // Validate snapshot frequency.
   if(SnapshotFrequencyMinutes < 1)
   {
      Print("Invalid SnapshotFrequencyMinutes.");
      return false;
   }

   // Validate enabled timeframe arrays.
   if(!ValidateLabeledArrays())
   {
      Print("Labeled export failed: Invalid timeframe arrays.");
      return false;
   }

   // Get latest completed M1 candle timestamp.
   // M1 is used for scheduling even if M1 export is disabled.
   datetime current_m1_time = iTime(_Symbol, PERIOD_M1, 1);

   if(current_m1_time == 0)
   {
      Print("Labeled export failed: Invalid M1 timestamp.");
      return false;
   }

   // Calculate snapshot interval.
   long snapshot_interval = (long)SnapshotFrequencyMinutes * 60;

   // Align to clock boundaries.
   datetime snapshot_time =
      (datetime)((long)current_m1_time -
      ((long)current_m1_time % snapshot_interval));

   if(snapshot_time == 0)
      return false;

   // Prevent duplicate exports.
   if(snapshot_time == last_labeled_exported_time)
      return true;

   ResetLastError();

   int file = FileOpen(LABELED_FLATDATA_FILENAME,
                       FILE_READ | FILE_WRITE | FILE_TXT |
                       FILE_ANSI | FILE_SHARE_READ);

   if(file == INVALID_HANDLE)
   {
      Print("Cannot open labeled CSV. Error: ", GetLastError());
      return false;
   }

   // Create header if file is empty.
   if(FileSize(file) == 0)
   {
      string header;

      GenerateLabeledHeaders(header);

      if(FileWriteString(file, header + "\r\n") == 0)
      {
         Print("Failed to write CSV header.");
         FileClose(file);
         return false;
      }

      last_labeled_export_id = 0;
   }
  
   // Generate next ID.
   long next_id = last_labeled_export_id + 1;

   // Start row with metadata.
   string row = IntegerToString(next_id);

   AppendLabeledCSVField(row, _Symbol);

   AppendLabeledCSVField(
      row,
      DoubleToString(anchor_price, _Digits)
   );

   AppendLabeledCSVField(
      row,
      TimeToString(snapshot_time, TIME_DATE | TIME_MINUTES)
   );

   // Calculate remaining time until timeframe closes.
double h4_remaining;
double h1_remaining;
double m15_remaining;

GetTimeRemaining(
   snapshot_time,
   h4_remaining,
   h1_remaining,
   m15_remaining
);

// Append remaining time in minutes.
AppendLabeledCSVField(row, DoubleToString(h4_remaining, 2));
AppendLabeledCSVField(row, DoubleToString(h1_remaining, 2));
AppendLabeledCSVField(row, DoubleToString(m15_remaining, 2));

// Append OHLC values.
GenerateLabeledValues(row);

   // Write CSV row.
   FileSeek(file, 0, SEEK_END);

   uint written = FileWriteString(file, row + "\r\n");

   FileFlush(file);
   FileClose(file);

   if(written == 0)
   {
      Print("Failed to write labeled CSV row.");
      return false;
   }

   // Update tracking.
   last_labeled_export_id = next_id;
   last_labeled_exported_time = snapshot_time;

   Print("Labeled CSV exported: ",
         LABELED_FLATDATA_FILENAME,
         " | ID: ", next_id,
         " | Frequency: ", SnapshotFrequencyMinutes, " minutes",
         " | Snapshot: ",
         TimeToString(snapshot_time, TIME_DATE | TIME_MINUTES));

   return true;
}

#endif
