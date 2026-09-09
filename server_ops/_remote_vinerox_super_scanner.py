"""
VINEROX Super Scanner Daemon
─────────────────────────────────────────────────────────────────────────────
Institutional-grade stock scanner — finds stocks with high probability of
significant positive returns in the short term (1–5 days).

Scoring model (1-100) mirrors top hedge-fund quant screens:
  1. Momentum / RVOL         (20 pts) — relative volume & price momentum
  2. Trend Alignment         (20 pts) — EMA stack, ADX
  3. Squeeze / VCP           (20 pts) — Bollinger/KC squeeze, tight price action
  4. Relative Strength       (15 pts) — vs SPY over 20 days
  5. Breakout Quality        (15 pts) — distance from 52w high, volume confirm
  6. Fundamental Proxy       (10 pts) — market cap tier

Bonus rules:
  + RSI in accumulation zone (30-50): +10 pts
  + ADX ≥ 40 (very strong trend): +5 pts

Architecture:
  • Stage 1 — Daily screen ALL filtered US tickers (~1700)
  • Stage 2 — Store score ≥ 70 in explosion_candidates (vinerox_sentinel.db)
  • Stage 3 — Send Telegram alerts for score ≥ 80 (top 10 per cycle)
  • Runs every 4 hours in a tight loop
─────────────────────────────────────────────────────────────────────────────
"""

import yfinance as yf
import pandas as pd
import numpy as np
import sqlite3
import time
import requests
import os
import sys
import math
import logging
from datetime import datetime, timedelta

# ── Optimizer: load dynamic penalty rules (updated by vinerox_optimizer.py) ──
_OPTIMIZER_RULES: dict = {}

def _refresh_optimizer_rules():
    """Load latest penalty rules from optimizer_state table. Called once per scan cycle."""
    global _OPTIMIZER_RULES
    try:
        from vinerox_optimizer import load_rules
        _OPTIMIZER_RULES = load_rules()
    except Exception:
        _OPTIMIZER_RULES = {}

# ── CONFIG ────────────────────────────────────────────────────────────────────
try:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from vinerox_config import TELEGRAM_TOKEN, TELEGRAM_CHAT_ID
except Exception:
    TELEGRAM_TOKEN            = "8542820894:AAEHdWTREu6HPE8AR2meunqc35PvXcBq04o"
    TELEGRAM_CHAT_ID          = "6489061196"
DB_PATH                   = r"/opt/vinerox/data/vinerox_sentinel.db"
# 3-tier architecture:
#   1) data/master_universe.csv     (~11.7K — all known US tickers)
#   2) data/active_universe.csv     (~4.4K — passed price+liquidity pre-filter) ← PRIMARY
#   3) data/hot_list.csv            (~200  — top of light_scanner, optional fast path)
TICKERS_PATH              = r"/opt/vinerox/data/active_universe.csv"
TICKERS_FALLBACK_PATH     = r"/opt/vinerox/data/hot_list.csv"
LOG_PATH                  = r"/opt/vinerox/data/logs/super_scanner.log"

SCAN_INTERVAL_H           = 4        # hours between scans
TOP_CANDIDATE_THRESHOLD   = 65       # min score to store in DB
TELEGRAM_ALERT_THRESHOLD  = 80       # min score to send Telegram
BATCH_SIZE                = 50       # tickers per yfinance batch
BATCH_DELAY_S             = 3        # seconds between batches (rate limit; raised for 4.4K universe)
MAX_TELEGRAM_ALERTS       = 5        # max picks per Telegram message (GOLD-only = fewer, higher quality)
TELEGRAM_GOLD_ONLY        = True     # when True: only GOLD / BESTSTOCK reach Telegram

FALLBACK_TICKERS = [
    'AAPL', 'MSFT', 'NVDA', 'AMD', 'TSLA', 'AMZN', 'META', 'GOOGL', 'NFLX',
    'JPM', 'BAC', 'GS', 'XOM', 'CVX', 'UNH', 'LLY', 'ABBV', 'PFE', 'TMO',
    'AVGO', 'ORCL', 'CRM', 'ADBE', 'QCOM', 'MU', 'SMCI', 'MRVL', 'ARM',
]

# ── LOGGING ───────────────────────────────────────────────────────────────────
os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [SCANNER] %(levelname)s: %(message)s',
    handlers=[
        logging.FileHandler(LOG_PATH, encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)
log = logging.getLogger('VINEROX_SCANNER')


# ── UTILITIES ─────────────────────────────────────────────────────────────────
def safe_float(val, default=0.0):
    try:
        v = float(val)
        return default if (math.isnan(v) or math.isinf(v)) else v
    except Exception:
        return default


def safe_int(val, lo=1, hi=100, default=50):
    try:
        v = float(val)
        if math.isnan(v) or math.isinf(v):
            return default
        return int(max(lo, min(hi, round(v))))
    except Exception:
        return default


def send_telegram(message):
    url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
    try:
        r = requests.post(url, data={"chat_id": TELEGRAM_CHAT_ID, "text": message}, timeout=10)
        if r.status_code != 200:
            log.warning(f"Telegram HTTP {r.status_code}: {r.text[:200]}")
        return r.status_code == 200
    except Exception as e:
        log.error(f"Telegram send failed: {e}")
        return False


def _read_tickers_csv(path):
    """Read tickers from a CSV that may be plain (one symbol per line) or
    have a header with a 'ticker' column. Returns list[str] or None."""
    if not os.path.exists(path):
        return None
    try:
        with open(path, encoding='utf-8') as f:
            rows = [ln.strip() for ln in f if ln.strip()]
        if not rows:
            return None
        # Detect header
        header = rows[0].lower()
        if ',' in rows[0] and ('ticker' in header or 'symbol' in header):
            cols = [c.strip().lower() for c in rows[0].split(',')]
            try:
                idx = cols.index('ticker')
            except ValueError:
                idx = cols.index('symbol')
            tickers = []
            for ln in rows[1:]:
                parts = ln.split(',')
                if idx < len(parts):
                    t = parts[idx].strip().upper()
                    if t and t.isascii():
                        tickers.append(t)
            return tickers or None
        # Plain list (one ticker per line, possibly with commas — take first field)
        return [r.split(',')[0].strip().upper() for r in rows if r.split(',')[0].strip()]
    except Exception as e:
        log.warning(f"Failed to read {path}: {e}")
        return None


def load_tickers():
    # Primary: full active universe (~4.4K — passed price+liquidity pre-filter)
    tickers = _read_tickers_csv(TICKERS_PATH)
    src = "ACTIVE_UNIVERSE"
    if not tickers:
        # Secondary fallback: hot_list (~200 — light_scanner top picks)
        tickers = _read_tickers_csv(TICKERS_FALLBACK_PATH)
        src = "HOT_LIST"
        if tickers:
            log.warning(f"active_universe missing — falling back to HOT_LIST: "
                        f"{len(tickers)} tickers from {TICKERS_FALLBACK_PATH}")
        else:
            # Last resort
            log.warning(f"All ticker files missing — using FALLBACK ({len(FALLBACK_TICKERS)} tickers)")
            return FALLBACK_TICKERS

    # ── HEDGE-FUND INSTRUMENT FILTER ───────────────────────────────────
    # Exclude ETFs / mutual funds / SPACs / units / warrants / REITs.
    # The system's purpose is to find single-stock catalysts; these
    # tracker / income vehicles cannot "explode" in the meaningful sense.
    try:
        from vinerox_instrument_filter import filter_universe
        before = len(tickers)
        tickers = filter_universe(tickers)
        removed = before - len(tickers)
        log.info(f"Loaded {len(tickers)} tickers from {src} "
                 f"(after instrument filter: removed {removed} non-equities)")
    except Exception as e:
        log.warning(f"Instrument filter unavailable ({e}); using raw universe of {len(tickers)}")
    return tickers


# ── DATABASE ──────────────────────────────────────────────────────────────────
def _fix_yfinance_cache():
    """Clear corrupted yfinance timezone/cookie cache."""
    import glob
    cache_dirs = [
        os.path.join(os.path.expanduser('~'), '.yfinance'),
        os.path.join(os.path.expanduser('~'), 'AppData', 'Local', 'py-yfinance'),
        os.path.join(os.environ.get('LOCALAPPDATA', ''), 'py-yfinance'),
    ]
    removed = 0
    for d in cache_dirs:
        for db_file in glob.glob(os.path.join(d, '*.db')):
            try:
                import sqlite3 as _sq
                c = _sq.connect(db_file, timeout=2)
                c.execute("SELECT 1")
                c.close()
            except Exception:
                try:
                    os.remove(db_file)
                    log.info(f"Removed corrupt yfinance cache: {db_file}")
                    removed += 1
                except Exception:
                    pass
    if removed:
        log.info(f"Cleared {removed} corrupt yfinance cache file(s)")


def ensure_db():
    conn = sqlite3.connect(DB_PATH, timeout=30)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS explosion_candidates (
            ticker          TEXT PRIMARY KEY,
            score           INTEGER,
            explosion_score INTEGER,
            prox_score      INTEGER,
            price           REAL,
            buy_price       REAL,
            rvol            REAL,
            volume          INTEGER,
            avg_volume      INTEGER,
            rsi             REAL,
            adx             REAL,
            squeeze         INTEGER,
            trend_status    TEXT,
            telegram_status TEXT DEFAULT 'PENDING',
            last_alert_sent TEXT,
            quality_flag    TEXT,
            last_updated    TEXT
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS scan_log (
            id               INTEGER PRIMARY KEY AUTOINCREMENT,
            scan_time        TEXT,
            tickers_scanned  INTEGER,
            candidates_found INTEGER,
            alerts_sent      INTEGER
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS watchlist (
            id               INTEGER PRIMARY KEY AUTOINCREMENT,
            ticker           TEXT NOT NULL,
            entry_price      REAL NOT NULL,
            entry_score      INTEGER,
            entry_date       TEXT NOT NULL,
            current_price    REAL,
            pnl_pct          REAL DEFAULT 0.0,
            pnl_abs          REAL DEFAULT 0.0,
            last_price_update TEXT,
            status           TEXT DEFAULT 'ACTIVE'
        )
    """)
    # Ensure all columns exist (migration-safe)
    existing_cols = {r[1] for r in conn.execute("PRAGMA table_info(explosion_candidates)").fetchall()}
    new_cols = {
        'volume': 'INTEGER', 'avg_volume': 'INTEGER', 'rsi': 'REAL',
        'adx': 'REAL', 'squeeze': 'INTEGER', 'buy_price': 'REAL',
        'quality_flag': 'TEXT', 'last_alert_sent': 'TEXT',
        'trend_status': 'TEXT',
        'base_weeks':        'INTEGER',
        'pocket_pivot':      'INTEGER',
        'rs_new_high':       'INTEGER',
        'setup_type':        'TEXT',
        'cmf':               'REAL',
        'nr7':               'INTEGER',
        'weekly_stage2':     'INTEGER',
        'expected_move_pct': 'REAL',
        # Smart Money signals — dark_pool populated inline; rest by enrich_smart_money()
        'dark_pool':         'INTEGER',
        'uoa_flag':          'INTEGER',
        'insider_buying':    'INTEGER',
        'short_squeeze':     'INTEGER',
        'pead':              'INTEGER',
        'sm_score':          'INTEGER',
        # Risk safeguards (ACHC lesson 2026-04-30)
        'earnings_days_away': 'INTEGER',
        'gaps_gt5':           'INTEGER',
        'gap_max_down':       'REAL',
        # Position sizing (ATR-based risk normalization)
        'atr_pct':            'REAL',
        # Live buy/sell recommendation (recalculated each scan)
        'recommendation':     'TEXT',
    }
    for col, dtype in new_cols.items():
        if col not in existing_cols:
            try:
                conn.execute(f"ALTER TABLE explosion_candidates ADD COLUMN {col} {dtype}")
            except Exception:
                pass
    conn.commit()
    conn.close()
    log.info(f"DB ready: {DB_PATH}")


# ── SCORING ENGINE ────────────────────────────────────────────────────────────
def score_ticker_daily(ticker: str, spy_close: pd.Series) -> dict | None:
    """
    7-Factor Institutional Quantitative Model (1–100)
    Identifies institutional accumulation BEFORE breakout — not after.

    Factors                         Max
    ──────────────────────────────  ────
    1. Momentum Quality             20   RVOL sweet-spot + velocity gradient
    2. Trend Structure              18   EMA depth + ADX credibility weight
    3. Volatility Setup / Squeeze   18   BB/KC squeeze + ATR compression + VCP
    4. Relative Strength vs SPY     14   dual-timeframe 5d + 20d
    5. Technical Entry Zone         14   consolidation depth + EMA21 support
    6. Smart Volume (OBV + ratio)    8   accumulation vs distribution footprint
    7. Fundamental Tier              8   market cap quality tier
    ──────────────────────────────  ────
    Sub-total                       100
    Bonuses  (RSI zone, ADX, bull-flag)   +15 max
    Penalties (overbought, distribution)  −13 max
    → capped at 1–100
    """
    try:
        # Check module-level cache first (populated by run_scan batch download)
        if ticker in _HIST_CACHE:
            hist = _HIST_CACHE[ticker].copy()
        else:
            hist = yf.download(ticker, period='6mo', interval='1d',
                               auto_adjust=True, progress=False)
        if hist.empty or len(hist) < 30:
            return None

        if isinstance(hist.columns, pd.MultiIndex):
            hist.columns = hist.columns.get_level_values(0)
        hist.columns = [c.lower() for c in hist.columns]

        close = hist['close'].astype(float)
        high  = hist['high'].astype(float)
        low   = hist['low'].astype(float)
        vol   = hist['volume'].astype(float)

        price = safe_float(close.iloc[-1])
        if price <= 1.0 or price > 50000:
            return None

        # ── ADR / FOREIGN FINANCIAL BLOCKER ──────────────────────────────────
        # Korean/Chinese/Foreign bank ADRs (SHG, KB, WF, HDB, IBN, BSAC, etc.)
        # behave like macro-driven instruments, not US growth stocks.
        # They pass RVOL/ATR filters but CANNOT make 30%+ explosive moves.
        # Detection: ticker is 2-3 chars AND avg daily dollar volume $20M-$500M
        # AND price is stable (ATR-proxy: last 20d range / price < 2.5%)
        # We don't block them from scoring (might be valid), but cap at SILVER.
        _adr_suspect = False
        # Known foreign-bank ADR tickers AND infrastructure/utility tickers that
        # repeatedly appear incorrectly as explosive candidates
        _FOREIGN_BANK_BLOCK = {
            'KB', 'SHG', 'WF', 'SHI', 'HDB', 'IBN', 'BSAC', 'ITUB', 'BBD',
            'BBDO', 'UBS', 'CS', 'DB', 'ING', 'BCS', 'SAN', 'BBVA', 'NMR',
            # Infrastructure/EPC contractors — stable, not explosive US growth
            'AGX',   # Argan Inc — power plant contractor
        }
        if ticker.upper() in _FOREIGN_BANK_BLOCK:
            _adr_suspect = True

        # ── Liquidity gate (stricter — institutional quality only) ─────────────
        avg_vol_20 = safe_float(vol.iloc[-21:-1].mean())
        cur_vol    = safe_float(vol.iloc[-1])
        dollar_vol = price * avg_vol_20
        if dollar_vol < 5_000_000:   # $5M minimum avg daily dollar volume
            return None
        if avg_vol_20 < 100_000:     # 100k minimum avg daily shares
            return None
        # ETF / mega-fund filter: >$500M avg daily dollar volume = index ETF or mega-cap utility.
        # Large-cap growth stocks (NVDA, TSLA, etc.) with real catalysts ARE explosive candidates.
        # DVY/PFF/SPY (~$500M+ /day) are excluded; NVDA/TSLA/META (~$100-400M) are NOT blocked.
        if dollar_vol > 500_000_000:
            return None   # Ultra-liquid index ETF or mega-fund — not a directional mover

        rvol = (cur_vol / avg_vol_20) if avg_vol_20 > 0 else 0.0

        # ── EARNINGS PROXIMITY ────────────────────────────────────────────────
        # Earnings check is deferred to Phase 3 in run_scan (after scoring).
        # Initialize placeholders only — values will be set by run_scan Phase 3.
        earnings_days_away = None
        earnings_risk      = False

        # Hard exclusion: never score a stock with imminent/fresh earnings
        if earnings_risk:
            return None

        # ── GAP RISK SCORE ────────────────────────────────────────────────────
        # ACHC lesson: gaps DOWN skip stop-losses and cause uncontrolled losses.
        # Gap-UPS are NOT a risk — they are the move we want to catch (e.g. BAND +43%).
        # So hard-exclude is based on DOWN gaps only.
        gap_history  = ((hist['open'] / hist['close'].shift()) - 1) * 100
        gaps_gt5_dn  = int((gap_history < -5.0).sum())   # only DOWN gaps — stop-loss risk
        gaps_gt5     = int((gap_history.abs() > 5.0).sum())  # both dirs (for display/penalty)
        gaps_gt10    = int((gap_history.abs() > 10.0).sum())
        max_gap_dn   = float(gap_history.min()) if len(gap_history) > 0 else 0.0
        # Hard-exclude only for DOWN gap risk (stop-loss cannot protect a gapping-down stock)
        if gaps_gt5_dn >= 3 or max_gap_dn <= -15.0:
            return None   # gap-down-prone: stop-loss unreliable

        # ── Multi-timeframe returns ────────────────────────────────────────────
        def pct(n):
            return safe_float((close.iloc[-1] - close.iloc[-(n+1)]) /
                              (close.iloc[-(n+1)] + 1e-10)) if len(close) > n else 0.0
        pct3, pct5, pct10, pct20 = pct(3), pct(5), pct(10), pct(20)

        # Dark Pool Accumulation proxy (free — no extra API call required)
        # Signature: RVOL 2x+ normal, but price barely moved = institutions absorbing supply
        dark_pool = (
            (rvol >= 3.0 and abs(pct5) < 0.008) or
            (rvol >= 2.5 and abs(pct5) < 0.012) or
            (rvol >= 2.0 and abs(pct5) < 0.015 and pct5 > 0)   # positive drift + absorption
        )

        # ── RSI (14) ───────────────────────────────────────────────────────────
        delta   = close.diff()
        gain    = delta.clip(lower=0).rolling(14).mean()
        loss    = (-delta.clip(upper=0)).rolling(14).mean()
        rsi_val = safe_float((100 - 100 / (1 + gain / (loss + 1e-10))).iloc[-1])

        # ── True Range ────────────────────────────────────────────────────────
        tr = pd.concat([
            high - low,
            (high - close.shift()).abs(),
            (low  - close.shift()).abs()
        ], axis=1).max(axis=1)

        # ATR compression ratio (5d ATR vs 20d ATR baseline)
        atr5_val  = safe_float(tr.iloc[-5:].mean())
        atr20_val = safe_float(tr.iloc[-21:-1].mean())
        atr_comp  = (atr5_val / atr20_val) if atr20_val > 0 else 1.0
        # Minimum daily ATR: < 0.4% = ETF, utility, or bond fund — not an explosive candidate
        # This catches instruments that dollar_vol filter misses (mid-sized ETFs, BDCs)
        atr_pct_20 = (atr20_val / price) if price > 0 else 0.0
        if atr_pct_20 < 0.004:   # < 0.4% avg daily move = structurally unable to make 30%+
            return None

        # ── ADX (14, rolling DI method) — only credit uptrend (+DI > −DI) ─────
        adx_val = plus_di = minus_di = 0.0
        if len(close) >= 28:
            try:
                atr14    = tr.rolling(14).mean()
                pdm_raw  = high.diff().clip(lower=0)
                ndm_raw  = (-low.diff()).clip(lower=0)
                pdm      = pdm_raw.where(pdm_raw > ndm_raw, 0.0)
                ndm      = ndm_raw.where(ndm_raw > pdm_raw, 0.0)
                pdi_s    = 100 * pdm.rolling(14).mean() / (atr14 + 1e-10)
                ndi_s    = 100 * ndm.rolling(14).mean() / (atr14 + 1e-10)
                dx_s     = 100 * (pdi_s - ndi_s).abs() / (pdi_s + ndi_s + 1e-10)
                adx_val  = safe_float(dx_s.rolling(14).mean().iloc[-1])
                plus_di  = safe_float(pdi_s.iloc[-1])
                minus_di = safe_float(ndi_s.iloc[-1])
            except Exception:
                adx_val = plus_di = minus_di = 0.0

        # ── EMAs ──────────────────────────────────────────────────────────────
        ema9_v  = safe_float(close.ewm(span=9,  adjust=False).mean().iloc[-1])
        ema21_v = safe_float(close.ewm(span=21, adjust=False).mean().iloc[-1])
        ema50_v = safe_float(close.ewm(span=50, adjust=False).mean().iloc[-1])

        # ── Chaikin Money Flow (CMF, 20-day) ──────────────────────────────────
        # Positive = institutional accumulation. > 0.10 = strong buy pressure.
        cmf_val = 0.0
        if len(close) >= 21:
            try:
                hl_range = (high - low).replace(0, np.nan)
                mfm = ((close - low) - (high - close)) / hl_range   # money flow multiplier
                mfv = mfm * vol                                       # money flow volume
                cmf_val = safe_float(mfv.iloc[-20:].sum() / (vol.iloc[-20:].sum() + 1e-10))
            except Exception:
                cmf_val = 0.0

        # ── NR7 (Narrow Range 7) ──────────────────────────────────────────────
        # Today's range is the tightest of the last 7 days: contraction before expansion
        nr7 = False
        if len(close) >= 8:
            today_range = safe_float(high.iloc[-1] - low.iloc[-1])
            min_range_7 = safe_float((high.iloc[-7:] - low.iloc[-7:]).min())
            nr7 = (today_range > 0 and today_range <= min_range_7 * 1.05)

        # ── Weekly Stage 2 (30-week MA) ───────────────────────────────────────
        # Price above rising 30-week MA = institutions holding for big move
        weekly_stage2 = False
        if len(close) >= 150 and isinstance(close.index, pd.DatetimeIndex):
            try:
                wc  = close.resample('W').last().dropna()
                if len(wc) >= 32:
                    wma30 = wc.rolling(30).mean()
                    curr_wma  = safe_float(wma30.iloc[-1])
                    prior_wma = safe_float(wma30.iloc[-5])
                    curr_wc   = safe_float(wc.iloc[-1])
                    if curr_wma > 0 and curr_wc > curr_wma and curr_wma > prior_wma:
                        weekly_stage2 = True
            except Exception:
                pass

        # ══ ADVANCED SETUP SIGNALS ═══════════════════════════════════════════
        # Identifies stocks about to make 30-50%+ explosive moves
        # ─────────────────────────────────────────────────────────────────────

        # (1) MULTI-WEEK BASE / VCP (Minervini)
        # After a prior run-up, the stock consolidates in a tight range.
        # Longer + tighter base = more coiled spring = explosive breakout.
        # 6-8 week flat base (<12% depth) is the textbook setup for 30-50%+ moves.
        base_weeks  = 0
        base_depth  = 1.0    # worst case
        if len(close) >= 35:
            try:
                weekly_high  = high.resample('W').max()
                weekly_low   = low.resample('W').min()
                weekly_close = close.resample('W').last()
                if len(weekly_close) >= 4:
                    wc = weekly_close.iloc[-26:] if len(weekly_close) > 26 else weekly_close
                    wl = weekly_low.iloc[-26:]   if len(weekly_low)   > 26 else weekly_low
                    peak_idx = int(wc.values.argmax())
                    if peak_idx < len(wc) - 2:          # peak is not the most recent week
                        peak_price = safe_float(wc.iloc[peak_idx])
                        base_lows  = wl.iloc[peak_idx:]
                        base_min   = safe_float(base_lows.min())
                        base_depth = max(0.0, 1.0 - base_min / (peak_price + 1e-10))
                        base_weeks = max(0, len(base_lows) - 1)
            except Exception:
                pass

        # (2) POCKET PIVOT (Gil Morales)
        # Today's volume > the highest DOWN-day volume of the last 10 sessions.
        # This is the institutional buying footprint BEFORE the price breaks out.
        # False positives are rare — when this fires alongside base/RS it is elite.
        pocket_pivot = False
        if len(close) >= 12:
            today_v = safe_float(vol.iloc[-1])
            dn_vols = [
                safe_float(vol.iloc[-i])
                for i in range(2, 12)
                if close.iloc[-i] < close.iloc[-(i + 1)]
            ]
            if dn_vols and today_v > max(dn_vols) and close.iloc[-1] > close.iloc[-2]:
                pocket_pivot = True

        # (3) RS LINE AT NEW HIGH (IBD / William O'Neil)
        # The stock / SPY ratio line makes a NEW 52-week high.
        # When this fires BEFORE the price makes a new high it is the single best
        # leading indicator of an impending explosive move (stocks do this 70%+
        # of the time before a 20%+ price breakout).
        rs_new_high = False
        if spy_close is not None and len(spy_close) >= 63 and len(close) >= 63:
            try:
                spy_aligned = spy_close.reindex(close.index, method='ffill')
                rs_line     = close / (spy_aligned + 1e-10)
                rs_window   = min(len(rs_line), 252)
                rs_52w_max  = safe_float(rs_line.rolling(rs_window).max().iloc[-1])
                rs_curr     = safe_float(rs_line.iloc[-1])
                rs_new_high = rs_52w_max > 0 and rs_curr >= rs_52w_max * 0.97
            except Exception:
                pass

        # (4) NEAR PIVOT (20-day) — price within 5% of recent base top.
        # A stock at 95-100% of its 20-day high is sitting at the launch pad.
        # This is TIGHTER than the 52w check in F5 — it detects the CURRENT cycle.
        high_20d       = safe_float(high.iloc[-20:].max()) if len(high) >= 20 else price
        near_pivot_20d = (price / high_20d >= 0.95) if high_20d > 0 else False

        # (5) VOLUME DRY-UP — last 5-day avg volume < 75% of 20-day average.
        # Dry volume near a pivot = nobody selling = coiled spring before explosion.
        # This is the #1 institutional tell before a 30-50%+ breakout move.
        rvol_5d_avg   = safe_float(vol.iloc[-5:].mean() / (avg_vol_20 + 1e-10)) if len(vol) >= 5 else 1.0
        volume_dry_up = rvol_5d_avg < 0.75

        # Coiling setup = "spring loaded": near pivot + dry volume + proper base.
        # Classic BAND-type setup: tight consolidation, price at top, no sellers.
        coiling_setup = near_pivot_20d and volume_dry_up and base_weeks >= 1  # 1-week min base (fresh breakouts allowed)

        # ── RSI BLOW-OFF HARD EXIT ────────────────────────────────────────────
        # RSI > 85: true parabolic blow-off — vertical extension, no safe entry.
        # RSI 71-85: breakout momentum zone — stocks HERE are the ones that move +20-40%.
        # Entry in RSI 72-82 IS the institutional breakout entry (CANSLIM / O'Neil style).
        if rsi_val > 85:
            return None   # parabolic blow-off — disqualified (RSI > 85 = vertical extension)

        # ═══════════════════════════════════════════════════════════════════════
        # FACTOR 1 — MOMENTUM QUALITY (0–20)
        # RVOL sweet spot = 2–4x (institutional flow, not retail FOMO)
        # pct5 sweet spot = 2–8% (building, not exhausted)
        # ═══════════════════════════════════════════════════════════════════════
        f1 = 0
        if   1.5 <= rvol < 2.0:  f1 += 6
        elif 2.0 <= rvol < 3.0:  f1 += 10
        elif 3.0 <= rvol < 4.5:  f1 += 12   # optimal
        elif 4.5 <= rvol < 7.0:  f1 += 7    # possible news event
        elif rvol >= 7.0:        f1 += 3    # blow-off risk
        elif rvol >= 1.0:        f1 += 3

        if   0.015 <= pct3 and 0.02 <= pct5 < 0.08:  f1 += 8   # ideal gradient
        elif 0.01  <= pct5 < 0.14:                    f1 += 5
        elif pct5  >= 0.14:                           f1 += 1   # extended / exhausted
        elif 0.005 <= pct5 < 0.01:                    f1 += 2

        # Momentum acceleration: recent move pacing but not over-extended (10d)
        if pct3 > 0 and 0.02 <= pct10 < 0.18:
            f1 += 2

        # PRE-BREAKOUT COIL: only reward when RVOL confirms breakout is happening.
        # DATA 2026-05: entry_squeeze ρ=-0.22 with 7d returns. Pure coiling = no edge.
        # Coiling + RVOL >= 1.2 = breakout NOW = valid. Coiling alone = still waiting.
        if rvol < 1.0 and coiling_setup:
            f1 += 0   # dry squeeze: not breaking out yet, no momentum credit
        elif rvol < 1.0 and near_pivot_20d and base_weeks >= 2:
            f1 += 1   # minimal credit — near pivot but no volume confirmation
        f1 = min(f1, 20)

        # ═══════════════════════════════════════════════════════════════════════
        # FACTOR 2 — TREND STRUCTURE (0–18)
        # EMA alignment + ADX quality only when +DI > −DI
        # ═══════════════════════════════════════════════════════════════════════
        f2 = 0
        if price > ema9_v:  f2 += 3
        if price > ema21_v: f2 += 3
        if price > ema50_v: f2 += 3
        if ema9_v > ema21_v > ema50_v: f2 += 3   # full bull stack
        elif ema9_v > ema21_v:         f2 += 1   # partial

        if plus_di > minus_di:   # uptrend confirmed
            if   adx_val >= 45:  f2 += 6
            elif adx_val >= 35:  f2 += 5
            elif adx_val >= 25:  f2 += 3
            elif adx_val >= 18:  f2 += 1
        f2 = min(f2, 18)

        # ═══════════════════════════════════════════════════════════════════════
        # FACTOR 3 — VOLATILITY SETUP / SQUEEZE (0–18)
        # Compression before explosion — the setup institutions wait for
        # ═══════════════════════════════════════════════════════════════════════
        f3 = 0
        squeeze_on = False
        if len(close) >= 20:
            ma20  = close.rolling(20).mean()
            std20 = close.rolling(20).std()
            atr20 = tr.rolling(20).mean()
            bb_lo = ma20 - 2 * std20
            bb_up = ma20 + 2 * std20
            kc_lo = ma20 - 1.5 * atr20
            kc_up = ma20 + 1.5 * atr20

            squeeze_on = (
                safe_float(bb_lo.iloc[-1]) > safe_float(kc_lo.iloc[-1]) and
                safe_float(bb_up.iloc[-1]) < safe_float(kc_up.iloc[-1])
            )
            if squeeze_on:
                f3 += 10   # classic Bollinger/Keltner squeeze

            # ATR compression
            if   atr_comp < 0.55:  f3 += 6   # extreme coil
            elif atr_comp < 0.70:  f3 += 4   # solid
            elif atr_comp < 0.85:  f3 += 2

            # VCP: range tightening (last 5 vs 20-day range)
            r5  = safe_float(high.iloc[-5:].max() - low.iloc[-5:].min())
            r20 = safe_float(high.iloc[-20:].max() - low.iloc[-20:].min())
            if r20 > 0:
                tightness = r5 / r20
                if   tightness < 0.20:  f3 += 4
                elif tightness < 0.30:  f3 += 2
        f3 = min(f3, 18)

        # ═══════════════════════════════════════════════════════════════════════
        # FACTOR 4 — RELATIVE STRENGTH vs SPY (0–14)
        # Dual-timeframe: 20d (structural) + 5d (recent)
        # ═══════════════════════════════════════════════════════════════════════
        f4 = 0
        if spy_close is not None and len(spy_close) >= 21 and len(close) >= 21:
            rs20 = safe_float(close.iloc[-1] / (close.iloc[-21] + 1e-10) - 1) - \
                   safe_float(spy_close.iloc[-1] / (spy_close.iloc[-21] + 1e-10) - 1)
            rs5  = 0.0
            if len(spy_close) >= 6 and len(close) >= 6:
                rs5 = safe_float(close.iloc[-1] / (close.iloc[-6] + 1e-10) - 1) - \
                      safe_float(spy_close.iloc[-1] / (spy_close.iloc[-6] + 1e-10) - 1)

            if   rs20 >= 0.15:  f4 += 10
            elif rs20 >= 0.08:  f4 += 8
            elif rs20 >= 0.03:  f4 += 5
            elif rs20 >= 0.00:  f4 += 2
            elif rs20 < -0.05:  f4 -= 3   # material underperformance

            if   rs5 >= 0.05:  f4 += 4
            elif rs5 >= 0.02:  f4 += 2
            elif rs5 >= 0.00:  f4 += 1
        f4 = max(0, min(f4, 14))

        # ═══════════════════════════════════════════════════════════════════════
        # FACTOR 5 — TECHNICAL ENTRY ZONE (0–14)
        # Two high-probability setups for short/mid-term returns:
        #   A) BREAKOUT: new 52w high = trend continuation = highest probability
        #   B) VCP BASE: 5-13% below high = tight consolidation before next move
        # Both deserve top scores. Far-from-high = weak relative strength.
        # ═══════════════════════════════════════════════════════════════════════
        f5 = 0
        n_days   = min(len(close), 252)
        high_52w = safe_float(close.rolling(n_days).max().iloc[-1])
        dist_52w = (price / high_52w) if high_52w > 0 else 0.0

        if   dist_52w >= 0.99:               f5 += 14  # at/above 52w high = breakout
        elif 0.97 <= dist_52w < 0.99:        f5 += 12  # within 3% of high = near-breakout
        elif 0.93 <= dist_52w < 0.97:        f5 += 10  # tight base top / VCP launch zone
        elif 0.87 <= dist_52w < 0.93:        f5 += 8   # VCP consolidation
        elif 0.80 <= dist_52w < 0.87:        f5 += 4   # base building
        elif 0.70 <= dist_52w < 0.80:        f5 += 1   # recovering
        # < 0.70 = too far from high, no points

        # EMA21 support test: touched and held within last 3 bars
        ema21_s = close.ewm(span=21, adjust=False).mean()
        recent_low_3   = safe_float(low.iloc[-3:].min())
        ema21_recent_3 = safe_float(ema21_s.iloc[-3:].min())
        if ema21_recent_3 > 0 and abs(recent_low_3 - ema21_recent_3) / ema21_recent_3 < 0.02:
            f5 = min(f5 + 2, 14)   # institutional support level held
        f5 = min(f5, 14)

        # ═══════════════════════════════════════════════════════════════════════
        # FACTOR 6 — SMART VOLUME + CMF (0–8)
        # OBV trend + Chaikin Money Flow (20d) — the gold standard for
        # detecting institutional accumulation BEFORE the price moves.
        # CMF > 0.10 means 20d net money flow is positive = smart money buying.
        # ═══════════════════════════════════════════════════════════════════════
        f6 = 0
        if len(close) >= 11:
            obv = (vol * np.sign(close.diff().fillna(0))).cumsum()
            obv5  = safe_float(obv.iloc[-1] - obv.iloc[-6])  if len(obv) >= 6  else 0.0
            obv20 = safe_float(obv.iloc[-1] - obv.iloc[-21]) if len(obv) >= 21 else 0.0

            if   obv5 > 0 and obv20 > 0:  f6 += 2   # both OBV timeframes accumulating
            elif obv5 > 0:                f6 += 1

            # CMF — primary institutional flow indicator (replaces simple up/dn vol ratio)
            if   cmf_val >= 0.20:  f6 += 6   # very strong institutional buying
            elif cmf_val >= 0.10:  f6 += 4   # confirmed accumulation
            elif cmf_val >= 0.03:  f6 += 2   # mild net positive flow
            elif cmf_val <= -0.10: f6 -= 3   # institutions distributing
        f6 = max(0, min(f6, 8))

        # ═══════════════════════════════════════════════════════════════════════
        # FACTOR 7 — FUNDAMENTAL TIER (0–8)
        # Use dollar volume as market cap proxy (no API call needed).
        # avg_volume_usd = price × avg_daily_volume gives a reliable size signal.
        # ═══════════════════════════════════════════════════════════════════════
        f7 = 4   # neutral default
        # Check module-level market cap cache (populated by run_scan before scoring)
        _mcap = _MCAP_CACHE.get(ticker, 0)
        if _mcap > 0:
            if   _mcap >= 50_000_000_000:  f7 = 8
            elif _mcap >= 10_000_000_000:  f7 = 7
            elif _mcap >= 2_000_000_000:   f7 = 6
            elif _mcap >= 500_000_000:     f7 = 5
            elif _mcap >= 100_000_000:     f7 = 3
            else:                           f7 = 1
        else:
            # Rough proxy from dollar volume: avg_vol_usd * 252 trading days
            # Large-cap stocks trade $100M+/day; small-cap < $5M/day
            avg_vol_usd = price * avg_vol_20
            if   avg_vol_usd >= 500_000_000:  f7 = 8
            elif avg_vol_usd >= 100_000_000:  f7 = 7
            elif avg_vol_usd >= 30_000_000:   f7 = 6
            elif avg_vol_usd >= 10_000_000:   f7 = 5
            elif avg_vol_usd >=  5_000_000:   f7 = 4
            else:                              f7 = 3

        # ═══════════════════════════════════════════════════════════════════════
        # RAW TOTAL
        # ═══════════════════════════════════════════════════════════════════════
        raw = f1 + f2 + f3 + f4 + f5 + f6 + f7

        # ─── BONUSES ──────────────────────────────────────────────────────────
        # RSI SWEET SPOT (data-driven 2026-05): entry_rsi ρ=+0.35 with 7d returns.
        # Winners avg RSI=65.7, Losers avg RSI=57.0 → momentum zone 55-75 = optimal.
        _strong_trend = (plus_di > minus_di and adx_val >= 25)
        if   55 <= rsi_val <= 75:
            raw += 10   # momentum breakout zone — highest forward return probability
        elif 75 < rsi_val <= 82:
            raw += 5    # extended but still rising — valid breakout momentum
        elif 50 <= rsi_val < 55:
            raw += 2    # building momentum — acceptable entry zone
        elif rsi_val < 50:
            raw -= 4    # below momentum threshold — not ready to explode
        # RSI > 82 handled in hard caps below — parabolic extension

        # ADX bonus (data-driven 2026-05): entry_adx ρ=+0.285 with 7d returns.
        if plus_di > minus_di:
            if   adx_val >= 40:  raw += 8   # strong confirmed uptrend
            elif adx_val >= 30:  raw += 5   # solid trend
            elif adx_val >= 20:  raw += 3   # building trend

        # NR7: Today's range = tightest of last 7 days — volatility coiling for explosion
        # One of the most reliable short-term precursors of a breakout move
        if nr7:
            raw += 4   # range contraction = energy being stored

        # Weekly Stage 2: price above rising 30-week MA
        # Higher-timeframe confirmation that institutions are in control
        if weekly_stage2:
            raw += 5   # powerful multi-week accumulation confirmed

        # Bull Flag: 3-day low-volume pullback after prior 5-day run
        if len(close) >= 13:
            base_gain = safe_float(close.iloc[-8] / (close.iloc[-13] + 1e-10) - 1)
            flag_ret  = safe_float(close.iloc[-1] / (close.iloc[-4]  + 1e-10) - 1)
            flag_vol  = safe_float(vol.iloc[-3:].mean())
            base_vol  = safe_float(vol.iloc[-8:-3].mean())
            if (base_gain >= 0.04 and
                    -0.05 <= flag_ret <= 0.005 and
                    base_vol > 0 and flag_vol < base_vol * 0.75):
                raw += 5   # textbook bull flag = high-probability setup

        # ─── EXPLOSIVE SETUP BONUSES ──────────────────────────────────────────
        # These three signals, alone or combined, identify stocks that are about
        # to make 20-50%+ moves.  Each has a documented edge from top traders.

        # BASE CONSOLIDATION (data-driven 2026-05): base_weeks alone is NOT a strong
        # short-term predictor. Bonus only meaningful when RVOL confirms active breakout.
        # Stocks in long quiet bases produce big moves eventually — but not in 1-7 days
        # unless volume is expanding NOW. Require RVOL for higher bonuses.
        if   base_weeks >= 8  and base_depth <= 0.12 and rvol >= 1.0:  raw += 8   # active breakout from tight VCP
        elif base_weeks >= 8  and base_depth <= 0.12:                  raw += 3   # tight VCP but no volume yet
        elif base_weeks >= 5  and base_depth <= 0.18 and rvol >= 1.0:  raw += 6   # solid VCP breaking out
        elif base_weeks >= 5  and base_depth <= 0.18:                  raw += 2   # solid VCP, still coiling
        elif base_weeks >= 3  and base_depth <= 0.25 and rvol >= 1.0:  raw += 4   # short base, active
        elif base_weeks >= 3  and base_depth <= 0.25:                  raw += 1   # short base, waiting

        # Pocket Pivot: institutional accumulation footprint
        # DATA 2026-05: pocket_pivot ρ=+0.29 with 7d returns — INCREASE this weight.
        # Valid in base context AND outside base if volume confirms (ρ positive overall).
        if pocket_pivot:
            if base_weeks >= 3:
                # Inside or just exiting a proper consolidation — institutional accumulation
                if rvol >= 1.5:  raw += 12   # clean institutional breakout footprint
                elif rvol >= 1.0: raw += 7   # valid accumulation signal
                else:             raw += 3   # PP in base, quiet — still a positive signal
            else:
                # No formal base: pocket pivot = active institutional buying NOW
                if rvol >= 2.0:  raw += 6   # high conviction institutional entry
                elif rvol >= 1.5: raw += 3  # valid but shorter-term signal
                else:             raw += 0  # no volume confirmation

        # RS Line at New High: only meaningful BEFORE a base breakout
        # Without a base, RS leading is just "stock already ran hard" — not predictive
        if rs_new_high:
            if base_weeks >= 3:
                raw += 6   # RS leading + base = pre-breakout institutional positioning
            else:
                raw += 2   # RS good but extended — not a setup, just momentum

        # Confluence bonus: all 3 signals = highest-conviction explosive setup
        if pocket_pivot and rs_new_high and base_weeks >= 4:
            raw += 6   # all signals aligned — rare, extremely high probability

        # Dark Pool Accumulation: meaningful only within a base context
        if dark_pool:
            if base_weeks >= 3:
                raw += 6   # quiet accumulation during consolidation — very bullish
            else:
                raw += 2   # DP on extended stock = institutions adding, but late-stage

        # COILING SETUP (data-driven 2026-05): entry_squeeze ρ=-0.22 with 7d returns.
        # Pure coiling/squeeze WITHOUT volume = stock still waiting = no short-term edge.
        # Coiling WITH volume = breakout happening NOW = very high conviction signal.
        # The distinction: is the spring RELEASING (RVOL) or still COMPRESSING (dry)?
        if coiling_setup and rvol >= 1.5:
            raw += 14   # squeeze RELEASING with volume = imminent explosive move
            if base_weeks >= 8:
                raw += 4   # long base compression releasing = maximum conviction
        elif coiling_setup and rvol >= 1.0:
            raw += 8    # coil breaking with adequate volume
        elif coiling_setup and rvol >= 0.6:
            raw += 3    # mild interest during coil — not yet confirmed
        elif coiling_setup:
            raw += 0    # pure dry coil, no volume = not breaking out, no bonus
        elif near_pivot_20d and rvol >= 1.2:
            raw += 5    # at pivot with active volume — potential breakout
        elif near_pivot_20d and base_weeks >= 3:
            raw += 3    # near pivot with base, normal volume
        
        # ─── ATR QUALITY BONUS ────────────────────────────────────────────────
        # ATR 2-4% = "Goldilocks zone" for growth stocks — enough volatility to make
        # 30%+ moves, but not so wild that stops get blown out on noise.
        # Utilities (ATR < 0.8%) can't move. Penny stocks (ATR > 6%) are too erratic.
        if 0.02 <= atr_pct_20 <= 0.04:
            raw += 5   # healthy volatility for explosive growth moves
        elif 0.015 <= atr_pct_20 < 0.02:
            raw += 2   # acceptable but lower momentum potential
        elif atr_pct_20 > 0.06:
            raw -= 3   # too volatile — stop placement unreliable

        # ─── PENALTIES ────────────────────────────────────────────────────────
        # RVOL < 1.0: no institutional demand today — explicit penalty
        # EXCEPT for coiling setups where low RVOL IS the correct pre-breakout signal.
        if rvol < 1.0 and not coiling_setup:
            raw -= 10   # no demand = no edge (but NOT if stock is coiling — that IS the signal)
        elif rvol < 1.0 and coiling_setup:
            raw -= 2    # minimal friction — low RVOL on a coiling setup is correct
        elif rvol < 1.2:
            raw -= 4    # mild demand — still below average

        # ── DYNAMIC OPTIMIZER PENALTIES ──────────────────────────────────────
        # Rules learned from real trade outcomes, updated automatically.
        # Each cycle: vinerox_optimizer.py re-derives these from actual P&L data.
        _opt = _OPTIMIZER_RULES
        if _opt:
            _opt_rvol_thresh = float(_opt.get('rvol_penalty_threshold', 1.0))
            _opt_rvol_amt    = int(_opt.get('rvol_penalty_amount', 10))
            _opt_rvol_soft   = float(_opt.get('rvol_soft_threshold', 1.2))
            _opt_rvol_soft_p = int(_opt.get('rvol_soft_penalty', 4))
            if rvol < _opt_rvol_thresh and not coiling_setup:
                raw -= max(0, _opt_rvol_amt - 10)   # incremental on top of static
            elif rvol < _opt_rvol_soft and not coiling_setup:
                raw -= max(0, _opt_rvol_soft_p - 4)

            _opt_adx_thresh = float(_opt.get('adx_penalty_threshold', 20))
            _opt_adx_amt    = int(_opt.get('adx_penalty_amount', 5))
            if adx_val < _opt_adx_thresh and plus_di <= minus_di:
                raw -= _opt_adx_amt

            _opt_cmf_thresh = float(_opt.get('cmf_penalty_threshold', -0.10))
            _opt_cmf_amt    = int(_opt.get('cmf_penalty_amount', 3))
            if cmf_val < _opt_cmf_thresh:
                raw -= max(0, _opt_cmf_amt - 3)

            # ── MOVER PROFILE BONUS ──────────────────────────────────────────
            # vinerox_movers_scanner.py stores pre-explosion indicator medians.
            # If current stock's indicators match the profile that preceded +15%
            # moves in the past, award a scoring bonus (+5 to +12 pts).
            _mp = _opt.get('mover_profile')
            if _mp:
                _mp_rvol  = float(_mp.get('mover_rvol_p50',  0))
                _mp_rsi   = float(_mp.get('mover_rsi_p50',   0))
                _mp_adx   = float(_mp.get('mover_adx_p50',   0))
                _mp_sq_rt = float(_mp.get('mover_squeeze_rate', 0))
                _match = 0
                if _mp_rvol > 0 and 0.5 * _mp_rvol <= rvol <= 2.5 * _mp_rvol:
                    _match += 1
                if _mp_rsi > 0 and abs(rsi_val - _mp_rsi) <= 15:
                    _match += 1
                if _mp_adx > 0 and abs(adx_val - _mp_adx) <= 12:
                    _match += 1
                if _mp_sq_rt >= 0.5 and squeeze:
                    _match += 1
                if   _match >= 3:  raw += 12
                elif _match == 2:  raw += 7
                elif _match == 1:  raw += 3
            # ── END MOVER PROFILE BONUS ──────────────────────────────────────
            # ── LEARNED FACTOR BONUSES (LEARNED_BONUS_BLOCK) ─────────────────
            # Derived from REAL signal_outcomes by the learning daemon
            # (apply_learned_weights -> optimizer_state). Applies the "what works"
            # side of learning, complementing the penalty ("what fails") side.
            try:
                if rsi_val is not None:
                    if 65 <= rsi_val <= 75:
                        raw += int(_opt.get('rsi_hot_bonus', 0) or 0)
                    elif rsi_val > 75:
                        raw += int(_opt.get('rsi_momentum_bonus', 0) or 0)
                if plus_di > minus_di and adx_val >= 50:
                    raw += int(_opt.get('adx_ultra_bonus', 0) or 0)
                if squeeze_on:
                    raw -= int(_opt.get('squeeze_pen_extra', 0) or 0)
                if rvol < 0.5:
                    raw -= int(_opt.get('low_rvol_pen_extra', 0) or 0)
            except Exception:
                pass
            # ── END LEARNED FACTOR BONUSES ──────────────────────────────────

        # ─────────────────────────────────────────────────────────────────────

        # Distribution: ≥2 high-volume down days in last 5
        if len(close) >= 6:
            c5 = close.iloc[-5:].values
            p5 = close.iloc[-6:-1].values
            v5 = vol.iloc[-5:].values
            dist_days = int(np.sum((c5 < p5) & (v5 > avg_vol_20 * 1.3)))
            if   dist_days >= 2:  raw -= 5
            elif dist_days == 1:  raw -= 2

        # ─── NO BASE PENALTY (data-driven 2026-05) ──────────────────────────────
        # DISTINGUISH between: (A) early breakout with volume = VALID entry
        #                       (B) random noise without volume = SKIP
        # High RVOL without base = stock currently breaking out (early stage) = valid.
        # Low RVOL without base = no setup + no institutional interest = skip.
        # DATA: Winners avg RVOL=1.36 — many winners were breaking out without long base.
        if base_weeks < 3:
            if rvol >= 2.0:
                raw -= 5    # REDUCED: high volume breakout without formal base = early move
            elif rvol >= 1.0:
                raw -= 12   # moderate: some interest but no setup → uncertain
            else:
                raw -= 18   # no base + no volume = random noise, ignore
            if rsi_val > 82 and rvol < 1.5:
                raw -= 8    # extended RSI + low volume + no base = peak chasing
        # ─────────────────────────────────────────────────────────────────────

        # Pump-chaser penalty: high RSI + high RVOL with NO institutional setup signal
        # This identifies stocks that already had their move — buying here = chasing
        # Exempted when Pocket Pivot / RS New High / base are present (those ARE predictive)
        # *** STRENGTHENED: This is key to avoid buying after the move happened ***
        if rsi_val > 75 and rvol > 3.0 and not pocket_pivot and not rs_new_high and base_weeks < 3:
            raw -= 12   # INCREASED from 8 — likely momentum-only, NOT predictive
        # Additional: penalize extended RSI even WITH a base if RVOL is extreme
        if rsi_val > 88 and rvol > 5.0:
            raw -= 10   # parabolic move — even with setup, this is late entry

        # ─── EARNINGS PROXIMITY CHECK + PENALTY ──────────────────────────────
        # In batch mode: use pre-populated _EARNINGS_CACHE (no API call).
        # In standalone mode: skip (earnings check too expensive per-ticker).
        if ticker in _EARNINGS_CACHE:
            earnings_days_away = _EARNINGS_CACHE[ticker]
            if earnings_days_away is not None and abs(earnings_days_away) <= 3:
                return None   # hard block: imminent earnings

        if earnings_days_away is not None:
            _eabs = abs(earnings_days_away)
            if 4 <= _eabs <= 7:
                raw -= 12   # imminent — cannot stop a gap-down
            elif 8 <= _eabs <= 14:
                raw -= 6    # approaching — reduce conviction

        # ─── GAP-PRONE STOCK PENALTY ─────────────────────────────────────────
        # Only penalise DOWN gaps — up-gaps are the moves we want to catch.
        #   2× down-gaps > 5%    → -8  pts  (pattern established, stop unreliable)
        #   max_gap_dn ≤ -10%    → -5  pts  (single severe down-gap)
        if gaps_gt5_dn == 2:
            raw -= 8    # two historical gap-downs > 5% — risk pattern established
        if max_gap_dn <= -10.0:
            raw -= 5    # at least one severe gap-down — stop cannot protect
        # ─────────────────────────────────────────────────────────────────────
        
        # ═══════════════════════════════════════════════════════════════════════
        # FACTOR 8 — SMART MONEY INSTITUTIONAL SIGNALS (0-15 bonus)
        # ═══════════════════════════════════════════════════════════════════════
        # These signals identify stocks BEFORE they move — institutions positioning
        # ahead of retail. Only checks candidates with score ≥ 65 (expensive API calls).
        # Dark Pool (fast, no API): always checked
        # UOA/Insider/PEAD/Squeeze: checked if base score warrants it
        #
        # Strategy: compute base score first, THEN add Smart Money bonus for top picks.
        # This way we scan 1700 tickers fast, then deep-dive only promising ones.
        # ═══════════════════════════════════════════════════════════════════════
        
        # For now: placeholder for Smart Money integration
        # Will be computed AFTER base score, then added as bonus (see store_candidates)
        smart_money_bonus = 0   # 0-15 pts added post-scan for qualified candidates

        final_score = safe_int(raw + smart_money_bonus, 1, 100)

        # ─── DERIVED SCORES ───────────────────────────────────────────────────
        prox_score      = safe_int(f3 * 3.5 + f5 * 3.0 + f4 * 2.0, 1, 100)
        # explosion_score v3: base_weeks added — punishes pure news spikes (no base = no institutional setup)
        # base_bonus: 0 (no base) → +6 (4w) → +12 (8w tight) — mirrors SPCE/NEXR/EDHL pattern
        _base_bonus = 0
        if   base_weeks >= 8 and base_depth <= 0.12:  _base_bonus = 12
        elif base_weeks >= 5 and base_depth <= 0.18:  _base_bonus = 8
        elif base_weeks >= 3 and base_depth <= 0.25:  _base_bonus = 5
        elif base_weeks >= 1:                         _base_bonus = 2
        explosion_score = safe_int(f1 * 3.0 + f2 * 2.0 + f6 * 2.0 + _base_bonus, 1, 100)

        # ── WINNER-DNA OVERLAY (learning system -> live ranking) ─────────────
        # Backtested on 451 real outcomes: top-50 win 16%->54%, avg7d -1.1%->+1.8%.
        # Blends the proven explosive-DNA score (rvol/adx/rsi zone, squeeze pen.)
        # into explosion_score so the bell ranks the REAL winners first.
        # Instant revert: export VINEROX_DNA_OVERLAY=0 and restart.
        try:
            from vinerox_winner_dna import winner_dna_score as _wdna, blend_score as _wbl
            _dna_es = _wdna(rsi_val, adx_val, rvol, squeeze_on)
            explosion_score = _wbl(explosion_score, _dna_es, 0.65)
        except Exception:
            pass

        if   f2 >= 16:  trend_label = 'STRONG'
        elif f2 >= 11:  trend_label = 'BUILDING'
        elif f2 >= 6:   trend_label = 'NEUTRAL'
        else:           trend_label = 'WEAK'

        # TIER MAPPING (v2 — explosion_score driven, May 2026):
        # Audit showed final_score is ANTI-CORRELATED with 5-10d returns (high score = lower return).
        # explosion_score = f1(momentum)*3 + f2(trend)*2 + f6(smart_vol)*2 — empirically calibrated
        # for short-term explosive moves. final_score still stored for reference.
        # Thresholds tuned so BESTSTOCK ≈ top 2%, GOLD ≈ top 10%, SILVER ≈ top 25%.
        if   explosion_score >= 75:  quality_flag = 'BESTSTOCK'
        elif explosion_score >= 58:  quality_flag = 'GOLD'
        elif explosion_score >= 42:  quality_flag = 'SILVER'
        elif explosion_score >= 28:  quality_flag = 'WATCH'
        else:                        quality_flag = 'WATCH'

        # ── HARD CAP: Completely no base = cannot be GOLD or above ────────────
        # Allow 1-2 week short bases — fresh breakouts from tight consolidation move fastest.
        if base_weeks < 1 and quality_flag in ('BESTSTOCK', 'GOLD'):
            quality_flag = 'SILVER'  # zero consolidation history = SILVER
        # ── BESTSTOCK = חייב Pocket Pivot OR base >= 4w (נתון מ-SPCE/NEXR/EDHL/BJDX/LODE) ───
        # pure RVOL spike (חדשות ביוטק, FDA, פאמפ קטן) → GOLD לכל היותר.
        # 20/21 BESTSTOCK_BULK failures היו spikes ללא base. זה השינוי הקריטי.
        _has_structural_setup = bool(pocket_pivot or rs_new_high or base_weeks >= 4)
        if quality_flag == 'BESTSTOCK' and not _has_structural_setup:
            quality_flag = 'GOLD'    # ספייק ללא מבנה = GOLD, לא BESTSTOCK
        # ── ADR / FOREIGN BANK HARD CAP ──────────────────────────────────────
        # SHG/KB/WF = ADR בנקים זרים: לא מתפוצצים כמו US growth stocks.
        # BESTSTOCK = לא אפשרי. GOLD = לא אפשרי. מקסימום SILVER.
        if _adr_suspect and quality_flag in ('BESTSTOCK', 'GOLD'):
            quality_flag = 'SILVER'  # ADR זר = SILVER מקסימום
        # ── RSI HARD CAP: RSI > 82 = overbought in all timeframes ────────────
        # RSI 71-82 = breakout momentum zone — allowed (this is where big moves start).
        if rsi_val > 82:
            quality_flag = 'WATCH'   # over-extended — no conviction entry above 82
        # ── VOLUME HARD CAP: BESTSTOCK requires real institutional flow ───────
        # Require RVOL ≥ 2.5 for BESTSTOCK (institutional buying, not retail noise).
        # Coiling setups (intentional volume dry-up) exempt with 3+ week base.
        if quality_flag == 'BESTSTOCK' and rvol < 2.5 and not (coiling_setup and base_weeks >= 3):
            quality_flag = 'GOLD'    # not enough volume for institutional breakout
        # ── GOLD RVOL GATE: institutional flow required for conviction buys ──
        # GOLD = active buy list. Without RVOL ≥ 1.2 there is no evidence of
        # institutional participation → downgrade to SILVER (watchlist mode).
        # TWO exemptions:
        #   (A) Coiling setups: intentional volume dry-up is THE pre-breakout signal.
        #   (B) Long base (≥ 8 weeks): patient institutional accumulation — O'Neil CANSLIM.
        #       A 8+ week base with dry volume IS the highest-probability setup,
        #       regardless of today's RVOL reading.
        long_base_dry = base_weeks >= 8 and volume_dry_up
        # GOLD RVOL GATE (data-driven 2026-05): Remove coiling exemption.
        # Coiling without RVOL = stock still waiting = not GOLD tier material.
        # Only exception: genuine long-base dry-up (8+ weeks, institutional patience).
        if quality_flag == 'GOLD' and rvol < 1.2 and not long_base_dry:
            quality_flag = 'SILVER'  # no volume confirmation → watchlist only
        # ─────────────────────────────────────────────────────────────────────

        # ── LIVE RECOMMENDATION (recalculated every scan cycle) ─────────────
        # Points-based: coiled-spring setup + volume + trend + RSI + tier + CMF
        _rec_pts = 0

        # ── COILED SPRING BONUS (data-driven 2026-05) ──────────────────────────
        # Only award when RVOL confirms the spring is RELEASING, not still compressing.
        # Dry coiling (no RVOL) = waiting mode = no STRONG_BUY recommendation.
        _is_coiled_spring = coiling_setup and base_weeks >= 6
        if _is_coiled_spring and rvol >= 1.2 and squeeze_on:
            _rec_pts += 5   # squeeze RELEASING with volume = maximum conviction
        elif _is_coiled_spring and rvol >= 1.2:
            _rec_pts += 3   # VCP breakout with volume confirmation
        elif _is_coiled_spring and squeeze_on:
            _rec_pts += 1   # squeeze without volume = still waiting, not actionable
        # pure coiling without RVOL: 0 bonus
        if pocket_pivot:
            _rec_pts += 3   # institutional breakout day within base = strong buy signal
        if explosion_score >= 85:
            _rec_pts += 2   # very high setup quality
        elif explosion_score >= 75:
            _rec_pts += 1

        # ── VOLUME: differentiate coiling vs breakout stocks ─────────────────
        if _is_coiled_spring:
            # Coiling stocks SHOULD have low RVOL — don't penalise, give small bonus
            if   rvol >= 2.0:  _rec_pts += 3   # breakout volume triggered!
            elif rvol >= 1.2:  _rec_pts += 2   # volume starting to expand
            elif rvol >= 0.5:  _rec_pts += 1   # normal coiling volume = good
            # rvol < 0.5 = extreme dryup = squeeze nearing max, still OK
        else:
            # Non-coiling: standard volume scoring
            if   rvol >= 2.5:  _rec_pts += 4
            elif rvol >= 1.8:  _rec_pts += 3
            elif rvol >= 1.3:  _rec_pts += 2
            elif rvol >= 1.0:  _rec_pts += 1
            elif rvol < 0.6:   _rec_pts -= 3
            elif rvol < 0.85:  _rec_pts -= 1

        # ── ADX / trend direction ─────────────────────────────────────────────
        if   adx_val >= 40 and plus_di > minus_di: _rec_pts += 3
        elif adx_val >= 28 and plus_di > minus_di: _rec_pts += 2
        elif adx_val >= 20 and plus_di > minus_di: _rec_pts += 1
        elif adx_val < 15:                         _rec_pts -= 2
        elif plus_di <= minus_di:                  _rec_pts -= 1

        # ── RSI position (data-driven 2026-05) ──────────────────────────────────
        # Winners avg RSI=65.7. Optimal entry zone = 55-75 for both setups.
        if _is_coiled_spring:
            if   55 <= rsi_val <= 75:  _rec_pts += 2   # ideal momentum zone
            elif 45 <= rsi_val <  55:  _rec_pts += 1   # acceptable, building
            elif rsi_val > 80:         _rec_pts -= 2   # overbought even for setup
            elif rsi_val < 35:         _rec_pts -= 2   # oversold = base failing
        else:
            if   55 <= rsi_val <= 75:  _rec_pts += 2   # momentum breakout zone
            elif 45 <= rsi_val <  55:  _rec_pts += 1   # building
            elif 75 <  rsi_val <= 82:  _rec_pts += 1   # extended but still valid
            elif rsi_val > 82:         _rec_pts -= 3   # parabolic
            elif rsi_val < 40:         _rec_pts -= 2

        # ── Tier bonus ────────────────────────────────────────────────────────
        if   quality_flag == 'BESTSTOCK': _rec_pts += 2
        elif quality_flag == 'GOLD':      _rec_pts += 1
        elif quality_flag == 'WATCH':     _rec_pts -= 1

        # ── CMF institutional flow ────────────────────────────────────────────
        if   cmf_val >= 0.15:  _rec_pts += 2
        elif cmf_val >= 0.05:  _rec_pts += 1
        elif cmf_val <= -0.10: _rec_pts -= 2
        elif cmf_val < -0.03:  _rec_pts -= 1

        # ── Map to recommendation label ───────────────────────────────────────
        if   _rec_pts >= 9:   recommendation = 'STRONG_BUY'
        elif _rec_pts >= 6:   recommendation = 'BUY'
        elif _rec_pts >= 3:   recommendation = 'HOLD'
        elif _rec_pts >= 0:   recommendation = 'SELL'
        else:                 recommendation = 'STRONG_SELL'
        # ─────────────────────────────────────────────────────────────────────

        # ── FINAL TIER GUARD (May 2026): align quality_flag with recommendation
        # BESTSTOCK / GOLD = "invest now" tiers. A SELL/STRONG_SELL recommendation
        # MUST NOT appear in those tiers (user intent: BESTSTOCK = active buy list).
        # Pre-breakout coiling stocks with weak momentum belong in WATCH, not BEST.
        if recommendation in ('SELL', 'STRONG_SELL') and quality_flag in ('BESTSTOCK', 'GOLD'):
            quality_flag = 'WATCH'
        # BESTSTOCK is the highest conviction tier — require BUY+ recommendation.
        # A merely HOLD setup, even at score 95, is downgraded to GOLD.
        elif recommendation == 'HOLD' and quality_flag == 'BESTSTOCK':
            quality_flag = 'GOLD'

        # ── BESTSTOCK FINAL GATE v3 ──────────────────────────────────────────
        # BESTSTOCK = הגדרה מחדש: רק מניות עם מבנה מוסדי מוכח לפני הזינוק.
        # 1) rec חייב להיות BUY+
        # 2) חייב לפחות אחד: PP, RS New High, base>=4w, coiling+base>=3w
        # בלי כל אחד מאלה = GOLD בלבד, לא BESTSTOCK.
        if quality_flag == 'BESTSTOCK':
            if recommendation not in ('BUY', 'STRONG_BUY'):
                quality_flag = 'GOLD'                       # rec engine doesn't concur
            elif not _has_structural_setup:
                quality_flag = 'GOLD'                       # ספייק ללא מבנה = GOLD
        # ─────────────────────────────────────────────────────────────────────

        # Build human-readable setup description for Telegram
        _tags = []
        if coiling_setup:             _tags.append(f'SPRING{base_weeks}W')
        elif near_pivot_20d and volume_dry_up: _tags.append('COIL')
        if pocket_pivot:          _tags.append('POCKET_PIVOT')
        if rs_new_high:           _tags.append('RS_LEADER')
        if base_weeks >= 6:       _tags.append(f'VCP_{base_weeks}W')
        elif base_weeks >= 3:     _tags.append(f'BASE_{base_weeks}W')
        if weekly_stage2:         _tags.append('STAGE2')
        if nr7:                   _tags.append('NR7')
        if squeeze_on:            _tags.append('SQUEEZE')
        setup_type = '+'.join(_tags) if _tags else 'STANDARD'

        # Expected move estimate (Minervini: breakout = ~3-4x base depth)
        if base_depth < 1.0 and base_weeks >= 4:
            expected_move_pct = round(min(base_depth * 3.5 * 100, 60.0), 1)
        else:
            expected_move_pct = 14.0  # default T1 target

        # ── PRE-EXPLOSION DNA (learned pre-jump fingerprint) ─────────────────
        # Score the CURRENT (pre-move) state against the OOS-validated model that
        # learned the common denominator of stocks that went on to jump 30%+.
        # Computed from the bars we already hold → zero extra Yahoo calls.
        _pe_prob, _pe_dna = None, None
        try:
            import vinerox_pe_score as _pes
            _pe_prob, _pe_dna = _pes.score_hist_lower(hist)
        except Exception as _pe_err:
            log.debug(f"[{ticker}] pre-explosion score skipped: {_pe_err}")

        return {
            'ticker':              ticker,
            'score':               final_score,
            'explosion_score':     explosion_score,
            'prox_score':          prox_score,
            'price':               round(price, 2),
            'buy_price':           round(price * 1.003, 2),
            'rvol':                round(rvol, 2),
            'volume':              int(cur_vol),
            'avg_volume':          int(avg_vol_20),
            'rsi':                 round(rsi_val, 1),
            'adx':                 round(adx_val, 1),
            'squeeze':             1 if squeeze_on else 0,
            'trend_status':        trend_label,
            'quality_flag':        quality_flag,
            'recommendation':      recommendation,
            'base_weeks':          base_weeks,
            'pocket_pivot':        1 if pocket_pivot else 0,
            'rs_new_high':         1 if rs_new_high else 0,
            'setup_type':          setup_type,
            'cmf':                 round(cmf_val, 3),
            'nr7':                 1 if nr7 else 0,
            'weekly_stage2':       1 if weekly_stage2 else 0,
            'expected_move_pct':   expected_move_pct,
            'dark_pool':           1 if dark_pool else 0,
            'atr_pct':             round(atr_pct_20, 4),   # daily ATR as % of price (for position sizing)
            # Pre-breakout coiling signals
            'near_pivot_20d':      1 if near_pivot_20d else 0,
            'volume_dry_up':       1 if volume_dry_up else 0,
            'coiling_setup':       1 if coiling_setup else 0,
            'rvol_5d_avg':         round(rvol_5d_avg, 2),
            # Risk safeguards
            'earnings_days_away':  earnings_days_away,
            'gaps_gt5':            gaps_gt5,
            'gap_max_down':        round(max_gap_dn, 2),
            'pre_explosion_dna':   _pe_dna,
            'pre_explosion_prob':  _pe_prob,
            '_f1': f1, '_f2': f2, '_f3': f3, '_f4': f4,
            '_f5': f5, '_f6': f6, '_f7': f7,
        }

    except Exception as e:
        log.debug(f"[{ticker}] score error: {e}")
        return None



# ── DB WRITE ──────────────────────────────────────────────────────────────────
def store_candidates(candidates: list):
    if not candidates:
        return
    # ── DEFENSE-IN-DEPTH (May 2026): drop any non-equity that leaked through.
    # Even if a stale daemon process is running pre-filter code, no ETF / REIT /
    # fund / SPAC / warrant can ever land in explosion_candidates. ──
    try:
        from vinerox_instrument_filter import is_explosive_candidate
        before = len(candidates)
        candidates = [c for c in candidates if is_explosive_candidate(c['ticker'])]
        dropped = before - len(candidates)
        if dropped:
            log.info(f"[purity guard] dropped {dropped} non-equity rows pre-store")
    except Exception as _ex:
        log.warning(f"[purity guard] filter unavailable: {_ex}")
    if not candidates:
        return
    conn = sqlite3.connect(DB_PATH, timeout=30)
    now  = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    # Ensure the pre-explosion columns exist (idempotent).
    for _col, _typ in (('pre_explosion_dna', 'REAL'),
                       ('pre_explosion_prob', 'REAL'),
                       ('pre_explosion_at', 'TEXT')):
        try:
            conn.execute(f"ALTER TABLE explosion_candidates ADD COLUMN {_col} {_typ}")
        except Exception:
            pass
    ok   = 0
    for c in candidates:
        try:
            conn.execute("""
                INSERT INTO explosion_candidates
                    (ticker, score, explosion_score, prox_score, price, buy_price, rvol,
                     volume, avg_volume, rsi, adx, squeeze, trend_status,
                     quality_flag, recommendation, base_weeks, pocket_pivot, rs_new_high, setup_type,
                     cmf, nr7, weekly_stage2, expected_move_pct, dark_pool,
                     atr_pct,
                     earnings_days_away, gaps_gt5, gap_max_down,
                     telegram_status, last_updated)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,'PENDING',?)
                ON CONFLICT(ticker) DO UPDATE SET
                    score=excluded.score,
                    explosion_score=excluded.explosion_score,
                    prox_score=excluded.prox_score,
                    price=excluded.price,
                    buy_price=excluded.buy_price,
                    rvol=excluded.rvol,
                    volume=excluded.volume,
                    avg_volume=excluded.avg_volume,
                    rsi=excluded.rsi,
                    adx=excluded.adx,
                    squeeze=excluded.squeeze,
                    trend_status=excluded.trend_status,
                    quality_flag=excluded.quality_flag,
                    recommendation=excluded.recommendation,
                    base_weeks=excluded.base_weeks,
                    pocket_pivot=excluded.pocket_pivot,
                    rs_new_high=excluded.rs_new_high,
                    setup_type=excluded.setup_type,
                    cmf=excluded.cmf,
                    nr7=excluded.nr7,
                    weekly_stage2=excluded.weekly_stage2,
                    expected_move_pct=excluded.expected_move_pct,
                    dark_pool=excluded.dark_pool,
                    atr_pct=excluded.atr_pct,
                    earnings_days_away=excluded.earnings_days_away,
                    gaps_gt5=excluded.gaps_gt5,
                    gap_max_down=excluded.gap_max_down,
                    last_updated=excluded.last_updated
            """, (
                c['ticker'], c['score'], c['explosion_score'], c['prox_score'],
                c['price'], c['buy_price'], c['rvol'], c['volume'], c['avg_volume'],
                c['rsi'], c['adx'], c['squeeze'], c['trend_status'],
                c['quality_flag'], c.get('recommendation', 'HOLD'),
                c.get('base_weeks', 0), c.get('pocket_pivot', 0),
                c.get('rs_new_high', 0), c.get('setup_type', 'STANDARD'),
                c.get('cmf', 0.0), c.get('nr7', 0),
                c.get('weekly_stage2', 0), c.get('expected_move_pct', 14.0),
                c.get('dark_pool', 0),
                c.get('atr_pct', 0.0),
                c.get('earnings_days_away'), c.get('gaps_gt5', 0), c.get('gap_max_down', 0.0),
                now
            ))
            ok += 1
        except Exception as e:
            log.warning(f"DB upsert failed [{c['ticker']}]: {e}")
    # Write the learned pre-explosion DNA without touching the main upsert string.
    for c in candidates:
        _dna = c.get('pre_explosion_dna')
        if _dna is None:
            continue
        try:
            conn.execute(
                "UPDATE explosion_candidates "
                "SET pre_explosion_dna=?, pre_explosion_prob=?, pre_explosion_at=? "
                "WHERE ticker=?",
                (_dna, c.get('pre_explosion_prob'), now, c['ticker']))
        except Exception as e:
            log.debug(f"pre-explosion write failed [{c['ticker']}]: {e}")
    conn.commit()
    conn.close()
    log.info(f"Stored/updated {ok} candidates in DB")

    # ── Auto-add GOLD picks (score ≥ 80) to watchlist at discovery price ──
    gold = [c for c in candidates if c['score'] >= TELEGRAM_ALERT_THRESHOLD]
    if gold:
        _add_to_watchlist(gold)


def _add_to_watchlist(candidates: list):
    """Insert GOLD candidates into watchlist (once per ticker, not duplicated per day)."""
    conn = sqlite3.connect(DB_PATH, timeout=30)
    today = datetime.now().strftime('%Y-%m-%d')
    added = 0
    for c in candidates:
        try:
            existing = conn.execute(
                "SELECT id FROM watchlist WHERE ticker=? AND status='ACTIVE'",
                (c['ticker'],)
            ).fetchone()
            if existing:
                continue  # already actively tracked
            conn.execute("""
                INSERT INTO watchlist (ticker, entry_price, entry_score, entry_date,
                                       current_price, pnl_pct, pnl_abs, last_price_update, status)
                VALUES (?, ?, ?, ?, ?, 0.0, 0.0, ?, 'ACTIVE')
            """, (
                c['ticker'],
                c['price'],
                c['score'],
                datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                c['price'],
                datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            ))
            added += 1
            log.info(f"[WATCHLIST] Added {c['ticker']} @ ${c['price']:.2f} (score={c['score']})")
        except Exception as e:
            log.warning(f"[WATCHLIST] Failed to add {c['ticker']}: {e}")
    conn.commit()
    conn.close()
    if added:
        log.info(f"[WATCHLIST] {added} new GOLD picks added to watchlist")


# ── TELEGRAM ALERTS ───────────────────────────────────────────────────────────
def send_telegram_alerts(candidates: list) -> int:
    """
    Send Telegram alerts for top GOLD+ candidates only.
    Filters: GOLD / BESTSTOCK quality flag + score >= TELEGRAM_ALERT_THRESHOLD.
    Each alert includes:  buy price · T1/T2 targets · ATR-based dynamic stop-loss · R/R ratio.
    Sorted by potential score = scan_score × expected_move_pct (highest return potential first).
    """
    # ── 1. Filter ──────────────────────────────────────────────────────────────
    GOLD_FLAGS = {'GOLD', 'BESTSTOCK'}
    pool = [
        c for c in candidates
        if c['score'] >= TELEGRAM_ALERT_THRESHOLD
        and (not TELEGRAM_GOLD_ONLY or c.get('quality_flag', '') in GOLD_FLAGS)
    ]
    if not pool:
        log.info("No GOLD+ candidates above Telegram threshold this cycle.")
        return 0

    # ── 2. Sort by potential (score × expected_move_pct) ──────────────────────
    for c in pool:
        c['_potential'] = c['score'] * c.get('expected_move_pct', 14.0)
    top = sorted(pool, key=lambda x: -x['_potential'])[:MAX_TELEGRAM_ALERTS]

    # ── 3. Build per-stock messages ───────────────────────────────────────────
    now_str = datetime.now().strftime('%Y-%m-%d %H:%M')
    parts = [
        f"🏆 VINEROX GOLD PICKS — {now_str}\n"
        f"{'━' * 32}\n"
        f"Top {len(top)} מניות עם פוטנציאל תשואה גבוה ביותר\n"
        f"(GOLD / BESTSTOCK בלבד)\n"
    ]

    for c in top:
        ticker   = c['ticker']
        score    = c['score']
        qflag    = c.get('quality_flag', 'GOLD')
        price    = c.get('price', 0.0)
        buy_px   = c.get('buy_price', round(price * 1.003, 2))
        exp_mv   = c.get('expected_move_pct', 14.0)
        atr_frac = c.get('atr_pct', 0.02)          # daily ATR as fraction of price

        # ── Dynamic stop-loss: 1.5× daily ATR, capped 5%–10% ──────────────
        stop_dist = max(0.05, min(0.10, atr_frac * 1.5))
        stop_px   = round(buy_px * (1.0 - stop_dist), 2)
        stop_pct  = round(stop_dist * 100, 1)

        # ── Targets ────────────────────────────────────────────────────────
        t1_px     = round(buy_px * (1.0 + exp_mv / 100.0), 2)
        t2_px     = round(buy_px * (1.0 + exp_mv * 1.75 / 100.0), 2)
        t1_pct    = round(exp_mv, 1)
        t2_pct    = round(exp_mv * 1.75, 1)

        # ── Risk/Reward ────────────────────────────────────────────────────
        gain  = t1_px - buy_px
        risk  = buy_px - stop_px
        rr    = round(gain / risk, 1) if risk > 0 else 0.0

        # ── Emoji + setup badges ───────────────────────────────────────────
        if qflag == 'BESTSTOCK':         emoji = '💥'
        else:                            emoji = '⚡'

        badges = []
        if c.get('pocket_pivot'):  badges.append('🎯POCKET_PIVOT')
        if c.get('rs_new_high'):   badges.append('📊RS_LEADER')
        bw = c.get('base_weeks', 0)
        if bw >= 6:                badges.append(f'🏗VCP_{bw}W')
        elif bw >= 3:              badges.append(f'🏗BASE_{bw}W')
        if c.get('weekly_stage2'): badges.append('📈STAGE2')
        if c.get('nr7'):           badges.append('🔩NR7')
        if c.get('squeeze'):       badges.append('🌀SQUEEZE')
        if c.get('dark_pool'):     badges.append('🏦DARK$')
        badge_str = ' '.join(badges) if badges else c.get('setup_type', 'STANDARD')

        cmf_v   = c.get('cmf', 0.0)
        cmf_txt = f' | CMF:{cmf_v:+.2f}' if cmf_v != 0.0 else ''
        rvol    = c.get('rvol', 1.0)
        rsi     = c.get('rsi', 50.0)
        adx     = c.get('adx', 20.0)
        trend   = c.get('trend_status', '')

        block = (
            f"\n{emoji} {ticker}  [{qflag}]  {score}/100\n"
            f"{'─' * 30}\n"
            f"📌 {badge_str}\n"
            f"📊 RVOL:{rvol:.1f}x | RSI:{rsi:.0f} | ADX:{adx:.0f} | {trend}{cmf_txt}\n"
            f"\n💰 תוכנית מסחר:\n"
            f"  🟢 קנייה:  ${buy_px:.2f}\n"
            f"  🎯 T1:     ${t1_px:.2f}  (+{t1_pct:.1f}%)\n"
            f"  🏆 T2:     ${t2_px:.2f}  (+{t2_pct:.1f}%)\n"
            f"  🛑 Stop:   ${stop_px:.2f}  (-{stop_pct:.1f}%  ATR×1.5)\n"
            f"  ⚖️  R/R:    {rr:.1f} : 1\n"
        )
        parts.append(block)

    # ── 4. Send (split if > 4000 chars) ──────────────────────────────────────
    message = '\n'.join(parts)
    messages_to_send = []
    if len(message) > 4000:
        # split per stock
        header = parts[0]
        for blk in parts[1:]:
            messages_to_send.append(header + blk)
    else:
        messages_to_send.append(message)

    any_sent = False
    for msg in messages_to_send:
        if send_telegram(msg):
            any_sent = True

    if any_sent:
        now_db = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        conn = sqlite3.connect(DB_PATH, timeout=15)
        for c in top:
            conn.execute(
                "UPDATE explosion_candidates "
                "SET telegram_status='SENT', last_alert_sent=? WHERE ticker=?",
                (now_db, c['ticker'])
            )
        conn.commit()
        conn.close()
        log.info(f"Telegram GOLD alerts sent: {len(top)} picks")
        return len(top)
    return 0


# ── SMART MONEY ENRICHMENT ───────────────────────────────────────────────────
def enrich_smart_money(candidates: list):
    """
    Run full Smart Money analysis for top candidates and persist to DB.
    Called after each scan cycle (runs in the background scanner process).
    Only processes score >= TELEGRAM_ALERT_THRESHOLD for performance.
    Full check: UOA (options) + Insider (Form 4) + Squeeze + PEAD + Dark Pool.
    """
    top = [c for c in candidates if c['score'] >= TELEGRAM_ALERT_THRESHOLD]
    if not top:
        return
    try:
        from vinerox_smart_money import get_smart_money_signals
    except ImportError:
        log.warning('[SM] vinerox_smart_money.py not found — skip enrichment')
        return

    conn     = sqlite3.connect(DB_PATH, timeout=30)
    enriched = 0
    boosted  = 0
    for c in top:
        ticker = c['ticker']
        try:
            sm = get_smart_money_signals(
                ticker,
                rvol=c.get('rvol', 1.0),
                pct5=0.0,
                fast_only=False
            )
            # Merge inline dark_pool (scanner-computed — more accurate for today's bar)
            dp = max(int(sm.get('dark_pool', 0)), int(c.get('dark_pool', 0) or 0))

            # ── SMART MONEY BONUS WIRING (Phase 1.2) ──────────────────────
            # Convert 0-100 sm_score into a 0-15 score bonus.
            # Tiered so a single weak signal doesn't inflate score.
            sm_s = int(sm.get('sm_score', 0))
            if   sm_s >= 70: smart_bonus = 15   # 3+ confluent signals — max boost
            elif sm_s >= 50: smart_bonus = 10   # 2 signals
            elif sm_s >= 30: smart_bonus =  5   # 1 strong signal
            else:            smart_bonus =  0

            old_score   = int(c.get('score', 0))
            new_score   = max(1, min(100, old_score + smart_bonus))
            old_flag    = c.get('quality_flag', 'WATCH')
            base_weeks  = int(c.get('base_weeks', 0) or 0)
            rsi_v       = float(c.get('rsi', 50) or 50)
            rvol_v      = float(c.get('rvol', 1.0) or 1.0)
            rec_v       = str(c.get('recommendation', 'HOLD') or 'HOLD').upper()
            coiling_v   = bool(c.get('coiling_setup', 0) or 0)

            # Re-derive quality_flag with the boosted score (preserve hard caps)
            pp_or_rs    = int(c.get('pocket_pivot', 0) or 0) or int(c.get('rs_new_high', 0) or 0)
            has_setup   = bool(pp_or_rs or base_weeks >= 6)
            if   new_score >= 88:  new_flag = 'BESTSTOCK'
            elif new_score >= 79:  new_flag = 'GOLD'
            elif new_score >= 70:  new_flag = 'SILVER'
            else:                  new_flag = 'WATCH'

            # ── ALL HARD CAPS (must mirror score_ticker_daily exactly) ───
            # 1. No base = no GOLD or above
            if base_weeks < 3 and new_flag in ('BESTSTOCK', 'GOLD'):
                new_flag = 'SILVER'
            # 2. RSI > 71 = WATCH (overbought)
            if rsi_v > 71:
                new_flag = 'WATCH'
            # 3. BESTSTOCK requires volume confirmation (RVOL ≥ 1.2)
            if new_flag == 'BESTSTOCK' and rvol_v < 1.2 and not (coiling_v and base_weeks >= 5):
                new_flag = 'GOLD'
            # 4. GOLD requires some volume (RVOL ≥ 0.7)
            if new_flag == 'GOLD' and rvol_v < 0.7 and not coiling_v:
                new_flag = 'SILVER'
            # 5. RECOMMENDATION GUARD — invest tiers must agree with rec engine
            if rec_v in ('SELL', 'STRONG_SELL') and new_flag in ('BESTSTOCK', 'GOLD'):
                new_flag = 'WATCH'
            elif rec_v == 'HOLD' and new_flag == 'BESTSTOCK':
                new_flag = 'GOLD'
            # 6. BESTSTOCK FINAL GATE (v2): require RVOL ≥ 2.5 + buy-side rec concur
            if new_flag == 'BESTSTOCK':
                if rvol_v < 2.5:                     # real institutional flow required
                    new_flag = 'GOLD'
                elif rec_v not in ('BUY', 'STRONG_BUY'):
                    new_flag = 'GOLD'                # rec engine must concur

            conn.execute("""
                UPDATE explosion_candidates
                SET sm_score=?, uoa_flag=?, insider_buying=?, short_squeeze=?,
                    pead=?, dark_pool=?, score=?, quality_flag=?
                WHERE ticker=?
            """, (
                sm['sm_score'], sm['uoa_flag'], sm['insider_buying'],
                sm['short_squeeze'], sm['pead'], dp,
                new_score, new_flag,
                ticker
            ))
            # Update the in-memory candidate dict so Telegram alerts use the boosted score
            c['score']        = new_score
            c['quality_flag'] = new_flag
            c['sm_score']     = sm['sm_score']
            if smart_bonus > 0:
                boosted += 1
            enriched += 1
            log.info(f'[SM] {ticker}: sm_score={sm["sm_score"]} bonus=+{smart_bonus} '
                     f'score:{old_score}->{new_score} flag:{old_flag}->{new_flag} | {sm["description"][:60]}')
        except Exception as e:
            log.debug(f'[SM] {ticker} enrichment skipped: {e}')
    conn.commit()
    conn.close()
    if enriched:
        log.info(f'[SM] Enriched {enriched}/{len(top)} candidates · {boosted} got score boost')


# ── CLEANUP ───────────────────────────────────────────────────────────────────
def clean_old_candidates():
    """Delete stale candidates BUT preserve any ticker that is currently being
    tracked elsewhere (active watchlist entry, open virtual_trade, or open
    signal_outcome).  A recommended ticker must NEVER silently disappear from
    the UI while the user still has exposure or interest in it."""
    # NEVER_DELETE_POLICY (user, 2026-06-14): stocks are never purged. They
    # persist forever and are re-scored / re-classified every cycle so they
    # always live in some page (BESTSTOCK/GOLD/SILVER/WATCH) or in ALERTS.
    # Search + single-pick lookup always find them. Purge disabled.
    log.info('clean_old_candidates: purge DISABLED (NEVER_DELETE_POLICY) - 0 rows deleted')
    return
    cutoff = (datetime.now() - timedelta(hours=48)).strftime('%Y-%m-%d %H:%M:%S')
    conn = sqlite3.connect(DB_PATH, timeout=30)
    try:
        # Collect protected tickers from all live-tracking tables
        protected = set()
        for sql in (
            "SELECT ticker FROM watchlist WHERE status='ACTIVE'",
            "SELECT ticker FROM virtual_trades WHERE status='OPEN'",
            "SELECT ticker FROM signal_outcomes WHERE exit_date IS NULL",
        ):
            try:
                for (t,) in conn.execute(sql).fetchall():
                    if t:
                        protected.add(t.upper())
            except sqlite3.OperationalError:
                pass  # table may not exist on first run

        if protected:
            placeholders = ",".join("?" * len(protected))
            deleted = conn.execute(
                f"DELETE FROM explosion_candidates "
                f"WHERE last_updated < ? AND ticker NOT IN ({placeholders})",
                (cutoff, *protected),
            ).rowcount
        else:
            deleted = conn.execute(
                "DELETE FROM explosion_candidates WHERE last_updated < ?",
                (cutoff,),
            ).rowcount
        conn.commit()
        if deleted:
            log.info(
                f"Purged {deleted} stale candidates (>48h old); "
                f"preserved {len(protected)} tracked tickers"
            )
    finally:
        conn.close()


def _post_scan_self_heal():
    """Idempotent cleanup run at the very end of every scan cycle.

    Removes any non-equity rows, then re-applies all six hard-cap gates to
    every remaining row. This is defence-in-depth: even if a stale process
    or external script writes garbage, the next cycle silently corrects it.
    Returns dict with diagnostics.
    """
    diag = {"purged_non_equity": 0, "retiered": 0, "warnings": []}
    conn = sqlite3.connect(DB_PATH, timeout=30)
    try:
        try:
            from vinerox_instrument_filter import is_explosive_candidate
            rows = conn.execute("SELECT ticker FROM explosion_candidates").fetchall()
            bad = [t for (t,) in rows if not is_explosive_candidate(t)]
            if bad:
                conn.executemany(
                    "DELETE FROM explosion_candidates WHERE ticker = ?",
                    [(t,) for t in bad]
                )
                conn.commit()
                diag["purged_non_equity"] = len(bad)
        except Exception as ex:
            diag["warnings"].append(f"purity heal failed: {ex}")

        # Re-apply hard caps (must mirror score_ticker_daily logic exactly)
        rows = conn.execute(
            "SELECT ticker, score, explosion_score, rvol, rsi, base_weeks, recommendation, quality_flag "
            "FROM explosion_candidates"
        ).fetchall()
        TIERS = ['BESTSTOCK', 'GOLD', 'SILVER', 'WATCH']
        def _demote(t):
            try:
                i = TIERS.index(t)
                return TIERS[i + 1] if i + 1 < len(TIERS) else None
            except ValueError:
                return t
        def _from_explosion_score(es):
            # Mirrors the NEW tier mapping in score_ticker_daily
            return ('BESTSTOCK' if es >= 75 else
                    'GOLD'      if es >= 58 else
                    'SILVER'    if es >= 42 else
                    'WATCH')
        # Load pocket_pivot / rs_new_high for structural gate check
        _struct = {}
        try:
            for (t2, pp, rs) in conn.execute(
                "SELECT ticker, COALESCE(pocket_pivot,0), COALESCE(rs_new_high,0) FROM explosion_candidates"
            ).fetchall():
                _struct[t2] = (int(pp or 0), int(rs or 0))
        except Exception:
            pass

        changed = 0
        for tk, sc, es, rv, rsi, bw, rec, cur in rows:
            sc  = sc  or 0;  es  = es  or 0
            rv  = rv  or 0;  rsi = rsi or 0;  bw = bw or 0
            rec = (rec or '').upper()
            pp, rs = _struct.get(tk, (0, 0))
            new = _from_explosion_score(es)
            # Hard caps (same order as score_ticker_daily)
            if bw < 1:                                       new = 'SILVER'
            if rsi > 82:                                     new = 'WATCH'
            if new == 'BESTSTOCK' and rv < 2.5 and bw < 3:  new = 'GOLD'
            # GOLD RVOL gate — exempt long-base (≥8w) dry-volume setups (O'Neil CANSLIM)
            if new == 'GOLD' and rv < 1.2 and bw < 8:       new = 'SILVER'
            if rec in ('SELL', 'STRONG_SELL') and new in ('BESTSTOCK', 'GOLD'):
                new = 'WATCH'
            if new == 'BESTSTOCK' and rec not in ('BUY', 'STRONG_BUY'):
                new = 'GOLD'
            # ── STRUCTURAL SETUP GATE (מבוסס SPCE/NEXR/EDHL/BJDX/LODE) ─────
            # BESTSTOCK = חייב מבנה מוסדי: PP או RS-New-High או בסיס >=4 שבועות.
            # ספייקים טכניים (ADR קוריאני, בנק, AGX-type) = GOLD לכל היותר.
            _has_struct = bool(pp or rs or bw >= 4)
            if new == 'BESTSTOCK' and not _has_struct:
                new = 'GOLD'    # תיקון AGX/SHG/KB — ספייק ללא מבנה = לא BESTSTOCK
            # ── ADR / FOREIGN BANK GATE (self-heal) ──────────────────────────
            _FOREIGN_BANK_BLOCK = {
                'KB', 'SHG', 'WF', 'SHI', 'HDB', 'IBN', 'BSAC', 'ITUB', 'BBD',
                'BBDO', 'UBS', 'CS', 'DB', 'ING', 'BCS', 'SAN', 'BBVA', 'NMR',
                'AGX',  # Argan Inc — infrastructure EPC, not explosive US growth
            }
            if tk.upper() in _FOREIGN_BANK_BLOCK and new in ('BESTSTOCK', 'GOLD'):
                new = 'SILVER'  # ADR בנק זר = SILVER מקסימום
            if new != cur:
                conn.execute(
                    "UPDATE explosion_candidates SET quality_flag = ? WHERE ticker = ?",
                    (new, tk)
                )
                changed += 1
        conn.commit()
        diag["retiered"] = changed
    finally:
        conn.close()
    log.info(f"[self-heal] purged {diag['purged_non_equity']} non-equity rows; "
             f"re-tiered {diag['retiered']} rows")
    return diag


# ── MAIN SCAN CYCLE ───────────────────────────────────────────────────────────
def _score_from_hist(ticker: str, hist_single: pd.DataFrame, spy_close: pd.Series) -> dict | None:
    """
    Score one ticker using pre-downloaded OHLCV data (avoids per-ticker API calls).
    hist_single must already be a single-ticker DataFrame with columns: open,high,low,close,volume
    """
    # Inject the pre-downloaded data into score_ticker_daily by monkey-patching yf.download
    # via a module-level cache dict that score_ticker_daily checks first.
    _HIST_CACHE[ticker] = hist_single
    try:
        return score_ticker_daily(ticker, spy_close)
    finally:
        _HIST_CACHE.pop(ticker, None)


# Module-level cache: populated by run_scan, consumed by score_ticker_daily
_HIST_CACHE:     dict = {}   # ticker → pre-downloaded OHLCV DataFrame
_MCAP_CACHE:     dict = {}   # ticker → market_cap float (optional, from info)
_EARNINGS_CACHE: dict = {}   # ticker → days_away int|None (populated after scoring)


def run_scan(max_workers: int = 5):
    """
    Batch-download OHLCV for all tickers (50 at a time), then score in parallel.
    Avoids per-ticker yfinance HTTP calls that cause 401 crumb errors.
    """
    import concurrent.futures
    log.info("=" * 60)
    log.info(f"VINEROX SUPER SCANNER — cycle start (batch mode, {max_workers} score workers)")
    log.info("=" * 60)

    _refresh_optimizer_rules()
    if _OPTIMIZER_RULES:
        log.info(f"Optimizer rules: rvol_threshold={_OPTIMIZER_RULES.get('rvol_penalty_threshold','?')}  "
                 f"adx_threshold={_OPTIMIZER_RULES.get('adx_penalty_threshold','?')}")

    tickers = load_tickers()
    log.info(f"Universe: {len(tickers)} US tickers")

    # SPY reference (single call)
    spy_close = None
    try:
        spy_data = yf.download('SPY', period='6mo', interval='1d',
                               auto_adjust=True, progress=False)
        if not spy_data.empty:
            if isinstance(spy_data.columns, pd.MultiIndex):
                spy_data.columns = spy_data.columns.get_level_values(0)
            spy_close = spy_data['Close'].astype(float)
            log.info(f"SPY loaded: {len(spy_close)} bars")
    except Exception as e:
        log.warning(f"SPY fetch failed: {e}")

    # ── PHASE 1: Batch-download all OHLCV data ─────────────────────────────
    # yf.download(list_of_tickers) = 1 HTTP call per batch → no crumb issues
    all_hist: dict = {}   # ticker → single-ticker DataFrame
    n_batches = math.ceil(len(tickers) / BATCH_SIZE)
    log.info(f"Downloading price data: {n_batches} batches of {BATCH_SIZE}...")

    for bi in range(n_batches):
        batch = tickers[bi * BATCH_SIZE:(bi + 1) * BATCH_SIZE]
        try:
            raw = yf.download(batch, period='6mo', interval='1d',
                              auto_adjust=True, progress=False, threads=True)
            if raw.empty:
                continue
            # Multi-ticker download → MultiIndex columns (OHLCV, ticker)
            if isinstance(raw.columns, pd.MultiIndex):
                for t in batch:
                    try:
                        df = raw.xs(t, axis=1, level=1).copy()
                        df.columns = [c.lower() for c in df.columns]
                        df = df.dropna(how='all')
                        if len(df) >= 30:
                            all_hist[t] = df
                    except Exception:
                        pass
            else:
                # Single ticker in batch
                raw.columns = [c.lower() for c in raw.columns]
                if len(raw) >= 30 and len(batch) == 1:
                    all_hist[batch[0]] = raw
        except Exception as e:
            log.debug(f"Batch {bi+1} download error: {e}")
        if (bi + 1) % 5 == 0:
            log.info(f"  Downloaded {bi+1}/{n_batches} batches  ({len(all_hist)} tickers ready)")
        time.sleep(0.5)   # gentle rate-limiting between batches

    log.info(f"Download complete: {len(all_hist)}/{len(tickers)} tickers with valid data")

    # ── PHASE 2: Score all tickers from cached data (5 workers, no HTTP) ──
    candidates    = []
    all_scored    = []
    total_scanned = 0

    def _score_one(ticker):
        hist_df = all_hist.get(ticker)
        if hist_df is None:
            return None
        # Temporarily store in module cache so score_ticker_daily picks it up
        _HIST_CACHE[ticker] = hist_df
        try:
            return score_ticker_daily(ticker, spy_close)
        except Exception as ex:
            log.debug(f"[{ticker}] score error: {ex}")
            return None
        finally:
            _HIST_CACHE.pop(ticker, None)

    scored_tickers = list(all_hist.keys())
    log.info(f"Scoring {len(scored_tickers)} tickers with {max_workers} workers...")
    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_map = {executor.submit(_score_one, t): t for t in scored_tickers}
        for future in concurrent.futures.as_completed(future_map):
            ticker = future_map[future]
            total_scanned += 1
            if total_scanned % 200 == 0:
                log.info(f"  Scored {total_scanned}/{len(scored_tickers)}, {len(candidates)} candidates")
            try:
                result = future.result()
            except Exception:
                continue
            if result is None:
                continue
            all_scored.append(result)
            if result['score'] >= TOP_CANDIDATE_THRESHOLD:
                candidates.append(result)
                _bw = result.get('base_weeks', 0)
                log.info(
                    f"  >> {ticker:6s}  {result['score']:3d}/100  "
                    f"RVOL={result['rvol']:.1f}x  RSI={result['rsi']:.0f}  "
                    f"ADX={result['adx']:.0f}  CMF={result.get('cmf',0):+.2f}  "
                    f"{result['quality_flag']}"
                    f"{'  [PP]'     if result.get('pocket_pivot')  else ''}"
                    f"{'  [RS]'     if result.get('rs_new_high')   else ''}"
                    f"{'  [NR7]'    if result.get('nr7')           else ''}"
                    f"{f'  [VCP{_bw}W]' if _bw >= 3              else ''}"
                )

    # Persist every successfully computed score for the online MASTER feed.
    # This does not alter candidate thresholds, alerts, tiers, or formulas.
    try:
        live_conn = sqlite3.connect(DB_PATH, timeout=30)
        live_conn.execute("""CREATE TABLE IF NOT EXISTS master_live_scores (
            ticker TEXT PRIMARY KEY, score REAL NOT NULL, price REAL,
            volume REAL, rsi REAL, rvol REAL, adx REAL, quality_flag TEXT,
            recommendation TEXT, sector TEXT, raw_metrics TEXT NOT NULL,
            fetched_at TEXT NOT NULL)""")
        live_now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        for scored in all_scored:
            live_conn.execute("""INSERT OR REPLACE INTO master_live_scores
                (ticker, score, price, volume, rsi, rvol, adx, quality_flag,
                 recommendation, sector, raw_metrics, fetched_at)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?)""", (
                scored.get('ticker'), scored.get('score', 0), scored.get('price'),
                scored.get('volume'), scored.get('rsi'), scored.get('rvol'),
                scored.get('adx'), scored.get('quality_flag', 'WATCH'),
                scored.get('recommendation', 'HOLD'), scored.get('sector', ''),
                json.dumps(scored, default=str), live_now))
        live_conn.commit()
        live_conn.close()
        log.info(f"MASTER live persistence: {len(all_scored)} scored rows saved")
    except Exception as live_error:
        log.warning(f"MASTER live persistence failed: {live_error}")

    candidates.sort(key=lambda x: -x['score'])
    gold_count = sum(1 for c in candidates if c.get('quality_flag') in ('GOLD','BESTSTOCK'))
    log.info(
        f"\n{'-'*60}\n"
        f"Scan complete: {total_scanned} scored | "
        f"{len(candidates)} candidates (>={TOP_CANDIDATE_THRESHOLD}) | "
        f"{gold_count} GOLD+\n"
        f"{'-'*60}"
    )

    # ── PHASE 3: Earnings check — only on passing candidates ──────────────
    # Now we do the expensive API call, but only on ~20-50 tickers, not 1700.
    from datetime import date as _date
    log.info(f"Checking earnings proximity for {len(candidates)} candidates...")
    filtered = []
    for c in candidates:
        t = c['ticker']
        earn = None
        try:
            cal = yf.Ticker(t).calendar
            if cal is not None and 'Earnings Date' in cal:
                e_dates = cal['Earnings Date']
                if not isinstance(e_dates, list):
                    e_dates = [e_dates]
                today_d = _date.today()
                for ed in e_dates:
                    if hasattr(ed, 'date'):
                        ed = ed.date()
                    diff = (ed - today_d).days
                    if earn is None or abs(diff) < abs(earn):
                        earn = diff
        except Exception:
            pass
        _EARNINGS_CACHE[t] = earn
        c['earnings_days_away'] = earn
        # Hard block: 5-day window (2 days before announcement price usually gaps up or down)
        # The original 3-day window missed MCW (-1d) and SBAC (-1d) in testing.
        if earn is not None and abs(earn) <= 5:
            log.info(f"  BLOCKED {t}: earnings in {earn}d")
            continue
        # Apply score penalty for approaching earnings
        if earn is not None:
            _eabs = abs(earn)
            if 6 <= _eabs <= 10:
                c['score'] = max(1, c['score'] - 12)   # imminent — gap risk, no edge
            elif 11 <= _eabs <= 18:
                c['score'] = max(1, c['score'] - 6)    # approaching — reduce conviction
            # Re-check quality_flag after penalty
            s = c['score']
            bw = c.get('base_weeks', 0)
            pp = c.get('pocket_pivot', 0)
            rs = c.get('rs_new_high', 0)
            if   s >= 88:  c['quality_flag'] = 'BESTSTOCK'
            elif s >= 79:  c['quality_flag'] = 'GOLD'
            elif s >= 70:  c['quality_flag'] = 'SILVER'
            else:          c['quality_flag'] = 'WATCH'
            if bw < 3 and c['quality_flag'] in ('BESTSTOCK', 'GOLD'):
                c['quality_flag'] = 'SILVER'
            if c.get('rsi', 50) > 71:
                c['quality_flag'] = 'WATCH'
        filtered.append(c)
    candidates = filtered
    gold_count = sum(1 for c in candidates if c.get('quality_flag') in ('GOLD','BESTSTOCK'))
    log.info(f"After earnings filter: {len(candidates)} candidates | {gold_count} GOLD+")
    # ─────────────────────────────────────────────────────────────────────

    # ── PHASE 4: Enrich with Elite Gate data ────────────────────────────
    log.info(f"Enriching candidates with Elite Gate data...")
    try:
        from vinerox_elite_gate import get_elite_candidates
        elite_map = get_elite_candidates() or {}
        for c in candidates:
            ticker = c.get('ticker')
            elite_data = elite_map.get(ticker)
            if elite_data:
                c['elite_tier'] = elite_data.get('tier')
                c['elite_v13_pct'] = elite_data.get('v13_percentile')
                c['elite_win_rate'] = elite_data.get('win_rate_10d')
                c['elite_avg_ret'] = elite_data.get('avg_ret_10d')
                c['elite_n_signals'] = elite_data.get('n_signals')
            else:
                c['elite_tier'] = None
        elite_tier_count = sum(1 for c in candidates if c.get('elite_tier') in ('PLATINUM', 'GOLD', 'WATCH'))
        log.info(f"Elite Gate: {elite_tier_count}/{len(candidates)} candidates match elite criteria")
    except Exception as e:
        log.warning(f"Elite Gate enrichment failed: {e}")
    # ─────────────────────────────────────────────────────────────────────

    store_candidates(candidates)
    alerts_sent = send_telegram_alerts(candidates)
    enrich_smart_money(candidates)
    # ── NEWS CATALYST (May 2026): sentiment scoring for top candidates ──
    try:
        from vinerox_news_catalyst import compute_and_save as _news_save
        _nn = _news_save(DB_PATH)
        log.info(f"news_catalyst updated for {_nn} candidates")
    except Exception as _ex:
        log.warning(f"news_catalyst update failed: {_ex}")
    # ── EXPLOSION PROBABILITY (May 2026): rule-based predictive overlay ──
    try:
        from vinerox_explosion_prob import compute_and_save as _xprob_save
        _n = _xprob_save(DB_PATH)
        log.info(f"explosion_prob updated for {_n} candidates")
    except Exception as _ex:
        log.warning(f"explosion_prob update failed: {_ex}")
    # ── BESTSTOCK PROMOTER (May 2026): single best-buy pick ──
    try:
        from vinerox_beststock_promoter import promote_best as _promote
        _w = _promote(DB_PATH)
        if _w:
            log.info(f"BESTSTOCK = {_w['ticker']} (score={_w['score']:.0f} xprob={_w['explosion_prob']:.1f}%)")
        else:
            log.info("BESTSTOCK: no candidate qualified")
    except Exception as _ex:
        log.warning(f"beststock promoter failed: {_ex}")
    # ── SELF-HEAL: idempotent purity + gate guard (May 2026) ──
    try:
        _post_scan_self_heal()
    except Exception as _ex:
        log.warning(f"self-heal failed: {_ex}")
    # ── AUTO-SYNC VIRTUAL PORTFOLIO (May 2026): every BESTSTOCK/GOLD pick
    # is auto-added at the LIVE online price as the recommended entry. ──
    try:
        from virtual_portfolio import sync_from_tiers as _vp_sync
        _added = _vp_sync(DB_PATH, tiers=('BESTSTOCK', 'GOLD'), silent=True)
        log.info(f"virtual portfolio: +{_added} new auto-trades (BESTSTOCK/GOLD)")
    except Exception as _ex:
        log.warning(f"virtual-portfolio auto-sync failed: {_ex}")
    clean_old_candidates()

    conn = sqlite3.connect(DB_PATH, timeout=15)
    conn.execute(
        "INSERT INTO scan_log (scan_time, tickers_scanned, candidates_found, alerts_sent) "
        "VALUES (?,?,?,?)",
        (datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
         total_scanned, len(candidates), alerts_sent)
    )
    conn.commit()
    conn.close()

    return candidates

    # Load latest optimizer rules for this cycle
    _refresh_optimizer_rules()
    if _OPTIMIZER_RULES:
        log.info(f"Optimizer rules loaded: rvol_threshold={_OPTIMIZER_RULES.get('rvol_penalty_threshold','?')}"
                 f"  adx_threshold={_OPTIMIZER_RULES.get('adx_penalty_threshold','?')}"
                 f"  (last optimized: {_OPTIMIZER_RULES.get('last_optimized','never')})")
    else:
        log.info("Optimizer rules: defaults (no prior optimization run)")

    tickers = load_tickers()
    log.info(f"Universe: {len(tickers)} US tickers")

    # Fetch SPY once for relative strength (shared across all workers)
    spy_close = None
    try:
        spy_data  = yf.download('SPY', period='6mo', interval='1d',
                                auto_adjust=True, progress=False)
        if not spy_data.empty:
            if isinstance(spy_data.columns, pd.MultiIndex):
                spy_data.columns = spy_data.columns.get_level_values(0)
            spy_close = spy_data['Close'].astype(float)
            log.info(f"SPY reference loaded: {len(spy_close)} bars")
    except Exception as e:
        log.warning(f"SPY fetch failed: {e}")

    candidates    = []
    total_scanned = 0

    def _score_one(ticker):
        try:
            return score_ticker_daily(ticker, spy_close)
        except Exception as ex:
            log.debug(f"[{ticker}] worker error: {ex}")
            return None

    log.info(f"Submitting {len(tickers)} tickers to {max_workers}-worker pool...")
    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_map = {executor.submit(_score_one, t): t for t in tickers}
        done = 0
        for future in concurrent.futures.as_completed(future_map):
            ticker = future_map[future]
            total_scanned += 1
            done += 1
            if done % 100 == 0:
                log.info(f"  Progress: {done}/{len(tickers)} scanned, {len(candidates)} candidates so far")
            try:
                result = future.result()
            except Exception:
                continue
            if result is None:
                continue
            if result['score'] >= TOP_CANDIDATE_THRESHOLD:
                candidates.append(result)
                _bw = result.get('base_weeks', 0)
                log.info(
                    f"  >> {ticker:6s}  {result['score']:3d}/100  "
                    f"RVOL={result['rvol']:.1f}x  RSI={result['rsi']:.0f}  "
                    f"ADX={result['adx']:.0f}  CMF={result.get('cmf', 0):+.2f}  {result['quality_flag']}"
                    f"{'  [SQUEEZE]'   if result.get('squeeze')       else ''}"
                    f"{'  [PP]'        if result.get('pocket_pivot')  else ''}"
                    f"{'  [RS_LEAD]'   if result.get('rs_new_high')   else ''}"
                    f"{'  [STAGE2]'    if result.get('weekly_stage2') else ''}"
                    f"{'  [NR7]'       if result.get('nr7')           else ''}"
                    f"{f'  [VCP {_bw}W]' if _bw >= 4                 else ''}"
                )

    candidates.sort(key=lambda x: -x['score'])
    log.info(
        f"\n{'-'*60}\n"
        f"Scan complete: {total_scanned} scanned | "
        f"{len(candidates)} candidates (score >= {TOP_CANDIDATE_THRESHOLD})\n"
        f"{'-'*60}"
    )

    store_candidates(candidates)
    alerts_sent = send_telegram_alerts(candidates)
    enrich_smart_money(candidates)   # full SM check for top picks (UOA + insider + PEAD)
    # ── NEWS CATALYST (May 2026): sentiment scoring for top candidates ──
    try:
        from vinerox_news_catalyst import compute_and_save as _news_save
        _nn = _news_save(DB_PATH)
        log.info(f"news_catalyst updated for {_nn} candidates")
    except Exception as _ex:
        log.warning(f"news_catalyst update failed: {_ex}")
    # ── EXPLOSION PROBABILITY (May 2026): rule-based predictive overlay ──
    try:
        from vinerox_explosion_prob import compute_and_save as _xprob_save
        _n = _xprob_save(DB_PATH)
        log.info(f"explosion_prob updated for {_n} candidates")
    except Exception as _ex:
        log.warning(f"explosion_prob update failed: {_ex}")
    # ── BESTSTOCK PROMOTER (May 2026): single best-buy pick ──
    try:
        from vinerox_beststock_promoter import promote_best as _promote
        _w = _promote(DB_PATH)
        if _w:
            log.info(f"BESTSTOCK = {_w['ticker']} (score={_w['score']:.0f} xprob={_w['explosion_prob']:.1f}%)")
        else:
            log.info("BESTSTOCK: no candidate qualified")
    except Exception as _ex:
        log.warning(f"beststock promoter failed: {_ex}")
    # ── SELF-HEAL: idempotent purity + gate guard (May 2026) ──
    try:
        _post_scan_self_heal()
    except Exception as _ex:
        log.warning(f"self-heal failed: {_ex}")
    # ── AUTO-SYNC VIRTUAL PORTFOLIO (May 2026): every BESTSTOCK/GOLD pick
    # is auto-added at the LIVE online price as the recommended entry. ──
    try:
        from virtual_portfolio import sync_from_tiers as _vp_sync
        _added = _vp_sync(DB_PATH, tiers=('BESTSTOCK', 'GOLD'), silent=True)
        log.info(f"virtual portfolio: +{_added} new auto-trades (BESTSTOCK/GOLD)")
    except Exception as _ex:
        log.warning(f"virtual-portfolio auto-sync failed: {_ex}")
    clean_old_candidates()

    # Log to scan_log table
    conn = sqlite3.connect(DB_PATH, timeout=15)
    conn.execute(
        "INSERT INTO scan_log (scan_time, tickers_scanned, candidates_found, alerts_sent) "
        "VALUES (?,?,?,?)",
        (datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
         total_scanned, len(candidates), alerts_sent)
    )
    conn.commit()
    conn.close()

    return len(candidates), alerts_sent


# ── ENTRY POINT ───────────────────────────────────────────────────────────────
def main():
    log.info("VINEROX Super Scanner Daemon initializing...")
    _fix_yfinance_cache()
    ensure_db()

    tickers = load_tickers()
    send_telegram(
        f"🟢 VINEROX SUPER SCANNER ONLINE\n"
        f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M')}\n"
        f"Universe: {len(tickers)} US stocks\n"
        f"Scan interval: every {SCAN_INTERVAL_H}h\n"
        f"Alert threshold: score ≥ {TELEGRAM_ALERT_THRESHOLD}/100"
    )

    while True:
        try:
            cands = run_scan()
            n_cand = len(cands)
            n_alerts = sum(1 for c in cands if c.get('quality_flag') in ('GOLD','BESTSTOCK'))
            next_scan = datetime.now() + timedelta(hours=SCAN_INTERVAL_H)
            log.info(
                f"Cycle done. Candidates: {n_cand}, GOLD+: {n_alerts}. "
                f"Next scan at {next_scan.strftime('%H:%M')}"
            )
        except Exception as e:
            log.error(f"MAIN LOOP ERROR: {e}", exc_info=True)
            send_telegram(f"⚠️ VINEROX SCANNER ERROR:\n{e}")

        time.sleep(SCAN_INTERVAL_H * 3600)


if __name__ == '__main__':
    main()
