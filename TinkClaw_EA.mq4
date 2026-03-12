//+------------------------------------------------------------------+
//|                                                TinkClaw_EA.mq4   |
//|                        Copyright 2026, TinkClaw Inc.             |
//|                             https://tinkclaw.com                 |
//+------------------------------------------------------------------+
#property copyright "TinkClaw Inc."
#property link      "https://tinkclaw.com"
#property version   "1.0"
#property strict
#property description "AI-powered trading signals from TinkClaw."
#property description "21-layer confluence scoring, regime detection,"
#property description "and ML-enhanced signals — delivered to MT4."

//--- Input Parameters ------------------------------------------------
input string   ApiKey          = "";              // TinkClaw API Key
input string   ApiBaseUrl      = "https://api.tinkclaw.com"; // API Base URL
input int      PollIntervalSec = 60;              // Signal poll interval (seconds)
input double   MinConfidence   = 65.0;            // Min confidence to display (0-100)
input bool     AutoTrade       = false;           // Enable auto-execution
input double   RiskPercent     = 1.0;             // Risk per trade (% of balance)
input double   MaxSpreadPips   = 3.0;             // Max spread to enter trade
input int      SlippagePoints  = 10;              // Max slippage (points)
input int      MagicNumber     = 20260312;        // EA magic number
input bool     ShowPanel       = true;            // Show info panel on chart
input color    BuyColor        = clrLime;         // BUY signal color
input color    SellColor       = clrRed;          // SELL signal color
input color    HoldColor       = clrGray;         // HOLD signal color
input color    PanelBgColor    = C'25,25,40';     // Panel background color
input color    PanelTextColor  = clrWhite;        // Panel text color

//--- Global State ----------------------------------------------------
datetime g_lastPoll       = 0;
string   g_lastSignal     = "HOLD";
double   g_lastConfidence = 0;
string   g_lastRegime     = "unknown";
string   g_lastNarrative  = "";
int      g_httpTimeout    = 10000; // 10 second timeout
string   g_symbol         = "";   // TinkClaw-format symbol

//+------------------------------------------------------------------+
//| Map MT4 symbol to TinkClaw canonical symbol                       |
//+------------------------------------------------------------------+
string MapSymbol(string mt4Symbol)
{
   // Strip broker suffixes (e.g., EURUSDm, EURUSD.ecn)
   string clean = mt4Symbol;
   int dotPos = StringFind(clean, ".");
   if(dotPos > 0) clean = StringSubstr(clean, 0, dotPos);
   if(StringLen(clean) > 6 && StringGetCharacter(clean, StringLen(clean)-1) == 'm')
      clean = StringSubstr(clean, 0, StringLen(clean)-1);

   // Crypto pairs — BTC mapped from BTCUSDx variants
   if(StringFind(clean, "BTC") == 0)   return "BTC";
   if(StringFind(clean, "ETH") == 0)   return "ETH";
   if(StringFind(clean, "SOL") == 0)   return "SOL";
   if(StringFind(clean, "BNB") == 0)   return "BNB";
   if(StringFind(clean, "XRP") == 0)   return "XRP";
   if(StringFind(clean, "DOGE") == 0)  return "DOGE";
   if(StringFind(clean, "ADA") == 0)   return "ADA";
   if(StringFind(clean, "LINK") == 0)  return "LINK";
   if(StringFind(clean, "AVAX") == 0)  return "AVAX";
   if(StringFind(clean, "PEPE") == 0)  return "PEPE";
   if(StringFind(clean, "SUI") == 0)   return "SUI";
   if(StringFind(clean, "DOT") == 0)   return "DOT";
   if(StringFind(clean, "SHIB") == 0)  return "SHIB";

   // Forex pairs — EURUSD stays EURUSD
   if(clean == "EURUSD")  return "EURUSD";
   if(clean == "GBPUSD")  return "GBPUSD";
   if(clean == "USDJPY")  return "USDJPY";
   if(clean == "AUDUSD")  return "AUDUSD";
   if(clean == "USDCAD")  return "USDCAD";
   if(clean == "USDCHF")  return "USDCHF";
   if(clean == "NZDUSD")  return "NZDUSD";
   if(clean == "EURJPY")  return "EURJPY";
   if(clean == "EURGBP")  return "EURGBP";
   if(clean == "GBPJPY")  return "GBPJPY";

   // Commodities
   if(StringFind(clean, "XAUUSD") >= 0 || StringFind(clean, "GOLD") >= 0) return "XAUUSD";
   if(StringFind(clean, "XAGUSD") >= 0 || StringFind(clean, "SILVER") >= 0) return "XAGUSD";
   if(StringFind(clean, "USOIL") >= 0 || StringFind(clean, "WTI") >= 0 || StringFind(clean, "CL") >= 0) return "USOILUSD";
   if(StringFind(clean, "UKOIL") >= 0 || StringFind(clean, "BRENT") >= 0) return "UKOILUSD";

   // US Stocks (if broker provides CFDs)
   if(clean == "AAPL")  return "AAPL";
   if(clean == "MSFT")  return "MSFT";
   if(clean == "GOOGL") return "GOOGL";
   if(clean == "AMZN")  return "AMZN";
   if(clean == "NVDA")  return "NVDA";
   if(clean == "META")  return "META";
   if(clean == "TSLA")  return "TSLA";
   if(clean == "AMD")   return "AMD";
   if(clean == "PLTR")  return "PLTR";
   if(clean == "COIN")  return "COIN";
   if(clean == "MSTR")  return "MSTR";

   // Index
   if(StringFind(clean, "US500") >= 0 || StringFind(clean, "SPX") >= 0 || StringFind(clean, "SP500") >= 0)
      return "US500USD";

   // Fallback — return cleaned symbol
   return clean;
}

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   if(StringLen(ApiKey) == 0)
   {
      Alert("TinkClaw EA: API Key is required. Get one free at tinkclaw.com");
      return INIT_PARAMETERS_INCORRECT;
   }

   g_symbol = MapSymbol(Symbol());
   Print("TinkClaw EA v1.0 initialized | Symbol: ", Symbol(), " → ", g_symbol,
         " | Poll: ", PollIntervalSec, "s | AutoTrade: ", AutoTrade);

   // Enable WebRequest for our API domain
   // User must add api.tinkclaw.com to Tools → Options → Expert Advisors → Allow WebRequest
   if(!IsTradeAllowed() && AutoTrade)
   {
      Alert("TinkClaw EA: Auto-trade enabled but trading is not allowed. Check Expert Advisors settings.");
      return INIT_FAILED;
   }

   EventSetTimer(PollIntervalSec);

   // Initial poll
   PollSignal();

   if(ShowPanel) DrawPanel();

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, "TC_");
   Comment("");
}

//+------------------------------------------------------------------+
//| Timer event — polls TinkClaw API                                  |
//+------------------------------------------------------------------+
void OnTimer()
{
   PollSignal();
   if(ShowPanel) DrawPanel();
}

//+------------------------------------------------------------------+
//| Tick event — check for trade execution                            |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!AutoTrade) return;
   if(g_lastSignal == "HOLD") return;
   if(g_lastConfidence < MinConfidence) return;

   // Check if we already have a position from this EA
   if(CountOpenOrders() > 0) return;

   // Check spread
   double spread = (Ask - Bid) / Point;
   if(spread > MaxSpreadPips * 10) return; // Convert pips to points

   ExecuteSignal(g_lastSignal, g_lastConfidence);
}

//+------------------------------------------------------------------+
//| Poll TinkClaw /v1/signals endpoint                                |
//+------------------------------------------------------------------+
void PollSignal()
{
   string url = ApiBaseUrl + "/v1/signals?symbols=" + g_symbol;
   string headers = "X-API-Key: " + ApiKey + "\r\n"
                    + "Content-Type: application/json\r\n";
   char   postData[];
   char   result[];
   string resultHeaders;

   int httpCode = WebRequest("GET", url, headers, g_httpTimeout, postData, result, resultHeaders);

   if(httpCode == -1)
   {
      int err = GetLastError();
      if(err == 4060)
         Print("TinkClaw: Add ", ApiBaseUrl, " to allowed URLs in Tools → Options → Expert Advisors");
      else
         Print("TinkClaw: HTTP request failed, error ", err);
      return;
   }

   if(httpCode != 200)
   {
      Print("TinkClaw: API returned HTTP ", httpCode);
      return;
   }

   string response = CharArrayToString(result);
   ParseSignalResponse(response);

   g_lastPoll = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Parse JSON signal response                                        |
//| Expected: {"signals":[{"symbol":"BTC","signal":"BUY",            |
//|   "confidence":78.5,"regime":"trending_up",...}]}                  |
//+------------------------------------------------------------------+
void ParseSignalResponse(string json)
{
   // Extract signal direction
   string signal = ExtractJsonString(json, "signal");
   if(signal == "") signal = "HOLD";
   signal = StringToUpper(signal);

   // Extract confidence
   double confidence = ExtractJsonDouble(json, "confidence");

   // Extract regime
   string regime = ExtractJsonString(json, "regime");
   if(regime == "") regime = "unknown";

   // Extract narrative (if present)
   string narrative = ExtractJsonString(json, "narrative");

   // Update globals
   g_lastSignal     = signal;
   g_lastConfidence = confidence;
   g_lastRegime     = regime;
   g_lastNarrative  = narrative;

   // Log
   Print("TinkClaw [", g_symbol, "] Signal: ", signal,
         " | Confidence: ", DoubleToString(confidence, 1), "%",
         " | Regime: ", regime);

   // Chart arrow
   DrawSignalArrow(signal, confidence);
}

//+------------------------------------------------------------------+
//| Simple JSON string field extractor                                |
//+------------------------------------------------------------------+
string ExtractJsonString(string json, string key)
{
   string search = "\"" + key + "\":\"";
   int start = StringFind(json, search);
   if(start < 0) return "";
   start += StringLen(search);
   int end = StringFind(json, "\"", start);
   if(end < 0) return "";
   return StringSubstr(json, start, end - start);
}

//+------------------------------------------------------------------+
//| Simple JSON numeric field extractor                               |
//+------------------------------------------------------------------+
double ExtractJsonDouble(string json, string key)
{
   // Try "key": number (no quotes)
   string search = "\"" + key + "\":";
   int start = StringFind(json, search);
   if(start < 0) return 0;
   start += StringLen(search);

   // Skip whitespace
   while(start < StringLen(json) && StringGetCharacter(json, start) == ' ')
      start++;

   // Read until comma, brace, or bracket
   string numStr = "";
   for(int i = start; i < StringLen(json); i++)
   {
      ushort ch = StringGetCharacter(json, i);
      if(ch == ',' || ch == '}' || ch == ']' || ch == ' ') break;
      numStr += CharToString((uchar)ch);
   }

   return StringToDouble(numStr);
}

//+------------------------------------------------------------------+
//| Draw signal arrow on chart                                        |
//+------------------------------------------------------------------+
void DrawSignalArrow(string signal, double confidence)
{
   if(confidence < MinConfidence) return;

   string name = "TC_Arrow_" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   color arrowColor = HoldColor;
   int arrowCode = 159; // circle

   if(signal == "BUY")
   {
      arrowColor = BuyColor;
      arrowCode = 233; // up arrow
   }
   else if(signal == "SELL")
   {
      arrowColor = SellColor;
      arrowCode = 234; // down arrow
   }
   else return; // Don't draw HOLD arrows

   ObjectCreate(0, name, OBJ_ARROW, 0, TimeCurrent(), signal == "BUY" ? Low[0] : High[0]);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, arrowColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetString(0, name, OBJPROP_TOOLTIP,
      "TinkClaw " + signal + " | " + DoubleToString(confidence, 1) + "% | " + g_lastRegime);
}

//+------------------------------------------------------------------+
//| Draw info panel on chart                                          |
//+------------------------------------------------------------------+
void DrawPanel()
{
   int x = 10, y = 30;
   int width = 280, lineH = 20;

   // Background
   CreateLabel("TC_PanelTitle", x, y, "TinkClaw Signal Engine", PanelTextColor, 11, true);
   y += lineH + 5;

   // Symbol
   CreateLabel("TC_Symbol", x, y,
      "Symbol: " + g_symbol, PanelTextColor, 9, false);
   y += lineH;

   // Signal + Confidence
   color sigColor = HoldColor;
   if(g_lastSignal == "BUY") sigColor = BuyColor;
   if(g_lastSignal == "SELL") sigColor = SellColor;

   CreateLabel("TC_Signal", x, y,
      "Signal: " + g_lastSignal + "  (" + DoubleToString(g_lastConfidence, 1) + "%)",
      sigColor, 10, true);
   y += lineH;

   // Regime
   CreateLabel("TC_Regime", x, y,
      "Regime: " + g_lastRegime, PanelTextColor, 9, false);
   y += lineH;

   // Last update
   string timeStr = (g_lastPoll > 0) ? TimeToString(g_lastPoll, TIME_SECONDS) : "polling...";
   CreateLabel("TC_Updated", x, y,
      "Updated: " + timeStr, clrDarkGray, 8, false);
   y += lineH;

   // Auto-trade status
   string tradeStatus = AutoTrade ? "ENABLED (risk " + DoubleToString(RiskPercent, 1) + "%)" : "OFF";
   color tradeColor = AutoTrade ? clrLime : clrDarkGray;
   CreateLabel("TC_AutoTrade", x, y,
      "Auto-Trade: " + tradeStatus, tradeColor, 8, false);
   y += lineH;

   // Narrative (truncated)
   if(StringLen(g_lastNarrative) > 0)
   {
      string shortNarr = g_lastNarrative;
      if(StringLen(shortNarr) > 60)
         shortNarr = StringSubstr(shortNarr, 0, 57) + "...";
      CreateLabel("TC_Narrative", x, y, shortNarr, clrDarkGray, 8, false);
   }
}

//+------------------------------------------------------------------+
//| Helper: Create or update a chart label                            |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color clr, int fontSize, bool bold)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
}

//+------------------------------------------------------------------+
//| Execute a trade based on signal                                   |
//+------------------------------------------------------------------+
void ExecuteSignal(string signal, double confidence)
{
   double lotSize = CalculateLotSize();
   if(lotSize <= 0) return;

   int cmd = -1;
   double price = 0;
   color arrowClr = clrNONE;

   if(signal == "BUY")
   {
      cmd = OP_BUY;
      price = Ask;
      arrowClr = BuyColor;
   }
   else if(signal == "SELL")
   {
      cmd = OP_SELL;
      price = Bid;
      arrowClr = SellColor;
   }
   else return;

   string comment = "TC|" + g_lastRegime + "|" + DoubleToString(confidence, 0) + "%";

   int ticket = OrderSend(
      Symbol(), cmd, lotSize, price, SlippagePoints,
      0, 0,  // No SL/TP — managed by signal updates
      comment, MagicNumber, 0, arrowClr
   );

   if(ticket > 0)
      Print("TinkClaw: ", signal, " executed | Ticket: ", ticket,
            " | Lots: ", DoubleToString(lotSize, 2),
            " | Confidence: ", DoubleToString(confidence, 1), "%");
   else
      Print("TinkClaw: Order failed, error ", GetLastError());
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage                       |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   double balance = AccountBalance();
   double riskAmount = balance * (RiskPercent / 100.0);

   // Use ATR for dynamic stop distance
   double atr = iATR(Symbol(), PERIOD_H1, 14, 0);
   if(atr <= 0) atr = 100 * Point; // Fallback: 100 points

   double stopDistance = atr * 2.0; // 2x ATR stop
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);

   if(tickValue <= 0 || tickSize <= 0 || stopDistance <= 0)
      return MarketInfo(Symbol(), MODE_MINLOT);

   double lots = riskAmount / ((stopDistance / tickSize) * tickValue);

   // Clamp to broker limits
   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

   lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(lots, minLot);
   lots = MathMin(lots, maxLot);

   return lots;
}

//+------------------------------------------------------------------+
//| Count open orders for this EA + symbol                            |
//+------------------------------------------------------------------+
int CountOpenOrders()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != MagicNumber) continue;
      if(OrderSymbol() != Symbol()) continue;
      count++;
   }
   return count;
}

//+------------------------------------------------------------------+
