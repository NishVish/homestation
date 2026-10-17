#resource "\\trading_model.onnx" as uchar trading_model[]

long model_handle = INVALID_HANDLE;

int OnInit()
{
   model_handle = OnnxCreateFromBuffer(
      trading_model,
      ONNX_DEFAULT
   );

   if(model_handle == INVALID_HANDLE)
   {
      Print("ONNX load failed: ", GetLastError());
      return INIT_FAILED;
   }

   long input_shape[] = {1, 2};
   if(!OnnxSetInputShape(model_handle, 0, input_shape))
   {
      Print("Input shape failed: ", GetLastError());
      return INIT_FAILED;
   }

   long label_shape[] = {1};
   if(!OnnxSetOutputShape(model_handle, 0, label_shape))
   {
      Print("Label output shape failed: ", GetLastError());
      return INIT_FAILED;
   }

   long proba_shape[] = {1, 2};
   if(!OnnxSetOutputShape(model_handle, 1, proba_shape))
   {
      Print("Probabilities output shape failed: ", GetLastError());
      return INIT_FAILED;
   }

   Print("ONNX model loaded successfully");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(model_handle != INVALID_HANDLE)
      OnnxRelease(model_handle);
}

void OnTick()
{
   static bool tested = false;
   if(tested)
      return;
   tested = true;

   float input_data[2] = {65.0f, 0.002f};
   long  label_out[1];
   float proba_out[2];

   if(!OnnxRun(
      model_handle,
      ONNX_NO_CONVERSION,
      input_data,
      label_out,
      proba_out
   ))
   {
      Print("Prediction failed: ", GetLastError());
      return;
   }

   Print("MODEL LABEL = ", label_out[0]);
   Print("MODEL PROB[0] = ", proba_out[0], " PROB[1] = ", proba_out[1]);
}