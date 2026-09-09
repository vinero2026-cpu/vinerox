import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'my_team_screen.dart';
import 'live_refresh.dart';
import 'shop_screen.dart';
import 'tabs.dart';
import 'theme.dart';
import 'widgets.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 3;
  late final LiveRefreshController _liveRefresh;

  static const _titles = ['Shop', 'Rank', 'League', 'My Team', 'Market'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _liveRefresh = LiveRefreshController()..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _liveRefresh.request();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveRefresh.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _liveRefresh.request();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_titles[_index]),
            _LiveStatus(controller: _liveRefresh),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh live data',
            onPressed: _liveRefresh.isRefreshing
                ? null
                : () => _liveRefresh.request(),
            icon: _liveRefresh.isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => showModalBottomSheet(
              context: context,
              backgroundColor: AC.bgAlt,
              showDragHandle: true,
              builder: (_) => const _NotificationsSheet(),
            ),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            tooltip: 'Account',
            onPressed: () => showModalBottomSheet(
              context: context,
              backgroundColor: AC.bgAlt,
              showDragHandle: true,
              isScrollControlled: true,
              builder: (_) => AccountSheet(onSignedOut: widget.onSignedOut),
            ),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          _PageAtmosphere(kind: _PageAtmosphereKind.shop, child: ShopScreen(refreshController: _liveRefresh)),
          _PageAtmosphere(kind: _PageAtmosphereKind.rank, child: RankScreen(refreshController: _liveRefresh)),
          _PageAtmosphere(kind: _PageAtmosphereKind.league, child: LeagueScreen(refreshController: _liveRefresh)),
          _PageAtmosphere(kind: _PageAtmosphereKind.team, child: MyTeamScreen(refreshController: _liveRefresh)),
          _PageAtmosphere(kind: _PageAtmosphereKind.market, child: MarketScreen(refreshController: _liveRefresh)),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Colors.transparent,
          indicatorColor: AC.gold.withValues(alpha: .22),
          indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: AC.gold.withValues(alpha: .35))),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: states.contains(WidgetState.selected)
                  ? AC.gold
                  : AC.textFaint,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              size: 22,
              color: states.contains(WidgetState.selected)
                  ? AC.gold
                  : AC.textFaint,
            ),
          ),
        ),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AC.surfaceHi, AC.bgAlt],
            ),
          ),
          child: NavigationBar(
            height: 76,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
            NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront_rounded),
                label: 'SHOP'),
            NavigationDestination(
                icon: Icon(Icons.leaderboard_outlined),
                selectedIcon: Icon(Icons.leaderboard_rounded),
                label: 'RANK'),
            NavigationDestination(
                icon: Icon(Icons.emoji_events_outlined),
                selectedIcon: Icon(Icons.emoji_events_rounded),
                label: 'LEAGUE'),
            NavigationDestination(
                icon: Icon(Icons.shield_outlined),
                selectedIcon: Icon(Icons.shield_rounded),
                label: 'MY TEAM'),
            NavigationDestination(
                icon: Icon(Icons.swap_horiz_outlined),
                selectedIcon: Icon(Icons.swap_horiz_rounded),
                label: 'MARKET'),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveStatus extends StatelessWidget {
  const _LiveStatus({required this.controller});
  final LiveRefreshController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final time = controller.lastUpdated;
        final label = controller.isRefreshing
            ? 'UPDATING ${controller.completed}/5'
            : time == null
                ? 'LIVE · CONNECTING'
                : 'LIVE · ${_formatTime(time)}';
        final color = controller.lastError != null
            ? AC.warn
            : controller.isRefreshing
                ? AC.gold
                : AC.teal;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 8,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800)),
          ],
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}

enum _PageAtmosphereKind { shop, rank, league, team, market }

class _PageAtmosphere extends StatelessWidget {
  const _PageAtmosphere({required this.kind, required this.child});
  final _PageAtmosphereKind kind;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = switch (kind) {
      _PageAtmosphereKind.shop => const [Color(0xFF211A0D), AC.bg],
      _PageAtmosphereKind.rank => const [Color(0xFF0D1B31), AC.bg],
      _PageAtmosphereKind.league => const [Color(0xFF082A2A), AC.bg],
      _PageAtmosphereKind.team => const [Color(0xFF24152A), AC.bg],
      _PageAtmosphereKind.market => const [Color(0xFF0D241F), AC.bg],
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.72, -0.9),
          radius: 1.15,
          colors: [colors.first.withValues(alpha: .72), colors.last],
        ),
      ),
      child: child,
    );
  }
}

class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 380,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: AsyncView<List<dynamic>>(
          future: ArenaApi.instance.notifications(),
          builder: (context, rows) {
            if (rows.isEmpty) {
              return const EmptyState(
                icon: Icons.notifications_off_rounded,
                title: 'No messages',
                subtitle: 'Alerts and news will show up here.',
              );
            }
            return ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 18),
              itemBuilder: (_, i) {
                final row = Map<String, dynamic>.from(rows[i] as Map);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.campaign_rounded, color: AC.gold),
                  title: Text(row.str('title', 'Update')),
                  subtitle: Text(row.str('body', row.str('message'))),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Account & privacy. Google Play requires an in-app route to delete the
/// account and links to the privacy policy.
class AccountSheet extends StatelessWidget {
  const AccountSheet({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.surface,
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently removes your club, squad, Vineros and history. '
          'It cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AC.bear, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ArenaApi.instance.deleteAccount();
      if (context.mounted) Navigator.pop(context);
      onSignedOut();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Account',
                style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 20,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _LinkTile(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy policy',
              onTap: () => launchUrl(Uri.parse(kPrivacyUrl),
                  mode: LaunchMode.externalApplication),
            ),
            _LinkTile(
              icon: Icons.description_outlined,
              label: 'Terms of service',
              onTap: () => launchUrl(Uri.parse(kTermsUrl),
                  mode: LaunchMode.externalApplication),
            ),
            const Divider(height: 24),
            _LinkTile(
              icon: Icons.logout_rounded,
              label: 'Sign out',
              onTap: () async {
                await ArenaApi.instance.signOut();
                if (context.mounted) Navigator.pop(context);
                onSignedOut();
              },
            ),
            _LinkTile(
              icon: Icons.delete_forever_outlined,
              label: 'Delete account',
              color: AC.bear,
              onTap: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AC.text;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(icon, color: c, size: 21),
      title: Text(label, style: TextStyle(color: c, fontSize: 15)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AC.textFaint),
    );
  }
}
