from __future__ import annotations

import io
import json
import os
import sqlite3
import uuid
from datetime import datetime, timezone
from pathlib import Path

from google.cloud import bigquery


PROJECT = os.environ['BQ_PROJECT']
DATASET = os.environ.get('BQ_SCANNER_DATASET', 'vinerox_scanner')
LOCATION = os.environ.get('BQ_LOCATION', 'US')
SENTINEL_DB = Path(os.environ.get(
    'VINEROX_SENTINEL_DB', '/opt/vinerox/data/vinerox_sentinel.db'))
MASTER_DB = Path(os.environ.get(
    'VINEROX_MASTER_DB', '/opt/vinerox/data/master_scores.db'))

SNAPSHOT_TABLES = (
    'explosion_candidates',
    'sp500_candidates',
    'microcap_rockets',
    'continuation_rockets',
    'v17_cache',
)


def read_rows(path: Path, table: str) -> list[dict[str, object]]:
    if not path.exists():
        return []
    connection = sqlite3.connect(f'file:{path}?mode=ro', uri=True, timeout=20)
    try:
        connection.row_factory = sqlite3.Row
        cursor = connection.execute(f'SELECT * FROM "{table}"')
        return [
            {key: value for key, value in dict(row).items()}
            for row in cursor.fetchall()
        ]
    except sqlite3.Error:
        return []
    finally:
        connection.close()


def table_exists(path: Path, table: str) -> bool:
    if not path.exists():
        return False
    connection = sqlite3.connect(f'file:{path}?mode=ro', uri=True, timeout=20)
    try:
        return connection.execute(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?",
            (table,),
        ).fetchone() is not None
    finally:
        connection.close()


def replace_table(client: bigquery.Client, table: str, rows: list[dict[str, object]]) -> int:
    if not rows:
        return 0
    table_id = f'{PROJECT}.{DATASET}.{table}'
    payload = '\n'.join(json.dumps(row, default=str) for row in rows).encode()
    config = bigquery.LoadJobConfig(
        autodetect=True,
        write_disposition='WRITE_TRUNCATE',
        source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
        ignore_unknown_values=True,
    )
    client.load_table_from_file(io.BytesIO(payload), table_id, job_config=config).result()
    return len(rows)


def append_table(client: bigquery.Client, table: str, rows: list[dict[str, object]]) -> int:
    if not rows:
        return 0
    table_id = f'{PROJECT}.{DATASET}.{table}'
    payload = '\n'.join(json.dumps(row, default=str) for row in rows).encode()
    config = bigquery.LoadJobConfig(
        autodetect=True,
        write_disposition='WRITE_APPEND',
        source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
        ignore_unknown_values=True,
    )
    client.load_table_from_file(io.BytesIO(payload), table_id, job_config=config).result()
    return len(rows)


def main() -> None:
    now = datetime.now(timezone.utc).isoformat()
    run_id = uuid.uuid4().hex
    client = bigquery.Client(project=PROJECT)
    dataset_id = f'{PROJECT}.{DATASET}'
    try:
        client.get_dataset(dataset_id)
    except Exception:
        dataset = bigquery.Dataset(dataset_id)
        dataset.location = LOCATION
        client.create_dataset(dataset, exists_ok=True)

    status: list[dict[str, object]] = []
    for source, table in ((SENTINEL_DB, name) for name in SNAPSHOT_TABLES):
        rows = read_rows(source, table)
        name = f'scanner_{table}_current'
        count = replace_table(client, name, rows)
        status.append({
            'run_id': run_id,
            'source': str(source),
            'table_name': table,
            'row_count': count,
            'source_mtime': datetime.fromtimestamp(
                source.stat().st_mtime, timezone.utc).isoformat()
                if source.exists() else None,
            'exported_at': now,
        })

    master_rows = read_rows(MASTER_DB, 'master_scores')
    replace_table(client, 'master_scores_current', master_rows)
    append_table(client, 'master_scores_history', [
        {**row, 'run_id': run_id, 'exported_at': now}
        for row in master_rows
    ])
    status.append({
        'run_id': run_id,
        'source': str(MASTER_DB),
        'table_name': 'master_scores',
        'row_count': len(master_rows),
        'source_mtime': datetime.fromtimestamp(
            MASTER_DB.stat().st_mtime, timezone.utc).isoformat()
            if MASTER_DB.exists() else None,
        'exported_at': now,
    })
    replace_table(client, 'scanner_sync_status', status)
    print(json.dumps({'run_id': run_id, 'status_rows': len(status)}, default=str))


if __name__ == '__main__':
    main()