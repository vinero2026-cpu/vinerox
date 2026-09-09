import 'package:flutter_test/flutter_test.dart';

import 'package:vinerox_mobile/models/master_stock.dart';

void main() {
  test('MasterFeed preserves every live and stale stock row', () {
    final feed = MasterFeed.fromJson({
      'run_id': 'run-1',
      'created_at': '2026-09-09T10:00:00+00:00',
      'row_count': 2,
      'rows': [
        {
          'ticker': 'LIVE',
          'score': 91.5,
          'status': 'ok',
          'fetched_at': '2026-09-09T09:59:00+00:00',
        },
        {
          'ticker': 'OLD',
          'score': 40,
          'status': 'stale',
          'fetched_at': '2026-09-08T09:00:00+00:00',
        },
      ],
    });

    expect(feed.rows, hasLength(2));
    expect(feed.liveCount, 1);
    expect(feed.staleCount, 1);
    expect(feed.rows.first.ticker, 'LIVE');
    expect(feed.rows.last.status, 'stale');
  });
}
