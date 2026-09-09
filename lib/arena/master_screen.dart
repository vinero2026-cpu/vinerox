import 'dart:async';

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../models/master_stock.dart';
import 'live_refresh.dart';
import 'theme.dart';
import 'widgets.dart';

class MasterScreen extends StatefulWidget {
  const MasterScreen({super.key, required this.refreshController});

  final LiveRefreshController refreshController;

  @override
  State<MasterScreen> createState() => _MasterScreenState();
}

class _MasterScreenState extends State<MasterScreen> {
  final ApiClient _api = ApiClient();
  late Future<MasterFeed> _future;
  int _handledGeneration = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
    widget.refreshController.addListener(_onRefreshRequested);
  }

  @override
  void dispose() {
    widget.refreshController.removeListener(_onRefreshRequested);
    super.dispose();
  }

  Future<MasterFeed> _load() => _api.masterFeed();

  void _onRefreshRequested() {
    if (!mounted || !widget.refreshController.isRefreshing) return;
    if (_handledGeneration == widget.refreshController.generation) return;
    _handledGeneration = widget.refreshController.generation;
    unawaited(_refreshLive());
  }

  Future<void> _refreshLive() async {
    try {
      final next = _load();
      setState(() => _future = next);
      await next;
      widget.refreshController.reportSuccess();
    } catch (error) {
      widget.refreshController.reportFailure(error);
    }
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AC.gold,
      backgroundColor: AC.surface,
      child: FutureBuilder<MasterFeed>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && !snapshot.hasData) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 120),
                EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'MASTER unavailable',
                  subtitle: snapshot.error.toString(),
                ),
              ],
            );
          }
          final feed = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 120),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: feed.rows.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return _MasterHeader(feed: feed);
              return _MasterRow(stock: feed.rows[index - 1]);
            },
          );
        },
      ),
    );
  }
}

class _MasterHeader extends StatelessWidget {
  const _MasterHeader({required this.feed});
  final MasterFeed feed;

  @override
  Widget build(BuildContext context) {
    final live = feed.liveCount;
    final stale = feed.staleCount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        title: 'VINEROX MASTER',
        trailing: Text('${feed.rowCount} stocks',
            style: const TextStyle(fontSize: 11, color: AC.textFaint)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle,
                    size: 9, color: stale == 0 ? AC.teal : AC.warn),
                const SizedBox(width: 7),
                Text(stale == 0 ? 'LIVE DATA' : 'LIVE FEED · $stale STALE',
                    style: TextStyle(
                        color: stale == 0 ? AC.teal : AC.warn,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.1)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Updated ${_formatTimestamp(feed.createdAt)}',
                style: const TextStyle(color: AC.textDim, fontSize: 12)),
            const SizedBox(height: 4),
            Text('$live live scores · $stale awaiting fresh source data',
                style: const TextStyle(color: AC.textFaint, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(String value) {
    if (value.isEmpty) return 'unknown';
    try {
      final time = DateTime.parse(value).toLocal();
      return '${time.day.toString().padLeft(2, '0')}/'
          '${time.month.toString().padLeft(2, '0')} '
          '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return value;
    }
  }
}

class _MasterRow extends StatelessWidget {
  const _MasterRow({required this.stock});
  final MasterStock stock;

  @override
  Widget build(BuildContext context) {
    final live = stock.status == 'ok';
    final color = live ? AC.teal : AC.bear;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: live ? AC.surface : AC.bear.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: live ? AC.stroke : AC.bear),
      ),
      child: Row(
        children: [
          StockLogo(ticker: stock.ticker, logoUrl: stock.logoUrl, size: 38, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stock.ticker,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(stock.companyName.isEmpty ? stock.status.toUpperCase() : stock.companyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: live ? AC.textDim : AC.bear)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('VX ${stock.score.toStringAsFixed(1)}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w900)),
              Text(live ? 'LIVE' : 'STALE',
                  style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}
