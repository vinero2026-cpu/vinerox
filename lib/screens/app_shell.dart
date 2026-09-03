import 'package:flutter/material.dart';

import '../api/client.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'narrator_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final ApiClient _api = ApiClient();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeScreen(),
      DataScreen(
        title: 'Positions',
        icon: Icons.account_balance_wallet_outlined,
        apiCall: _api.positions,
        emptyText: 'No open positions right now.',
      ),
      DataScreen(
        title: 'Portfolio',
        icon: Icons.pie_chart_outline,
        apiCall: _api.portfolio,
        emptyText: 'Your portfolio is empty.',
      ),
      const DataScreen(
        title: 'Alerts',
        icon: Icons.notifications_none_rounded,
        emptyText: 'No new alerts.',
      ),
      MoreScreen(api: _api),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        indicatorColor: VineroxTheme.accent.withValues(alpha: 0.18),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.show_chart_outlined), selectedIcon: Icon(Icons.show_chart), label: 'Positions'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Portfolio'),
          NavigationDestination(icon: Icon(Icons.notifications_none), selectedIcon: Icon(Icons.notifications), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.more_horiz), selectedIcon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}

class DataScreen extends StatefulWidget {
  const DataScreen({super.key, required this.title, required this.icon, this.apiCall, required this.emptyText});
  final String title;
  final IconData icon;
  final Future<Map<String, dynamic>> Function()? apiCall;
  final String emptyText;

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  late Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _future = widget.apiCall?.call();
  }

  Future<void> _refresh() async {
    if (widget.apiCall == null) return;
    setState(() => _future = widget.apiCall!.call());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: VineroxTheme.accent,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(widget.icon, size: 44, color: VineroxTheme.accent),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Unable to load ${widget.title.toLowerCase()}: ${snapshot.error}');
                }
                final data = snapshot.data;
                final positions = data?['positions'];
                if (positions is! List || positions.isEmpty) {
                  return Center(child: Text(widget.emptyText));
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('${positions.length} items', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    ...positions.map((item) => Card(
                      child: ListTile(
                        title: Text(item is Map ? item['ticker']?.toString() ?? 'Position' : 'Position'),
                        subtitle: Text(item is Map ? item['company']?.toString() ?? '' : ''),
                      ),
                    )),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.api});
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('VINERO Narrator'),
            subtitle: const Text('Signals, scores and system guidance'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NarratorScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync status'),
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => FutureBuilder<Map<String, dynamic>>(
                future: api.syncHealth(),
                builder: (_, snapshot) => AlertDialog(
                  title: const Text('Sync status'),
                  content: Text(snapshot.hasError ? 'Unavailable' : snapshot.data?['overall']?.toString() ?? 'Loading...'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
