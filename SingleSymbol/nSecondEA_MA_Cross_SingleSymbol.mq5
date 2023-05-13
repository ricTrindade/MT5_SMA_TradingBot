//+------------------------------------------------------------------+
//|                         nSecond EA (MA Cross) (Multi Symbol).mq5 |
//|                                 Copyright 2021, mrPragmatic Ltd. |
//|                                      https://www.mrPragmatic.com |
//+------------------------------------------------------------------+
#property link          "https://www.mrPragmatic.com"
#property description   "My first fully Functional Multi Symbol EA. Thanks - Darwinex"
#property copyright     "Copyright 2021, mrPragmatic Ltd."
#property strict
#include "SupportingFunction(SingleSymbol).mqh"

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+

CTrade trade;

//:::::::::::::::::::::::::::::::::::::::
// Multi-Symbol Capability              |
//:::::::::::::::::::::::::::::::::::::::
input string   TradeSymbols         = "AUDCAD|AUDJPY|AUDNZD|AUDUSD|EURUSD";   //Symbol(s) or ALL or CURRENT

//General Globals
string   AllSymbolsString           = "AUDCAD|AUDCHF|AUDJPY|AUDNZD|AUDUSD|CADCHF|CADJPY|CHFJPY|EURAUD|EURCAD|EURCHF|EURGBP|EURJPY|EURNZD|EURUSD|GBPAUD|GBPCAD|GBPCHF|GBPJPY|GBPNZD|GBPUSD|NZDCAD|NZDCHF|NZDJPY|NZDUSD|USDCAD|USDCHF|USDJPY";
int      NumberOfTradeableSymbols;
string   SymbolArray[];        // Store a list of the Symbols in String Array format

//Trade Management Arrays
double   OpenTradeSL_long[];        //Store 'Stop Loss' of trades
double   OpenTradeSL_short[];       //Store 'Stop Loss' of trades
int      BarsOnChart[];             //Store '# of bars' of each Currency Pair

//:::::::::::::::::::::::::::::::::::::::
// Strategy Inputs                      |
//:::::::::::::::::::::::::::::::::::::::
input string STRATEGY_SETTINGS;   //==STRATEGY SETTINGS==
input double riskPerTrade = 2.0;  // Risk Per Trade in % of Account Balance
input double tpRatio      = 1.0;  // Risk to Reward Ratio for Take Profit
input double tsRatio      = 2.0;  // Risk to Reward Ratio for Trailling Stop

//:::::::::::::::::::::::::::::::::::::::
// ATR Settings                         |
//:::::::::::::::::::::::::::::::::::::::
input string ATR_SETTINGS;        //==ATR SETTINGS==
input int    atrPeriod     = 14;  // ATR Period
input double atrMultiplier = 1.5; // ATR Multiplier

//ATR Handle
int handleATR[]; //Declare indicator handles as arrays

//:::::::::::::::::::::::::::::::::::::::
// C1 Indicator Inputs                  |
//:::::::::::::::::::::::::::::::::::::::
input string MOVING_AVERAGE_SETTINGS; //==MOVING AVERAGE SETTINGS==
input int    FastMAperiod = 5;        //Fast Moving Period
input int    SlowMAperiod = 21;       //Slow Moving Perion

//Moving Average Handles
int handleFastMA[]; //Declare indicator handles as arrays
int handleSlowMA[]; //Declare indicator handles as arrays

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {

   if(TradeSymbols == "CURRENT") { //Override TradeSymbols input variable and use the current chart symbol only
      NumberOfTradeableSymbols = 1;

      ArrayResize(SymbolArray, 1);
      SymbolArray[0] = Symbol();

      Print("EA will process ", SymbolArray[0], " only");
      
   } else {
   
      string TradeSymbolsToUse = "";

      if(TradeSymbols == "ALL")
         TradeSymbolsToUse = AllSymbolsString;
      else
         TradeSymbolsToUse = TradeSymbols;

      //CONVERT TradeSymbolsToUse TO THE STRING ARRAY SymbolArray
      NumberOfTradeableSymbols = StringSplit(TradeSymbolsToUse, '|', SymbolArray);

      Print("EA will process: ", TradeSymbolsToUse);
   }

   //RESIZE OPEN TRADE ARRAYS (based on how many symbols are being traded)
   ResizeCoreArrays();

   //RESIZE INDICATOR HANDLE ARRAYS
   ResizeIndicatorHandleArrays();

   Print("All arrays sized to accomodate ", NumberOfTradeableSymbols, " symbols");

   //INITIALIZE ARAYS
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++) {
   
      OpenTradeSL_long[SymbolLoop] = 0;        //To store 'Stop Loss' of trades
      OpenTradeSL_short[SymbolLoop] = 0;
      BarsOnChart[SymbolLoop] = 0;
   }

   //INSTANTIATE INDICATOR HANDLES
   if(SetUpIndicatorHandles() == false)
      return(INIT_FAILED);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
//---
   Print("Expert Advisor terminated");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
//---
   //LOOP THROUGH EACH SYMBOL TO CHECK FOR ENTRIES AND EXITS, AND THEN OPEN/CLOSE TRADES AS APPROPRIATE
   for(int SymbolLoop = 0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++) {

      string mtl_symbol = SymbolArray[SymbolLoop];
      int mtl_digits = digits_MyWay(mtl_symbol);

      // Force the EA to exucute calculation only at bar open
      if (IsNewCandle(SymbolLoop)) {

         // Size the Buffer receiving handles values
         int numBarsRequired = 4;//Bars(mtl_symbol,PERIOD_CURRENT);

         //===================================================================================================
         //Copying Values from Indicators Handles to Indicators Buffers
         //===================================================================================================

         //......................................
         //ATR Buffer
         //......................................
         double ATR[];

         int numAvailableBarsATR = CopyBuffer(handleATR[SymbolLoop], 0, 0, numBarsRequired, ATR);

         if (numAvailableBarsATR != numBarsRequired) {
            Alert("Error when copying values from Indicator Handle to ATR Indicator Buffer");
         } else { // Ensure that element are indexed as series
            ArraySetAsSeries(ATR, true);
         }

         //......................................
         //Confirmation indicator Buffer
         //......................................
         double FastMA[], SlowMA[];

         int numAvailableBarsFastMA = CopyBuffer(handleFastMA[SymbolLoop], 0, 0, numBarsRequired, FastMA);
         int numAvailableBarsSlowMA = CopyBuffer(handleSlowMA[SymbolLoop], 0, 0, numBarsRequired, SlowMA);

         if (numAvailableBarsFastMA != numBarsRequired || numAvailableBarsSlowMA != numBarsRequired) {
            Alert("Error when copying values from Indicator Handle to MA Indicator Buffer");
         } else { // Ensure that element are indexed as series
            ArraySetAsSeries(FastMA, true);
            ArraySetAsSeries(SlowMA, true);
         }

         //===================================================================================================
         //Trade Signal & Entry
         //===================================================================================================

         //***********************
         //Signal for trade entry
         //***********************
         bool long_entry  = (FastMA[1] > SlowMA[1]) && (FastMA[2] <= SlowMA[2]);
         bool short_entry = (FastMA[1] < SlowMA[1]) && (FastMA[2] >= SlowMA[2]);

         //===================================================================================================
         //Trade Execution, Fill the orders, Open and Close my Position (trigger)
         //===================================================================================================

         //****************************************
         if (long_entry) { // Submitting Long Trade
         //****************************************
    
            //..................................
            //ATR, Average True Range & Stoploss
            //..................................
            double Ask         = NormalizeDouble(SymbolInfoDouble(mtl_symbol, SYMBOL_ASK), mtl_digits);
            double LongATRstop = NormalizeDouble(Ask - (ATR[1] * atrMultiplier), mtl_digits);
            //double LongTP      = NormalizeDouble(Ask + (ATR[1] * atrMultiplier), mtl_digits);

            //..................................
            // Pips for Lot Size Calculation
            //..................................
            double pip_l = (Ask - LongATRstop) * Pip_Multiplier(mtl_symbol);
            double lot_l = NormalizeDouble(Lot_Size(riskPerTrade, pip_l, mtl_symbol), 2);

            //..................................
            //Close short Order (if one is open)
            //..................................
            for(int s=PositionsTotal()-1; s>=0; s--) {
               ulong PosTicket_s = PositionGetTicket(s);
               if (PositionSelectByTicket(PosTicket_s))
                  if (PositionGetString(POSITION_SYMBOL) == mtl_symbol)
                     if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                        bool close_sell = trade.PositionClose(PosTicket_s, 1000);
            }

            //..................................
            // Submitting a Long Position
            //..................................
            OpenTradeSL_long[SymbolLoop] = NormalizeDouble(LongATRstop, mtl_digits);
            bool buy = trade.Buy(lot_l, mtl_symbol, Ask, LongATRstop, NULL, NULL);

         }

         //****************************************
         if (short_entry) { // Submitting Short Trade
         //****************************************
     
            //..................................
            //ATR, Average True Range & Stoploss
            //..................................
            double Bid          = NormalizeDouble(SymbolInfoDouble(mtl_symbol, SYMBOL_BID), mtl_digits);
            double ShortATRstop = NormalizeDouble(Bid + (ATR[1] * atrMultiplier), mtl_digits);
            //double ShortTP      = NormalizeDouble(Bid - (ATR[1] * atrMultiplier), mtl_digits);

            //..................................
            // Pips for Lot Size Calculation
            //..................................
            double pip_s = (ShortATRstop - Bid) * Pip_Multiplier(mtl_symbol);
            double lot_s = NormalizeDouble(Lot_Size(riskPerTrade, pip_s, mtl_symbol), 2);

            //..................................
            //Close long Order (if one is open)
            //..................................
            for(int b=PositionsTotal()-1; b>=0; b--) {
               ulong PosTicket_b = PositionGetTicket(b);
               if (PositionSelectByTicket(PosTicket_b))
                  if (PositionGetString(POSITION_SYMBOL) == mtl_symbol)
                     if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                        bool close_buy = trade.PositionClose(PosTicket_b, 1000);
            }

            //..................................
            // Submitting a Short Position
            //..................................
            OpenTradeSL_short[SymbolLoop] = NormalizeDouble(ShortATRstop, mtl_digits);
            bool sell = trade.Sell(lot_s, mtl_symbol, Bid, ShortATRstop, NULL, NULL);
         }

         //..................................
         //Trailing Stop
         //..................................
         if(PositionsTotal() > 0) AdjustTrail(OpenTradeSL_long[SymbolLoop], OpenTradeSL_short[SymbolLoop], tsRatio, mtl_symbol);

      } // End of "IsNewBar() function"

      //..................................
      //Move to breakeven
      //and close half of the trade
      //..................................
      if(PositionsTotal() > 0) MoveToBreakeven_half_trade_off(OpenTradeSL_long[SymbolLoop], OpenTradeSL_short[SymbolLoop], tpRatio, mtl_symbol);
   }
}
// End of "OnTick() function"
//---------------------------------------------------------------------------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester() {
   double ret=0.0;

   return ret;
}
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//| Custom functions                                                 |
//+------------------------------------------------------------------+

//:::::::::::::::::::::::::::::::::::::::
// ResizeCoreArrays                     |
//:::::::::::::::::::::::::::::::::::::::
void ResizeCoreArrays() {
   ArrayResize(OpenTradeSL_long, NumberOfTradeableSymbols);
   ArrayResize(OpenTradeSL_short, NumberOfTradeableSymbols);
   ArrayResize(BarsOnChart, NumberOfTradeableSymbols);
   //Add other trade arrays here as required
}

//:::::::::::::::::::::::::::::::::::::::
// ResizeIndicatorHandleArrays          |
//:::::::::::::::::::::::::::::::::::::::
void ResizeIndicatorHandleArrays() {
   //Indicator Handles
   ArrayResize(handleATR, NumberOfTradeableSymbols);
   ArrayResize(handleFastMA, NumberOfTradeableSymbols);
   ArrayResize(handleSlowMA, NumberOfTradeableSymbols);
   //Add other indicators here as required by your EA
}

//:::::::::::::::::::::::::::::::::::::::::::::::::::
// SET UP REQUIRED INDICATOR HANDLES                |
//(arrays because of multi-symbol capability in EA) |
//:::::::::::::::::::::::::::::::::::::::::::::::::::
bool SetUpIndicatorHandles() {

   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++) {
      //Reset any previous error codes so that only gets set if problem setting up indicator handle
      ResetLastError();

      //****
      //ATR
      //****
      handleATR[SymbolLoop] = iATR(SymbolArray[SymbolLoop], Period(), atrPeriod);
      if(IndicatorSet_ErrorHandling(handleATR[SymbolLoop], SymbolArray[SymbolLoop], "ATR") == false) return false;
      Print("Handle for ATR / ", SymbolArray[SymbolLoop], " / ", EnumToString(Period()), " successfully created");
      ResetLastError();

      //********
      //Fast MA
      //********
      handleFastMA[SymbolLoop] = iMA(SymbolArray[SymbolLoop], Period(), FastMAperiod, 0, MODE_EMA, PRICE_CLOSE);
      if(IndicatorSet_ErrorHandling(handleFastMA[SymbolLoop], SymbolArray[SymbolLoop], "Fast MA") == false) return false;
      Print("Handle for Fast MA / ", SymbolArray[SymbolLoop], " / ", EnumToString(Period()), " successfully created");
      ResetLastError();

      //********
      //Slow MA
      //********
      handleSlowMA[SymbolLoop] = iMA(SymbolArray[SymbolLoop], Period(), SlowMAperiod, 0, MODE_EMA, PRICE_CLOSE);
      if(IndicatorSet_ErrorHandling(handleSlowMA[SymbolLoop], SymbolArray[SymbolLoop], "Slow MA") == false) return false;
      Print("Handle for Slow MA / ", SymbolArray[SymbolLoop], " / ", EnumToString(Period()), " successfully created");
      //ResetLastError();
   }

   //All completed without errors so return true
   return true;
}

//:::::::::::::::::::::::::::::::::::::::
// Only send order                      |
// when a candle just formed            |
//:::::::::::::::::::::::::::::::::::::::
bool IsNewCandle(int SymbolLoop) {

   if (Bars(SymbolArray[SymbolLoop], PERIOD_CURRENT) == BarsOnChart[SymbolLoop]) return false;
   BarsOnChart[SymbolLoop] = Bars(SymbolArray[SymbolLoop], PERIOD_CURRENT);
   return true;
}
//+------------------------------------------------------------------+
