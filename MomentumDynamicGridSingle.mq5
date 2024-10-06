//+------------------------------------------------------------------+
//|                                    MomentumDynamicGridSingle.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\Trade.mqh>
CTrade         m_trade;

#define SECONDS_IN_DAY 86400

input int MAGIC_NUMBER              = 11111;
input int GridLevelCount            = 5;
input int AllocationCountPerLevel   = 1; 
input double LotSize                = 0.01; 
input int MaxSLIPip                 = 5000;
input bool IsTakeProfitATR          = true;
input bool UseTrendFilter           = true;
input double ATRMultiple            = 2;
input bool IsIgnoreExitSignal       = true;
input uint DaysToForceExit          = 0;
input double GridLow                = 0;
input double GridHigh               = 0;
input bool IsLongMode               = true;

datetime timePreviousBar            = 0;

bool BuySignal = false;
bool SellSignal = false;
// Define the periods of the two indicators:
int MASlowPeriod = 4;
int MAFastPeriod =  4*24;
bool isUpTrend = true;


class GridLevel {
   public:
   double low;
   double high;
   GridLevel(double l, double h) {
      low = l;
      high = h;
   }
};
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   if (IsNewBar(_Symbol)) OnNewBar(_Symbol);
  }
//+------------------------------------------------------------------+

void OnNewBar(string symbol) {
      if (IsTradeAllowed() == false) return;
      double currentPrice = IsLongMode ? CurrentBid(symbol) : CurrentAsk(symbol);
      if (isInsideGrid(currentPrice) == false) return;
      
      CheckMomentumCross(symbol);
      CheckMomentumTrend(symbol);
         
      Comment(symbol, " on new bar inside grid");
      if (BuySignal == false && SellSignal == false) return;
         
      GridLevel *level = GetCurrentLevel(currentPrice);
      printf("price: %f high: %f low: %f",currentPrice, level.high, level.low);
      if (UseTrendFilter && isUpTrend) printf("Is up trend");
      if (UseTrendFilter && !isUpTrend) printf("Is down trend");
         
      ulong array[];
      FindTicketsInGridLevel(array, level.low, level.high);
      int arraySize = ArraySize(array);
      if (arraySize < AllocationCountPerLevel) {
         if (BuySignal && IsLongMode && ((UseTrendFilter && isUpTrend) || !UseTrendFilter)) entry(symbol, LotSize, ORDER_TYPE_BUY, MaxSLIPip);
         if (SellSignal && IsLongMode == false && ((UseTrendFilter && isUpTrend == false) || !UseTrendFilter)) entry(symbol, LotSize, ORDER_TYPE_SELL, MaxSLIPip);
      }
      Comment(symbol, " ", arraySize, " orders in grid");
      if (SellSignal && IsLongMode && !IsIgnoreExitSignal) exit(array, true);
      if (BuySignal && IsLongMode == false && !IsIgnoreExitSignal) exit(array, true);
      
      if (DaysToForceExit > 0) {
         forceExit(array, DaysToForceExit);
      }
      // if (IsLongMode && isUpTrend == false) exit(array, false);
      // if (IsLongMode == false && isUpTrend) exit(array, false);
      delete level;
}
  
bool IsNewBar(string symbol)
{
   datetime timeCurrentBar = iTime(symbol,Period(),0);

   if (timePreviousBar != timeCurrentBar)
   {
      timePreviousBar = timeCurrentBar;
      return true;
   } else {
      return false;
   }
}

void entry(string symbol, double lotSize, ENUM_ORDER_TYPE orderType, int stopLossPips) {
   if (orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_SELL) {
      double entryPrice = 0, stopLossPrice = 0, takeProfit = 0;
      int digits = (int) SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double atrValue = ATR(symbol, PERIOD_CURRENT);
      if (orderType == ORDER_TYPE_BUY) {
         entryPrice = CurrentAsk(symbol);
         stopLossPrice = NormalizeDouble(entryPrice - (NormalizedDigits(symbol) * stopLossPips), digits);
         takeProfit = IsTakeProfitATR ? NormalizeDouble(entryPrice + atrValue*ATRMultiple, digits) : 0;
      }
      if (orderType == ORDER_TYPE_SELL) {
         entryPrice = CurrentBid(symbol);
         stopLossPrice = NormalizeDouble(entryPrice + (NormalizedDigits(symbol) * stopLossPips), digits);
         takeProfit = IsTakeProfitATR ? NormalizeDouble(entryPrice - atrValue*ATRMultiple, digits) : 0;
      }
      
      Print("Entry", stopLossPrice, takeProfit, atrValue);
      //--- prepare a request 
      MqlTradeRequest request={}; 
      request.action=TRADE_ACTION_DEAL;
      request.type_filling=ORDER_FILLING_IOC;
      request.magic=MAGIC_NUMBER;
      request.symbol=symbol;
      request.volume=lotSize;
      request.sl=stopLossPrice;
      request.tp=takeProfit;
   //--- form the order type 
      request.type=orderType;
   //--- form the price for the pending order 
      request.price=entryPrice;
   //--- send a trade request 
      MqlTradeResult result={}; 
      if (OrderSend(request,result)) {
         Print("OrderSend placed successfully");
      } else {
         Print("OrderSend failed with error #",GetLastError());
      }
   }
}

void exit(ulong &array[], bool isExitOnlyProfitTrade=true) {
   int size = ArraySize(array);

   for(int pos=0;pos<size;pos++) { 
     ulong ticket = array[pos];
     if(PositionSelectByTicket(ticket) == false) continue;
     
     long positionId = PositionGetInteger(POSITION_IDENTIFIER);
     
     if (HistorySelectByPosition(positionId) == false) continue;
     double positionProfit = PositionGetDouble(POSITION_PROFIT);
     double positionSwap = PositionGetDouble(POSITION_SWAP);

     double dealCommission = 0;
     int dealSize = HistoryDealsTotal();
     for(int dealIndex=0;dealIndex<dealSize;dealIndex++) {
         dealCommission += HistoryDealGetDouble(HistoryDealGetTicket(dealIndex), DEAL_COMMISSION);
     }
     
     double profit = positionProfit + positionSwap + (2 * dealCommission);
     if (isExitOnlyProfitTrade && profit <= 0) continue;
     string symbol = OrderGetString(ORDER_SYMBOL);
     double exitPrice = 0;
     if (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY) {
         exitPrice = CurrentBid(symbol);
     }
     if (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL) {
         exitPrice = CurrentAsk(symbol);
     }
     
     if (m_trade.PositionClose(ticket, 5)) {
         Print("PositionClose successfully");
     } else {
         Print("PositionClose failed with error #",GetLastError());
     }
   }
}

void forceExit(ulong &array[], uint days)
{
   int size = ArraySize(array);

   for(int pos=0;pos<size;pos++) {
     long positionTicket = array[pos]; 
     if(PositionSelectByTicket(positionTicket)) continue;
     datetime positionTime = datetime(PositionGetInteger(POSITION_TIME));
     if (IsNDaysFromDate(positionTime, days)) {
        if (m_trade.PositionClose(positionTicket, 5)) {
           Print("OrderClose successfully");
        } else {
           Print("OrderClose failed with error #",GetLastError());
        }
     }
   }
}

void FindTicketsInGridLevel(ulong &array[], double low, double high) {
   int total = PositionsTotal();
   int counter=0;
   ArrayResize(array,total);

   for(int pos=0;pos<total;pos++) {
     ulong ticket = PositionGetTicket(pos);
     if(PositionSelectByTicket(ticket)==false) continue;
     ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);
     if (
         isInsideGridLevel(PositionGetDouble(POSITION_PRICE_OPEN), low, high) && 
         (positionType == POSITION_TYPE_BUY || positionType == POSITION_TYPE_SELL)
     ) {
         array[counter++] = ticket;
         Print("Found ticket in grid level");
     }
    }
   ArrayResize(array,counter);
   return;
}

bool isInsideGridLevel(double currentPrice, double low, double high) {
   return low <= currentPrice && high >= currentPrice;
}

bool isInsideGrid(double currentPrice) {
   return GridLow <= currentPrice && GridHigh >= currentPrice;
}

GridLevel* GetCurrentLevel(double currentPrice)
{
   double gridGap = (GridHigh - GridLow) / double(GridLevelCount);
   int currentLevel = int((currentPrice - GridLow) / gridGap);
   double low = GridLow + (currentLevel * gridGap);
   double high = low + gridGap;
   return new GridLevel(low, high);
}

double NormalizedDigits(string symbol)
{
   int digits = (int) SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   // If there are 3 or fewer digits (JPY, for example), then return 0.01, which is the pip value.
   if (digits <= 3){
      return(0.01);
   }
   // If there are 4 or more digits, then return 0.0001, which is the pip value.
   else if (digits >= 4){
      return(0.0001);
   }
   // In all other cases, return 0.
   else return(0);
}


// Define a function to detect a crossover:
void CheckMACross(string symbol)
{
   BuySignal = false;
   SellSignal = false;
   
   // iMA is the function to get the value of a moving average indicator.
   
   // MASlowCurr is the value of the slow moving average at the current instant.
   double MASlowCurr = MovingAverage(symbol, PERIOD_CURRENT, MASlowPeriod, MODE_EMA, 0);
   
   // MASlowPrev is the value of the slow moving average at the last closed candle/bar.
   double MASlowPrev = MovingAverage(symbol, PERIOD_CURRENT, MASlowPeriod, MODE_EMA, 1);
   
   // MAFastCurr is the value of the fast moving average at the current instant.
   double MAFastCurr = MovingAverage(symbol, PERIOD_CURRENT, MAFastPeriod, MODE_EMA, 0);
   
   // MAFastPrev is the value of the fast moving average at the last closed candle/bar.
   double MAFastPrev = MovingAverage(symbol, PERIOD_CURRENT, MAFastPeriod, MODE_EMA, 1);
   
   // Compare the values and detect if one of the crossovers has happened.
   if ((MASlowPrev > MAFastPrev) && (MAFastCurr > MASlowCurr))
   {
      BuySignal = true;
   }
   if ((MASlowPrev < MAFastPrev) && (MAFastCurr < MASlowCurr))
   {
      SellSignal = true;
   }
}

void CheckMomentumCross(string symbol) 
{
   BuySignal = false;
   SellSignal = false;
   double momentumSlowPrev = Momentum(symbol, PERIOD_CURRENT, MASlowPeriod, 1);
   double momentumSlowCurr = Momentum(symbol, PERIOD_CURRENT, MASlowPeriod, 0);
   double momentumFastPrev = Momentum(symbol, PERIOD_CURRENT, MAFastPeriod, 1);
   double momentumFastCurr = Momentum(symbol, PERIOD_CURRENT, MAFastPeriod, 0);
   
   if ((momentumSlowPrev > momentumFastPrev) && (momentumFastCurr > momentumSlowCurr)) {
      BuySignal = true;
   }
   if ((momentumSlowPrev < momentumFastPrev) && (momentumFastCurr < momentumSlowCurr)) {
      SellSignal = true;
   }
}

void CheckMomentumTrend(string symbol)
{
   isUpTrend = Momentum(symbol, PERIOD_D1, 5, 1) > Momentum(symbol, PERIOD_D1, 20, 1);
}

double Momentum(string symbol, ENUM_TIMEFRAMES timeframe,int maPeriod, uint index)
{
   double momentumArray[];
   int handle = iMomentum(symbol, timeframe, maPeriod, PRICE_CLOSE);
   if (CopyBuffer(handle, 0, 0, index + 1, momentumArray) >= 0) {
      ArraySetAsSeries(momentumArray, true);
      return momentumArray[index];
   } else {
      return -1;
   }
}

double MovingAverage(string symbol, ENUM_TIMEFRAMES timeframe, int maPeriod, ENUM_MA_METHOD method, uint index)
{
   double movingAverageArray[];
   int handle = iMA(symbol, timeframe, maPeriod,0,method, PRICE_CLOSE);
   if (CopyBuffer(handle, 0, 0, index + 1, movingAverageArray) >= 0) {
      ArraySetAsSeries(movingAverageArray, true);
      return movingAverageArray[index];
   } else {
      return -1;
   }
}

double ATR(string symbol, ENUM_TIMEFRAMES timeframe)
{
   double atrArray[];
   int handle = iATR(symbol, timeframe, 14);
   if (CopyBuffer(handle, 0, 0, 2, atrArray) >= 0) {
      ArraySetAsSeries(atrArray, true);
      return atrArray[1];
   } else {
      return -1;
   }
}

double IsNDaysFromDate(datetime date, uint days)
{
   datetime now = TimeCurrent();
   return datetime(date + SECONDS_IN_DAY*days) < now;
}

bool IsTradeAllowed(){
    int result = TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
    return result == 1;
}

double CurrentBid(string symbol) 
{
   return SymbolInfoDouble(symbol, SYMBOL_BID);
}

double CurrentAsk(string symbol)
{
   return SymbolInfoDouble(symbol, SYMBOL_ASK); 
}