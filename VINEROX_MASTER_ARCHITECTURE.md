# VINEROX MASTER

## Canonical Scope

When the task says `VINEROX MASTER`, it refers to the live stock scanner at:

- Public UI: `https://vinero.app/stocks/`
- Public snapshot feed: `https://vinero.app/stocks/master.json`
- Read API: `https://api.vinero.app/api/stocks/master`
- Production host: `root@178.105.85.44`

This scope is separate from the Flutter mobile UI. Do not change Flutter screens
when working on the MASTER scanner unless explicitly requested.

The native Stock Arena app is now explicitly connected to this feed through its
dedicated `MASTER` tab. It requests the full `/api/stocks/master` envelope,
preserves every row, and renders `ok` rows as live and `stale` rows in red.

## Production Data Flow

```text
Active stock scanners
  -> /opt/vinerox/data/vinerox_sentinel.db
  -> master_live_scores (all successfully computed scanner scores)
  -> /opt/vinerox/server_ops/vinerox_master_online.py
  -> /opt/vinerox/data/master_scores.db
  -> /var/www/stocks/master.json
  -> vinero.app/stocks/
  -> BigQuery mirror: psyched-ray-472608-f9.vinerox_scanner
```

Existing scanner formulas and alert thresholds remain in the scanner processes.
The online publisher does not invent or recalculate scores. It merges scores
already computed by the scanners and marks rows without a recent source result
as `stale`.

## Services and Schedules

- `vinerox.service`: master supervisor and scanner processes.
- `vinerox-master-online.timer`: publishes MASTER every 15 minutes.
- `vinerox-scanner-bq-export.timer`: mirrors scanner and MASTER snapshots to
  BigQuery every 15 minutes.
- `vinerox-api.service`: serves `/api/stocks/master`.

The active scanner universe is loaded from `data/active_universe.csv`. Yahoo
rate limits or missing source data must be recorded as stale/error; old data
must never be presented as live.

## Current Tables

Operational SQLite:

- `/opt/vinerox/data/vinerox_sentinel.db`
- `/opt/vinerox/data/master_scores.db`

BigQuery dataset:

- Project: `psyched-ray-472608-f9`
- Dataset: `vinerox_scanner`
- Current scanner tables: `scanner_*_current`
- Current MASTER table: `master_scores_current`
- History: `master_scores_history_v2`
- Health: `scanner_sync_status`

## Freshness Contract

- `status=ok` means the source timestamp is within the publisher freshness
  window (currently two hours).
- `status=stale` means a current source result was not available.
- `fetched_at` is the source timestamp, not the publish timestamp.
- Every publisher run writes a `run_id` and `finished_at` to `master_runs`.
- The web JSON is replaced atomically only after the local snapshot is built.

## Git Checkpoints

- `9eaa3a6`: BigQuery scanner mirror and 15-minute export timer.
- `c6ba8c1`: online MASTER publisher and recurring timer.
- `c7b3a70`: persistence of all successfully computed scanner scores.
- `0f381a9`: publish freshness status to the STOCKS UI feed.

## Verification

Check the public feed and timers:

```powershell
ssh -i C:\Users\USER\.ssh\hetzner_vinerox root@178.105.85.44 "systemctl is-active vinerox-master-online.timer; systemctl is-active vinerox-scanner-bq-export.timer"
curl.exe -sS https://vinero.app/stocks/master.json
```

Do not report the system as fully live unless `master_scores.db`,
`master.json`, the API, and BigQuery show a recent matching `run_id` and the
fresh/stale counts are understood.