from __future__ import annotations

import json
import os
import shutil
import sqlite3
import tempfile
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path


SENTINEL = Path(os.environ.get(
    'VINEROX_SENTINEL_DB', '/opt/vinerox/data/vinerox_sentinel.db'))
MASTER = Path(os.environ.get(
    'VINEROX_MASTER_DB', '/opt/vinerox/data/master_scores.db'))


def rows(connection: sqlite3.Connection, table: str) -> list[dict]:
    connection.row_factory = sqlite3.Row
    try:
        return [dict(row) for row in connection.execute(f'SELECT * FROM "{table}"')]
    except sqlite3.Error:
        return []


def latest_by_ticker(values: list[dict], time_keys: tuple[str, ...]) -> dict[str, dict]:
    output: dict[str, dict] = {}
    for row in values:
        ticker = str(row.get('ticker') or '').upper().strip()
        if not ticker:
            continue
        current = output.get(ticker)
        stamp = max((str(row.get(key) or '') for key in time_keys), default='')
        old_stamp = max((str(current.get(key) or '') for key in time_keys), default='') if current else ''
        if current is None or stamp >= old_stamp:
            output[ticker] = row
    return output


def json_value(value: object) -> str:
    return json.dumps(value, default=str, ensure_ascii=False)


def is_recent(value: object) -> bool:
    if not value:
        return False
    try:
        stamp = datetime.fromisoformat(str(value).replace('Z', '+00:00'))
        if stamp.tzinfo is None:
            stamp = stamp.replace(tzinfo=timezone.utc)
        return datetime.now(timezone.utc) - stamp <= timedelta(hours=2)
    except ValueError:
        return False


def main() -> None:
    run_id = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    started = datetime.now(timezone.utc).isoformat()
    source = sqlite3.connect(f'file:{SENTINEL}?mode=ro', uri=True, timeout=30)
    master_tmp = Path(tempfile.mktemp(prefix='master_scores.', suffix='.db', dir=MASTER.parent))
    backup = MASTER.with_suffix('.db.bak_online')
    try:
        source_sets = [
            latest_by_ticker(rows(source, 'stock_score_history'), ('run_ts',)),
            latest_by_ticker(rows(source, 'explosion_candidates'), ('last_updated',)),
            latest_by_ticker(rows(source, 'sp500_candidates'), ('last_updated',)),
            latest_by_ticker(rows(source, 'microcap_rockets'), ('last_updated',)),
            latest_by_ticker(rows(source, 'continuation_rockets'), ('last_updated',)),
        ]
    finally:
        source.close()

    fresh: dict[str, dict] = {}
    for source_set in source_sets:
        for ticker, row in source_set.items():
            fresh.setdefault(ticker, row)

    old = sqlite3.connect(f'file:{MASTER}?mode=ro', uri=True, timeout=30)
    old.row_factory = sqlite3.Row
    old_rows = [dict(row) for row in old.execute('SELECT * FROM master_scores')]
    old.close()

    connection = sqlite3.connect(master_tmp)
    connection.execute('''CREATE TABLE master_scores (
        ticker TEXT PRIMARY KEY, score REAL NOT NULL, confidence REAL NOT NULL,
        data_quality REAL NOT NULL, metric_scores TEXT NOT NULL,
        metric_status TEXT NOT NULL, missing_metrics TEXT NOT NULL,
        source_presence TEXT NOT NULL, price REAL, volume REAL,
        fetched_at TEXT NOT NULL, status TEXT NOT NULL, error TEXT,
        error_kind TEXT, retry_after TEXT, company_name TEXT, exchange TEXT,
        sector TEXT, industry TEXT, logo_url TEXT,
        identity_fetched_at TEXT, raw_metrics TEXT NOT NULL DEFAULT '{}')''')
    now = datetime.now(timezone.utc).isoformat()

    def write(ticker: str, row: dict, is_fresh: bool) -> None:
        score = next((row[key] for key in (
            'score', 'big_score', 'v17_score', 'pre_explosion_score',
            'cont_score', 'alert_score') if row.get(key) is not None), 0)
        fetched = row.get('run_ts') or row.get('last_updated') or now
        company = row.get('company') or row.get('company_name') or ''
        source_name = row.get('_source', 'live_scanner')
        connection.execute('INSERT OR REPLACE INTO master_scores VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)', (
            ticker, float(score or 0), 100.0 if is_fresh else 0.0,
            100.0 if is_fresh else 0.0, json_value({'score_source': source_name}),
            json_value({}), json_value([]), json_value({'source': source_name}),
            row.get('price'), row.get('volume'), str(fetched),
            'ok' if is_fresh else 'stale', None if is_fresh else 'source_not_refreshed',
            None if is_fresh else 'stale_source', None, company,
            row.get('exchange', ''), row.get('sector', ''), row.get('industry', ''),
            row.get('logo_url', ''), str(fetched), json_value(row)))

    for index, source_set in enumerate(source_sets):
        source_name = ('stock_score_history', 'explosion_candidates',
                       'sp500_candidates', 'microcap_rockets',
                       'continuation_rockets')[index]
        for ticker, row in source_set.items():
            row['_source'] = source_name
            source_time = row.get('run_ts') or row.get('last_updated')
            write(ticker, row, is_recent(source_time))
    for row in old_rows:
        if row['ticker'] not in fresh:
            write(row['ticker'], row, False)

    scored = connection.execute("SELECT COUNT(*) FROM master_scores WHERE status='ok'").fetchone()[0]
    total = connection.execute('SELECT COUNT(*) FROM master_scores').fetchone()[0]
    finished = datetime.now(timezone.utc).isoformat()
    connection.execute('''CREATE TABLE master_runs (
        run_id TEXT PRIMARY KEY, started_at TEXT NOT NULL, finished_at TEXT,
        requested_symbols INTEGER NOT NULL, scored_symbols INTEGER NOT NULL,
        yahoo_successes INTEGER NOT NULL DEFAULT 0, yahoo_failures INTEGER NOT NULL DEFAULT 0,
        batch_errors INTEGER NOT NULL DEFAULT 0)''')
    connection.execute('INSERT INTO master_runs VALUES (?,?,?,?,?,?,?,?)',
                       (run_id, started, finished, total, scored, scored, 0, 0))
    connection.commit()
    connection.close()
    if MASTER.exists():
        shutil.copy2(MASTER, backup)
    os.replace(master_tmp, MASTER)
    print(json.dumps({'run_id': run_id, 'total': total, 'fresh': scored,
                      'stale': total - scored, 'finished_at': finished}))


if __name__ == '__main__':
    main()