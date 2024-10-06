//+------------------------------------------------------------------+
//|                                                 AdaptiveGrid.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade         m_trade;

enum TrendDetectStrategy {
   Adx,
   Macd,
   Rsi,
   Stochastic,
   EMA,
   None
};

enum TrendMode {
   Up,
   Sideway,
   Down
};

struct IndicatorResult {
   double main;
   double signal;
};

struct AdxIndicatorResult {
   double main;
   double plus;
   double minus;
};

input ulong    magic_number         = 99;                               // Magic number 1-99 for each EA
input double   max_price            = 3000.0;                           // max price
input double   min_price            = 1500.0;                           // min price
input double   price_gap            = 5.0;                              // price gap
input int      number_pending_order = 10;                               // number of allows pending order
input double   lot_size             = 0.01;                             // lot size
input double   stoploss_price       = 1000.0;                           // stoploss price
input uint     market_order_above   = 0;                                // number of market order above current price
input TrendDetectStrategy trendDetectStrategy         = Adx;            // Trend detect strategy
input ENUM_TIMEFRAMES     trendDetectTimeframe        = PERIOD_CURRENT; // Trend detect timeframe
input int                 trendDetectLookbackPeriod   = 5;              // Trend detect lookback
datetime       timePreviousBar      = 0;
TrendMode      trendMode            = Sideway;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
   m_trade.SetExpertMagicNumber(magic_number);
   //--- create a timer with a 1 second period
   EventSetTimer(3);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
      EventKillTimer();
  }

void OnTimer()
{
   if (IsTradeAllowed() == false) { return; }
   OnNewBar();
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
/*
void OnTick()
  {
   if (IsTradeAllowed() == false) { return; }
   if (IsNewBar()) {
      OnNewBar();
   }
   //OnNewBar();
  }
*/
//+------------------------------------------------------------------+

bool IsTradeAllowed(){
    int result = TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
    return result == 1;
}

void OnNewBar() {
   string comment = "";
   comment += timePreviousBar + "\n";
   if (OrdersTotal() == 0) {
      InitialOrders();
   }
   DetectTrend();
   if (trendDetectStrategy != None) {
      if (trendMode == Up) {
         comment += "Up trend\n";
         OpenMarketOrders();
      } else if (trendMode == Down) {
         comment += "Down trend\n";
         CloseAllPositionsIfProfit();
      } else if (trendMode == Sideway) {
         comment += "Sideway\n";
      }
   }
   OpenLimitOrder();
   CloseOrOpenLimitOrderFromBottom();
   if (market_order_above > 0 && PositionsTotal() < market_order_above) {
      OpenMarketOrderForLevelAbove(market_order_above);
   }
   string currency=AccountInfoString(ACCOUNT_CURRENCY);
   ENUM_ACCOUNT_STOPOUT_MODE stopOutMode = (ENUM_ACCOUNT_STOPOUT_MODE) AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE);

   double margin_call=AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL);
   double stop_out=AccountInfoDouble(ACCOUNT_MARGIN_SO_SO);
   comment += currency + "\n";
   comment += "MarginCall=" + margin_call + " StopOut=" + stop_out + "\n";
   if (stopOutMode == ACCOUNT_STOPOUT_MODE_MONEY) {
      comment += "MONEY\n";
   } else {
      comment += "PERCENT\n";
   }
   comment += "ACCOUNT_LEVERAGE =" + AccountInfoInteger(ACCOUNT_LEVERAGE) + "\n";

   comment += "ACCOUNT_PROFIT =" + AccountInfoDouble(ACCOUNT_PROFIT) + "\n";
   
   Comment(comment);
}

bool IsNewBar()
{
   datetime timeCurrentBar = iTime(_Symbol,Period(),0);

   if (timePreviousBar != timeCurrentBar)
   {
      timePreviousBar = timeCurrentBar;
      return true;
   } else {
      return false;
   }
}

void DetectTrend() {
   if (trendDetectStrategy == None) {
      trendMode = Sideway; 
   } else if (trendDetectStrategy == Adx) {
      DetectTrendAdx();
   } else if (trendDetectStrategy == Macd) {
      DetectTrendMacd();
   } else if (trendDetectStrategy == Rsi) {
      DetectTrendRsi();
   } else if (trendDetectStrategy == Stochastic) {
      DetectTrendStochastic();
   } else if (trendDetectStrategy == EMA) {
      DetectTrendEma();
   }
}

void DetectTrendAdx() {
   AdxIndicatorResult result = AdxValue(_Symbol, trendDetectTimeframe, trendDetectLookbackPeriod, 1);
   if (result.main > 25) {
      if (result.plus > result.minus) {
         trendMode = Up;
      } else {
         trendMode = Down;
      }
   } else {
      trendMode = Sideway;
   }
}

void DetectTrendMacd() {
   IndicatorResult result1 = MacdValue(_Symbol, trendDetectTimeframe, 12, 26, 9, 1);
   IndicatorResult result2 = MacdValue(_Symbol, trendDetectTimeframe, 12, 26, 9, 2);
   if (result1.main < result1.signal && result2.main > result2.signal) {
      trendMode = Down;
   } else if (result1.main > result1.signal && result2.main < result2.signal) {
      trendMode = Up;
   }
}

void DetectTrendRsi() {
   double rsi1 = RsiValue(_Symbol, trendDetectTimeframe, trendDetectLookbackPeriod, 1);
   double rsi2 = RsiValue(_Symbol, trendDetectTimeframe, trendDetectLookbackPeriod, 2);
   
   if (rsi1 < 70 && rsi2 > 70) {
      trendMode = Down;
   } else if (rsi1 > 30 && rsi2 < 30) {
      trendMode = Up;
   }
}

void DetectTrendStochastic() {
   IndicatorResult result = StochasticValue(_Symbol, trendDetectTimeframe, 5, 3, 3, 1);
   if (result.main > 80 && result.signal > 80 && result.main < result.signal) {
      trendMode = Down;
   } else if(result.main < 20 && result.signal < 20 && result.main > result.signal) {
      trendMode = Up;
   }
}

void DetectTrendEma() {
   double emaValue = EmaValue(_Symbol, trendDetectTimeframe, trendDetectLookbackPeriod, 1);
   double buyPrice = MarketBuyPrice();
   double sellPrice = MarketSellPrice();
   if (buyPrice > emaValue) {
      trendMode = Up;
   } else if (sellPrice < emaValue) {
      trendMode = Down;
   }
}

//----------------------------------------------------------
// Technical analysis
//----------------------------------------------------------

double RsiValue(string symbol, ENUM_TIMEFRAMES timeframe, int maPeriod, uint index)
{
   double array[];
   
   int handle = iRSI(symbol, timeframe, maPeriod, PRICE_CLOSE);
   if (CopyBuffer(handle, 0, 0, index + 1, array) >= 0) {
      ArraySetAsSeries(array, true);
      return array[index];
   } else {
      return -1;
   }
}


IndicatorResult MacdValue(string symbol, ENUM_TIMEFRAMES timeframe, int fastMa, int slowMa, int signalMa, uint index)
{
   double mainArray[];
   double signalArray[];
   IndicatorResult result;
   int handle = iMACD(symbol, timeframe, fastMa, slowMa, signalMa, PRICE_CLOSE);
   if (CopyBuffer(handle, MAIN_LINE, 0, index + 1, mainArray) < 0) {   
      result.main = -1;
      result.signal = -1;
   }
   if (CopyBuffer(handle, SIGNAL_LINE, 0, index + 1, signalArray) < 0) {   
      result.main = -1;
      result.signal = -1;
   }

   ArraySetAsSeries(mainArray, true);
   ArraySetAsSeries(signalArray, true);
   result.main = mainArray[index];
   result.signal = signalArray[index];
   
   return result;
}

IndicatorResult StochasticValue(string symbol, ENUM_TIMEFRAMES timeframe, int kPeriod, int dPeriod, int slowing, uint index)
{
   double mainArray[];
   double signalArray[];
   IndicatorResult result;
   int handle = iStochastic(symbol, timeframe, kPeriod, dPeriod, slowing, MODE_SMA, STO_LOWHIGH);
   if (CopyBuffer(handle, MAIN_LINE, 0, index + 1, mainArray) < 0) {   
      result.main = -1;
      result.signal = -1;
   }
   if (CopyBuffer(handle, SIGNAL_LINE, 0, index + 1, signalArray) < 0) {   
      result.main = -1;
      result.signal = -1;
   }

   ArraySetAsSeries(mainArray, true);
   ArraySetAsSeries(signalArray, true);
   result.main = mainArray[index];
   result.signal = signalArray[index];
   
   return result;
}

AdxIndicatorResult AdxValue(string symbol, ENUM_TIMEFRAMES timeframe, int maPeriod, uint index)
{
   double mainArray[];
   double plusArray[];
   double minusArray[];
   AdxIndicatorResult result;
   
   int handle = iADX(symbol, timeframe, maPeriod);
   if (CopyBuffer(handle, MAIN_LINE, 0, index + 1, mainArray) < 0) {   
      result.main = -1;
      result.plus = -1;
      result.minus = -1;
   }
   if (CopyBuffer(handle, PLUSDI_LINE, 0, index + 1, plusArray) < 0) {   
      result.main = -1;
      result.plus = -1;
      result.minus = -1;
   }
   if (CopyBuffer(handle, MINUSDI_LINE, 0, index + 1, minusArray) < 0) {   
      result.main = -1;
      result.plus = -1;
      result.minus = -1;
   }
   ArraySetAsSeries(mainArray, true);
   ArraySetAsSeries(plusArray, true);
   ArraySetAsSeries(minusArray, true);
   
   result.main = mainArray[index];
   result.plus = plusArray[index];
   result.minus= minusArray[index];
   
   return result;
}

double EmaValue(string symbol, ENUM_TIMEFRAMES timeframe, int maPeriod, uint index) {
   double array[];
   
   int handle = iMA(symbol, timeframe, maPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if (CopyBuffer(handle, 0, 0, index + 1, array) >= 0) {
      ArraySetAsSeries(array, true);
      return array[index];
   } else {
      return -1;
   }
}

void InitialOrders() {
   double gridPrice;
   double marketBuyPrice = MarketBuyPrice();
   double gridTop = MathMin(max_price, marketBuyPrice);
   for (gridPrice=LowestPendingOpenPrice(); gridPrice < gridTop; gridPrice+=price_gap) {
      m_trade.BuyLimit(lot_size, gridPrice, _Symbol, stoploss_price, gridPrice + price_gap, ORDER_TIME_GTC);
   }
}

void OpenLimitOrder() {
   Print("OpenLimitOrder");
   double gridTop = MarketBuyPrice();
   double minOpenTakeProfitPrice = MinOpenTakeProfitPrice();
   double maxLimitBuyPrice = MaxLimitBuyPrice();
   
   if (maxLimitBuyPrice == 0) return;
   if (minOpenTakeProfitPrice > 0) {
      gridTop = MathMin(gridTop, minOpenTakeProfitPrice - price_gap);
   }
   double gridPrice = maxLimitBuyPrice + price_gap;
   
   if (gridPrice >= gridTop) return;
   
   Print(gridPrice, " ", gridTop);
   for (; gridPrice < gridTop; gridPrice+=price_gap) {
      m_trade.BuyLimit(lot_size, gridPrice, _Symbol, stoploss_price, gridPrice + price_gap, ORDER_TIME_GTC);
   }
}

void CloseOrOpenLimitOrderFromBottom() {
   double topPrice = MinLimitBuyPrice();
   double bottomPrice = LowestPendingOpenPrice();
   if (bottomPrice > topPrice) {
      CloseOrderBelow(bottomPrice);
   } else if (bottomPrice < topPrice) {
      for (double gridPrice = bottomPrice; gridPrice < topPrice; gridPrice+=price_gap) {
         m_trade.BuyLimit(lot_size, gridPrice, _Symbol, stoploss_price, gridPrice + price_gap, ORDER_TIME_GTC);
      }
   } else {
      return;
   }
}

void OpenMarketOrders() {
   double marketBuyPrice = MarketBuyPrice();
   double maxTakeProfitPrice = MaxTakeProfitPrice();
   double maxLimitBuyPrice = MaxLimitBuyPrice();
   double gridPrice = MathMax(maxTakeProfitPrice, maxLimitBuyPrice + price_gap);
   
   if (PositionsTotal() == 0) return; // DO NOT ENTER IF THERE IS NO POSITION (ENTER FOR PULLBACK ONLY)
   if (gridPrice >= max_price) return;
   Print("========== Grid price", gridPrice, " maxTakeProfitPrice", maxTakeProfitPrice, " maxLimitBuyPrice", maxLimitBuyPrice);
   
   for(; gridPrice < max_price; gridPrice += price_gap) {
      if (gridPrice < marketBuyPrice) continue;
      m_trade.Buy(lot_size, _Symbol, marketBuyPrice, stoploss_price, gridPrice + price_gap);
   }
}

void OpenMarketOrderForLevelAbove(uint numberOfLevel) {
   Print("OpenMarketOrderForLevelAbove");
   double marketBuyPrice = MarketBuyPrice();
   double maxTakeProfitPrice = MaxTakeProfitPrice();
   double maxLimitBuyPrice = MaxLimitBuyPrice();

   double expectedTopLevelBuyPrice = maxLimitBuyPrice + (price_gap * numberOfLevel);

   double gridPrice = MathMax(maxTakeProfitPrice, maxLimitBuyPrice + price_gap);
   while (gridPrice <= expectedTopLevelBuyPrice) {
      m_trade.Buy(lot_size, _Symbol, marketBuyPrice, stoploss_price, gridPrice + price_gap);
      gridPrice += price_gap;
   }
}

void CloseAllPositionsIfProfit() {
   if (TotalProfit() > 0) {
      CloseAllPositions();
   }
}

double MarketBuyPrice() {
   return SymbolInfoDouble(_Symbol, SYMBOL_ASK);
}

double MarketSellPrice() {
   return SymbolInfoDouble(_Symbol, SYMBOL_BID);
}

double NormalizeDouble(double value) {
   return NormalizeDouble(value, _Digits);
}

double MaxLimitBuyPrice() {
   int totalOrder = OrdersTotal();
   if (totalOrder == 0) return 0;
   int index;
   double maxLimitPrice = 0; 
   for (index= 0; index < totalOrder; index++) {
      ulong ticket = OrderGetTicket(index);
      if (OrderSelect(ticket) == false) {
         Print("Error selecting order", GetLastError());
         continue;
      }
      if (OrderGetInteger(ORDER_MAGIC) != magic_number) {
         continue;
      }
      
      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE) OrderGetInteger(ORDER_TYPE);
      if (type == ORDER_TYPE_BUY_LIMIT) {
         maxLimitPrice = MathMax(maxLimitPrice, OrderGetDouble(ORDER_PRICE_OPEN));
      }
   }
   maxLimitPrice = NormalizeDouble(maxLimitPrice);
   Print("maxLimitPrice ", maxLimitPrice);
   return maxLimitPrice;
}


double MinLimitBuyPrice() {
   int totalOrder = OrdersTotal();
   if (totalOrder == 0) return -1;
   double minLimitPrice = -1; 
   for (int index = 0; index < totalOrder; index++) {
      ulong ticket = OrderGetTicket(index);
      if (OrderSelect(ticket) == false) {
         Print("Error selecting order", GetLastError());
         continue;
      }
      if (OrderGetInteger(ORDER_MAGIC) != magic_number) {
         continue;
      }
      
      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE) OrderGetInteger(ORDER_TYPE);
      if (type == ORDER_TYPE_BUY_LIMIT) {
         if (minLimitPrice == -1) {
            minLimitPrice = OrderGetDouble(ORDER_PRICE_OPEN);
         } else {
            minLimitPrice = MathMin(minLimitPrice, OrderGetDouble(ORDER_PRICE_OPEN));
         }
      }
   }
   minLimitPrice = NormalizeDouble(minLimitPrice);
   Print("minLimitPrice ", minLimitPrice);
   return minLimitPrice;
}

double MinOpenTakeProfitPrice() {
   int totalPosition = PositionsTotal();
   if (totalPosition == 0) return -1;
   int index;
   double minOpenTakeProfitPrice = -1;
   
   for (index = 0; index < totalPosition; index++) {
      ulong ticket = PositionGetTicket(index);
      if (PositionSelectByTicket(ticket) == false) {
         Print("Error selecting position", GetLastError());
         continue;
      }
      if (PositionGetInteger(POSITION_MAGIC) != magic_number) {
         continue;
      }
      
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);
      if (type == POSITION_TYPE_BUY) {
         if (minOpenTakeProfitPrice == -1) {
            minOpenTakeProfitPrice = PositionGetDouble(POSITION_TP);
         } else {
            minOpenTakeProfitPrice = MathMin(minOpenTakeProfitPrice, PositionGetDouble(POSITION_TP));
         }
      }
   }
   minOpenTakeProfitPrice = NormalizeDouble(minOpenTakeProfitPrice);
   Print("minOpenTakeProfitPrice ", minOpenTakeProfitPrice);
   return minOpenTakeProfitPrice;
}

double MaxTakeProfitPrice() {
   int totalPosition = PositionsTotal();
   if (totalPosition == 0) return -1;
   double maxTakeProfitPrice = 0;
   
   for (int index = 0; index < totalPosition; index++) {
      ulong ticket = PositionGetTicket(index);
      if (PositionSelectByTicket(ticket) == false) {
         Print("Error selecting position", GetLastError());
         continue;
      }
      if (PositionGetInteger(POSITION_MAGIC) != magic_number) {
         continue;
      }
      
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);
      if (type == POSITION_TYPE_BUY) {
         maxTakeProfitPrice  = MathMax(maxTakeProfitPrice , PositionGetDouble(POSITION_TP));
      }
   }
   maxTakeProfitPrice = NormalizeDouble(maxTakeProfitPrice);
   return maxTakeProfitPrice ;
}

double TotalProfit() {
   double allProfit = 0;
   double totalPosition = PositionsTotal();
   if (totalPosition == 0) return 0;
   
   for (int index = 0; index < totalPosition; index++) {
      ulong ticket = PositionGetTicket(index);
      PositionSelectByTicket(ticket);
      
      
      if (PositionGetInteger(POSITION_MAGIC) != magic_number) {
         continue;
      }
      allProfit += PositionGetDouble(POSITION_PROFIT);
   }
   return allProfit;
}

void CloseAllPositions() {
   int totalPosition = PositionsTotal();
   if (totalPosition == 0) return;
   double maxTakeProfitPrice = 0;
   
   for (int index = 0; index < totalPosition; index++) {
      ulong ticket = PositionGetTicket(index);
      // Close only the ticket that open early with market order
      if ((PositionGetDouble(POSITION_TP) - PositionGetDouble(POSITION_PRICE_OPEN)) > price_gap * 1.1) {
         m_trade.PositionClose(ticket);
      }
   }
}

double LowestPendingOpenPrice() {
   double maxLimitBuyPrice = MaxLimitBuyPrice();
   if (maxLimitBuyPrice == 0) {
      maxLimitBuyPrice = MarketBuyPrice();
   }
   double lowestPrice = maxLimitBuyPrice - ((number_pending_order-1) * price_gap);
   double pow10 = MathPow(10, _Digits);
   double roundedLowestPrice = MathRound(lowestPrice * pow10 / price_gap) * price_gap / pow10;
   return MathMax(roundedLowestPrice, min_price);
}

void CloseOrderBelow(double price) {
   int totalOrder = OrdersTotal();
   if (totalOrder == 0) return;
   
   for (int index= 0; index < totalOrder; index++) {
      ulong ticket = OrderGetTicket(index);
      if (OrderSelect(ticket) == false) {
         Print("Error selecting order", GetLastError());
         continue;
      }
      if (OrderGetInteger(ORDER_MAGIC) != magic_number) {
         continue;
      }
      if (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT && OrderGetDouble(ORDER_PRICE_OPEN) < price) {
         m_trade.OrderDelete(ticket);
      }
   }
}