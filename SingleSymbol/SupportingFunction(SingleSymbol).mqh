//+------------------------------------------------------------------+
//|                                          Supporting Function.mqh |
//|                                 Copyright 2021, mrPragmatic Ltd. |
//|                                      https://www.mrPragmatic.com |
//+------------------------------------------------------------------+
#property link          "https://www.mrPragmatic.com"
#property copyright     "Copyright 2021, mrPragmatic Ltd."
#include <Trade/trade.mqh>

CTrade trades;

//+------------------------------------------------------------------+
//| Digits Multi-Symbol                                              |
//+------------------------------------------------------------------+
int digits_MyWay(string symbol) {

   long dig    = SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   int dig_int = (int)dig;
   return dig_int;
}

//+------------------------------------------------------------------+
//| Pip Value Calculation                                            |
//+------------------------------------------------------------------+
double GetPipValueMyWay(string symbol) {

   string Currency_Profit = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
   double PipValue = Currency_Profit == "JPY" ? 0.01 : 0.0001;
   return PipValue;
}

//+------------------------------------------------------------------+
//| Pip Multiplier                                                   |
//+------------------------------------------------------------------+
int Pip_Multiplier(string symbol) {

   string Currency_Profit = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
   return Currency_Profit == "JPY" ? 100 : 10000;
}


//+------------------------------------------------------------------+
//| Position Size Calculator (from the instructor)                   |
//+------------------------------------------------------------------+
double Lot_Size(double maxRisk, double maxLossInPips, string symbol) {

   int digs = digits_MyWay(symbol);

   double maxRiskPrc = maxRisk/100;

   double accEquity = AccountInfoDouble(ACCOUNT_BALANCE);

   double lotSize = SymbolInfoDouble(symbol,SYMBOL_MARGIN_HEDGED);

   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   if(digs <= 3) {
      tickValue = tickValue /100;
   }

   double maxLossDollar = accEquity * maxRiskPrc;

   double maxLossInQuoteCurr = maxLossDollar / tickValue;

   double optimalLotSize = NormalizeDouble(maxLossInQuoteCurr /(maxLossInPips * GetPipValueMyWay(symbol))/lotSize,2);

   return optimalLotSize;
}

//+------------------------------------------------------------------+
//| Break Even Function                                              |
//+------------------------------------------------------------------+
void MoveToBreakeven(double LongATRstop1, double ShortATRstop1, double Ratio, string symbol) {

   double PosOpenPrice;
   double PosStopLoss;
   int digs = digits_MyWay(symbol);

   //Adjust Buy Order
   for(int b=PositionsTotal()-1; b>=0; b--) {
      ulong PosTicket_b = PositionGetTicket(b);
      if (PositionSelectByTicket(PosTicket_b))
         if (PositionGetString(POSITION_SYMBOL) == symbol)
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
               double Bid    = NormalizeDouble(SymbolInfoDouble(symbol, SYMBOL_BID), digs);
               PosOpenPrice  = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), digs);
               PosStopLoss   = NormalizeDouble(PositionGetDouble(POSITION_SL), digs);

               if((Bid - PosOpenPrice) > ((PosOpenPrice - PosStopLoss) * Ratio))
                  if(NormalizeDouble(LongATRstop1, digs) == PosStopLoss)
                     trades.PositionModify(PosTicket_b, PosOpenPrice, NULL);
            }
   }

   //Adjust Sell Order
   for(int s=PositionsTotal()-1; s>=0; s--) {
      ulong PosTicket_s = PositionGetTicket(s);
      if (PositionSelectByTicket(PosTicket_s))
         if (PositionGetString(POSITION_SYMBOL) == symbol)
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
               double Ask    = NormalizeDouble(SymbolInfoDouble(symbol, SYMBOL_ASK), digs);
               PosOpenPrice  = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), digs);
               PosStopLoss   = NormalizeDouble(PositionGetDouble(POSITION_SL), digs);

               if((PosOpenPrice - Ask) > ((PosStopLoss - PosOpenPrice) * Ratio))
                  if(NormalizeDouble(ShortATRstop1, digs) == PosStopLoss)
                     trades.PositionModify(PosTicket_s, PosOpenPrice, NULL);
            }
   }
}

//+------------------------------------------------------------------+
//| Break Even Function that takes half of the trade off             |
//+------------------------------------------------------------------+
void MoveToBreakeven_half_trade_off(double LongATRstop1, double ShortATRstop1, double Ratio, string symbol) {

   double PosOpenPrice;
   double PosStopLoss;
   double PosVolume;
   double PosVolHalf;
   int digs = digits_MyWay(symbol);

   //Adjust Buy Order
   for(int b=PositionsTotal()-1; b>=0; b--) {
      ulong PosTicket_b = PositionGetTicket(b);
      if (PositionSelectByTicket(PosTicket_b))
         if (PositionGetString(POSITION_SYMBOL) == symbol)
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
               double Bid    = NormalizeDouble(SymbolInfoDouble(symbol, SYMBOL_BID), digs);
               PosOpenPrice  = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), digs);
               PosStopLoss   = NormalizeDouble(PositionGetDouble(POSITION_SL), digs);
               PosVolume     = NormalizeDouble(PositionGetDouble(POSITION_VOLUME), 2);
               PosVolHalf    = NormalizeDouble(PosVolume/2, 2);

               if((Bid - PosOpenPrice) > ((PosOpenPrice - PosStopLoss) * Ratio))
                  if(NormalizeDouble(LongATRstop1, digs) == PosStopLoss) {
                     bool check = trades.PositionModify(PosTicket_b, PosOpenPrice, NULL);
                     trades.PositionClosePartial(PosTicket_b, PosVolHalf, 1000);
                  }
            }
   }

   //Adjust Sell Order
   for(int s=PositionsTotal()-1; s>=0; s--) {
      ulong PosTicket_s = PositionGetTicket(s);
      if (PositionSelectByTicket(PosTicket_s))
         if (PositionGetString(POSITION_SYMBOL) == symbol)
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
               double Ask    = NormalizeDouble(SymbolInfoDouble(symbol, SYMBOL_ASK), digs);
               PosOpenPrice  = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), digs);
               PosStopLoss   = NormalizeDouble(PositionGetDouble(POSITION_SL), digs);
               PosVolume     = NormalizeDouble(PositionGetDouble(POSITION_VOLUME), 2);
               PosVolHalf    = NormalizeDouble(PosVolume/2, 2);

               if((PosOpenPrice - Ask) > ((PosStopLoss - PosOpenPrice) * Ratio))
                  if(NormalizeDouble(ShortATRstop1, digs) == PosStopLoss) {
                     bool check = trades.PositionModify(PosTicket_s, PosOpenPrice, NULL);
                     trades.PositionClosePartial(PosTicket_s, PosVolHalf, 1000);
                  }
            }
   }
}

//+------------------------------------------------------------------+
//| Trailling Stop                                                   |
//+------------------------------------------------------------------+
void AdjustTrail(double LongATRstop1, double ShortATRstop1, double Ratio, string symbol) {

   double PosOpenPrice;
   long   PosOpenTime;
   int digs = digits_MyWay(symbol);

   //Adjust Buy Order
   for(int b=PositionsTotal()-1; b>=0; b--) {
      ulong PosTicket_b = PositionGetTicket(b);
      if (PositionSelectByTicket(PosTicket_b))
         if (PositionGetString(POSITION_SYMBOL) == symbol)
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
               double Bid    = NormalizeDouble(SymbolInfoDouble(symbol, SYMBOL_BID), digs);
               PosOpenPrice  = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), digs);
               PosOpenTime   = PositionGetInteger(POSITION_TIME);

               if ((Bid - PosOpenPrice) > ((PosOpenPrice - LongATRstop1)*Ratio)) {
                  int barsince_l_entry = Bars(symbol, PERIOD_CURRENT, PosOpenTime, TimeCurrent());
                  int highest_shift    = iHighest(symbol, PERIOD_CURRENT, MODE_CLOSE, barsince_l_entry, 1);
                  double highest_close = iClose(symbol, PERIOD_CURRENT, highest_shift);

                  int highest_shift_2    = iHighest(symbol, PERIOD_CURRENT, MODE_CLOSE, barsince_l_entry, 2);
                  double highest_close_2 = iClose(symbol, PERIOD_CURRENT, highest_shift_2);

                  double new_sll = NormalizeDouble(Bid - (PosOpenPrice - LongATRstop1), digs);

                  if(NormalizeDouble(highest_close, digs) != NormalizeDouble(highest_close_2, digs))
                     bool check = trades.PositionModify(PosTicket_b, new_sll, NULL);
               }
            }
   }

   //Adjust Sell Order
   for(int s=PositionsTotal()-1; s>=0; s--) {
      ulong PosTicket_s = PositionGetTicket(s);
      if (PositionSelectByTicket(PosTicket_s))
         if (PositionGetString(POSITION_SYMBOL) == symbol)
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
               double Ask    = NormalizeDouble(SymbolInfoDouble(symbol, SYMBOL_ASK), digs);
               PosOpenPrice  = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), digs);
               PosOpenTime   = PositionGetInteger(POSITION_TIME);

               if((PosOpenPrice - Ask) > ((ShortATRstop1 - PosOpenPrice)*Ratio)) {
                  int barsince_s_entry = Bars(symbol, PERIOD_CURRENT, PosOpenTime, TimeCurrent());
                  int lowest_shift     = iLowest(symbol, PERIOD_CURRENT, MODE_CLOSE, barsince_s_entry, 1);
                  double lowest_close  = iClose(symbol, PERIOD_CURRENT, lowest_shift);

                  int lowest_shift_2    = iLowest(symbol, PERIOD_CURRENT, MODE_CLOSE, barsince_s_entry, 2);
                  double lowest_close_2 = iClose(symbol, PERIOD_CURRENT, lowest_shift_2);

                  double new_sls = NormalizeDouble(Ask + (ShortATRstop1 - PosOpenPrice), digs);

                  if(NormalizeDouble(lowest_close, digs) != NormalizeDouble(lowest_close_2, digs))
                     bool check = trades.PositionModify(PosTicket_s, new_sls, NULL);
               }
            }
   }
}

//+------------------------------------------------------------------+
//| Error Handling when setting up indicators Handles                |
//+------------------------------------------------------------------+
bool IndicatorSet_ErrorHandling (int Handle, string symbol, string Indicator) {

   if(Handle == INVALID_HANDLE) {
      string outputMessage = "";

      if(GetLastError() == 4302)
         outputMessage = "Symbol " + symbol + " needs to be added to the MarketWatch";
      else
         StringConcatenate(outputMessage, "(error code ", GetLastError(), ")");

      MessageBox("Failed to create handle of the " + Indicator + " indicator for " + symbol + "/" + EnumToString(Period()) + "\n\r\n\r" +
                 outputMessage +
                 "\n\r\n\rEA will now terminate.");

      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
