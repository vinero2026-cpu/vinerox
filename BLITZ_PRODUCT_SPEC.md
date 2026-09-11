# Blitz Mode — Product Specification and Implementation Blueprint

## 1. Executive Summary

Blitz Mode is a 2-minute head-to-head financial arcade match inside the VINEROX ecosystem. The player stakes Vinerox coins, enters a queue, and plays against either a human rival or a smart bot fallback. The match is based on live asset direction prediction, with dynamic chart behavior, layered tactical tools, and real-time ranking and wallet settlement.

This product should be built as a web-first MVP on vinero.app/blitz, with a clean backend contract and gameplay engine that can later be ported to Flutter native with the same rules and API structure.

---

## 2. Product Objective

Create a product that feels like:
- Clash Royale energy and reward loop
- trading simulator and chart prediction gameplay
- live head-to-head competition
- mobile-first fast session design

The central loop is:
1. player loads in
2. chooses stake and loadout
3. queues for match
4. gets human or smart bot opponent
5. plays 2-minute chart direction battle
6. resolves result
7. updates wallet, trophies, rank, and chest rewards

---

## 3. Target User Journey

### 3.1 Onboarding / Identity
- user chooses avatar / club name
- user chooses country flag
- user sees profile card with flag, rank, wallet, and trophies
- no match access until a profile is created

### 3.2 Main Lobby
The lobby shows:
- Vinerox balance
- free chests and opened boxes
- current trophy count
- exact rank / tier
- quick start button: Blitz 1v1
- recent reward summary and last match results

### 3.3 Loadout / Cockpit
Before match begin, the player chooses up to 3 layers:
- Bollinger Bands
- Volume Profile
- Heatmap
- Sentiment Radar

The selected layers become active in the match for visual or tactical advantage.

---

## 4. Match Structure

### 4.1 Match Type
- 1v1 Ranked
- 1v1 Casual
- Future: multiplayer arena on same chart

### 4.2 Match Duration
- 120 seconds
- each second updates price movement and pressure state

### 4.3 Core Action
The player must predict if the chart is going:
- UP
- DOWN

Each correct prediction increases yield and pressure advantage. The trailing player is highlighted red; the leader is highlighted green.

---

## 5. Matchmaking and Smart Bot System

### 5.1 Queue Flow
- player taps Find Rival
- system attempts to match against a human player
- if no player is found within 5-10 seconds, bot fallback activates

### 5.2 Bot Logic
The bot must feel fair and engaging:
- difficulty scales with the player's rank
- bot doesn't always win perfectly
- bot makes mistakes at random thresholds
- bot can sometimes play smarter than expected

Recommended logic:
- difficulty = 1..5
- bot skill score = player rank + random variance
- bot prediction accuracy = 55%-82% depending on difficulty and pressure
- decision noise = random error chance increases when pressure is high

### 5.3 Fairness Rules
- bot cannot be impossible to beat
- results must be deterministic per seed
- payout settlement must be server-authenticated

---

## 6. Game Mechanics: 2-Minute Blitz Loop

### 6.1 Asset Screen
Display:
- large asset name / ticker
- official feed tag
- current date and live clock
- chart line and current price
- side-by-side player HUDs

### 6.2 Price Simulation
At each tick:
- random drift is generated from seeded match state
- the chart and price move based on the match seed
- the user and bot each accumulate directional success and yield stats

### 6.3 Directional Calls
The player presses:
- UP
- DOWN

A call is evaluated against the actual market direction for that tick window.

### 6.4 Score / Gain Rules
- correct call: gain yield %
- wrong call: lose pressure / small negative yield
- successful streaks amplify score visually and monetarily

### 6.5 Finish Condition
When time reaches zero:
- winner is determined from total yield and score differential
- Vinerox pot is settled
- trophies and rankings are updated
- match result is stored in history

---

## 7. Player HUD and Presentation Rules

### 7.1 Visual State
- leading user: green glow + rising indicator
- trailing user: red glow + pressure indicator
- winner pop-up: success %, coin fountain, reward burst

### 7.2 Data Feed UI
Elements:
- asset name
- live price
- market mood
- current date/time
- official arena feed label

### 7.3 Layer Effects
- Bollinger Bands: bands around chart
- Volume Profile: 3D-ish bars at chart base
- Heatmap: background gradients and volatility clouds
- Sentiment Radar: pulse meter of live crowd sentiment

---

## 8. Audio and Gamification

### 8.1 Sound Engine
- background crowd murmur
- sharp crowd roar on strong move
- soft arcade click for action
- reward coin burst on win
- pressure sound on poor call

### 8.2 Reward Chest System
Reward types:
- Vinerox coins
- new layer unlocks
- skin/theme unlocks
- chest rarity tiers

### 8.3 Rank and Trophy System
- winners get trophies
- losers lose trophies
- rank changes are computed server-side
- ladder points and weekly leaderboard are persisted

---

## 9. Economical Rules

### 9.1 Currency
Vinerox is the main in-game economy currency.

### 9.2 Staking Model
- each match entry is a fixed stake amount
- pot = stake * 2
- winner receives the pot
- loser loses stake

### 9.3 Settlement Rules
- pot settlement happens after game over
- transaction must be atomic
- wallet balance must be validated before match start

### 9.4 Rewards
- match win reward
- chest reward
- seasonal ladder advancement
- streak bonuses

---

## 10. Backend API Contract

These are the required backend routes to support a proper Blitz MVP.

### 10.1 Lobby and Identity

#### GET /api/blitz/inventory
Response:
```json
{
  "balance": 340,
  "free_lootboxes_left": 2,
  "loadout": ["bollinger", "volume", "heatmap"],
  "cards": [
    { "card_id": "bollinger", "owned": true },
    { "card_id": "volume", "owned": true },
    { "card_id": "heatmap", "owned": true }
  ]
}
```

#### GET /api/blitz/catalog
Response:
```json
{
  "cards": [
    { "id": "bollinger", "name": "Bollinger Bands" },
    { "id": "volume", "name": "Volume Profile" },
    { "id": "heatmap", "name": "Call Heatmap" },
    { "id": "sentiment", "name": "Sentiment Radar" }
  ]
}
```

#### POST /api/blitz/loadout
Body:
```json
{
  "slots": ["bollinger", "volume", "sentiment"]
}
```

### 10.2 Match Lifecycle

#### POST /api/blitz/match/start
Body:
```json
{
  "mode": "ranked",
  "stake": 10
}
```

Response:
```json
{
  "match_id": "m_10291",
  "seed": 24891,
  "opponent": "CPU Rival",
  "status": "queued",
  "created_at": "2026-09-10T12:00:00Z"
}
```

#### POST /api/blitz/match/result
Body:
```json
{
  "match_id": "m_10291",
  "seed": 24891,
  "mode": "ranked",
  "outcome": "win",
  "my_pnl": 2.42,
  "opp_pnl": -1.67,
  "stake": 10
}
```

Response:
```json
{
  "updated_balance": 330,
  "trophies_delta": 20,
  "rank_delta": 1,
  "reward_chest": "bronze"
}
```

### 10.3 Chests

#### POST /api/blitz/lootbox
Body:
```json
{
  "count": 3
}
```

Response:
```json
{
  "drops": ["volume", "sentiment", "25 V"],
  "new_balance": 355
}
```

---

## 11. Web-First Product Structure

Recommended route structure:
- /blitz
- /blitz/lobby
- /blitz/match
- /blitz/reward
- /blitz/leaderboard

Priority:
1. lobby and loadout
2. queue and matchmaking
3. real match screen
4. result settlement and rewards
5. leaderboard and season progress

---

## 12. Native App Port Plan

Once the web first product is stable and validated:
1. Keep the same API contract
2. Reuse the same match engine rules
3. Port UI into Flutter widgets and canvas
4. Keep the same state machine and reward rules
5. Optimize for touch controls and mobile UI

Important: the flow remains identical; only the shell changes.

---

## 13. Implementation Priority

### Phase 1 — Product Shell
- Blitz landing screen
- loadout card list
- wallet tile
- hero header
- queue button

### Phase 2 — Match Loop
- price simulation
- call buttons
- success/failure state
- score bar and pressure logic

### Phase 3 — Matchmaking
- queue fallback
- bot difficulty
- fair result generation

### Phase 4 — Economy
- wallet updates
- staking and pot logic
- chest rewards
- ranking updates

### Phase 5 — Native Port
- Flutter UI
- same API contract
- same match logic
- polished mobile visuals

---

## 14. Engineering Notes

### Frontend
Recommended stack:
- React/Next.js for web MVP
- Flutter for native mobile later
- Canvas or SVG for chart rendering
- WebSockets for real-time queue and match updates

### Backend
Recommended stack:
- Node.js / TypeScript
- Redis for queue and match state
- Postgres for user wallets, rank, and chest persistence
- WebSockets for live updates

### Security
- server-side validation of all match outcomes
- wallet updates must be atomic
- bot logic must not be client-trusted
- signed match result payloads and player session checks

---

## 15. Final Recommendation

The correct strategy is to build Blitz as a web-first MVP, not a native app-first mock. Once the gameplay, economy, bot balance, and matchmaking are validated in a browser, the same rules can be ported to a native Flutter app without redesigning the product.

This is the correct architecture to avoid building a beautiful but non-working game shell.
