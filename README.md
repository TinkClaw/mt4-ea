# TinkClaw MT4/MT5 Expert Advisor

AI-powered trading signals delivered directly to MetaTrader.

## Installation

### MT4
1. Copy `TinkClaw_EA.mq4` to `MQL4/Experts/` in your MT4 data folder
2. Go to **Tools → Options → Expert Advisors**
3. Check "Allow WebRequest for listed URL" and add: `https://api.tinkclaw.com`
4. Compile the EA in MetaEditor (F7)
5. Drag the EA onto any supported chart
6. Enter your TinkClaw API key in the settings

### Getting an API Key
- Free: 50 signals/day → [tinkclaw.com](https://tinkclaw.com)
- Pro ($9.99/mo): 5,000 credits/month, all symbols, ML scoring
- Pro+ ($19.99/mo): 12,000 credits/month, WebSocket, confluence

## Features

| Feature | Free | Pro | Pro+ |
|---------|------|-----|------|
| Signal overlay on chart | Yes | Yes | Yes |
| Regime detection badge | Yes | Yes | Yes |
| Auto-execute trades | - | Yes | Yes |
| Real-time (60s poll) | - | Yes | Yes |
| Confluence scoring | - | - | Yes |

## Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| ApiKey | (required) | Your TinkClaw API key |
| PollIntervalSec | 60 | How often to check for new signals |
| MinConfidence | 65.0 | Minimum confidence to show/trade (0-100) |
| AutoTrade | false | Enable automatic trade execution |
| RiskPercent | 1.0 | % of balance risked per trade |
| MaxSpreadPips | 3.0 | Max spread to enter a trade |
| ShowPanel | true | Show signal info panel on chart |

## Supported Symbols

62 assets: 17 US stocks, 30 crypto, 15 forex pairs.
The EA automatically maps your broker's symbol names to TinkClaw format.

## Risk Disclaimer

TinkClaw provides analytical data only. This is not financial advice.
Past performance does not guarantee future results. Auto-trade at your own risk.
