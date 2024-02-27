//+------------------------------------------------------------------+
//|                                          MomentumDynamicGrid.mq4 |
//|                           Copyright 2024, Patompong Manprasatkul |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Patompong Manprasatkul"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

input double GridLow                = 0.86634;
input double GridHigh               = 1.61604;
input int GridLevelCount            = 5;
input int AllocationCountPerLevel   = 1; 
input int MaxSLIPip                 = 5000;

struct GridLevel {
   double high;
   double low;
};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
   GridLevel level = GetCurrentLevel();
   printf(level.high);
   printf(level.low);
   printf(Bid, Ask);
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
//---
   
  }
//+------------------------------------------------------------------+

GridLevel GetCurrentLevel()
{
   double gridGap = (GridHigh - GridLow) / GridLevelCount;
   double currentBuyPrice = MathMax(Ask, Bid);
   int currentLevel = int(currentBuyPrice / gridGap);
   printf("Level %d", currentLevel);
   GridLevel level = { 0.1, 1.1 };
   return level;
}
