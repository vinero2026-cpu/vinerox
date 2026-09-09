import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'live_refresh.dart';
import 'theme.dart';
import 'widgets.dart';

/// SHOP — spends in-game currency only.
///
/// Google Play requires Play Billing for any purchase of virtual currency, so
/// real-money top-up packs are gated behind [kRealMoneyTopUpsEnabled] and stay
/// off on Android until Play Billing is integrated.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, required this.refreshController});
  final LiveRefreshController refreshController;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late Future<_ShopBundle> _future;
  int _handledGeneration = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
    widget.refreshController.addListener(_onLiveRefresh);
  }

  @override
  void dispose() {
    widget.refreshController.removeListener(_onLiveRefresh);
    super.dispose();
  }

  void _onLiveRefresh() {
    if (!widget.refreshController.isRefreshing || !mounted) return;
    if (_handledGeneration == widget.refreshController.generation) return;
    _handledGeneration = widget.refreshController.generation;
    _refreshLive();
  }

  Future<void> _refreshLive() async {
    try {
      await _refresh();
      widget.refreshController.reportSuccess();
    } catch (error) {
      widget.refreshController.reportFailure(error);
    }
  }

  Future<_ShopBundle> _load() async {
    final api = ArenaApi.instance;
    final results = await Future.wait([
      api.balances().catchError((_) => <String, dynamic>{}),
      api.chests().catchError((_) => <String, dynamic>{}),
      api.fanBudget().catchError((_) => <String, dynamic>{}),
    ]);
    return _ShopBundle(
        wallet: results[0], chests: results[1], fanBudget: results[2]);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  Future<void> _open(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ArenaApi.instance.openChest(id);
      messenger.showSnackBar(const SnackBar(content: Text('Chest opened.')));
      await _refresh();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AC.gold,
      backgroundColor: AC.surface,
      child: AsyncView<_ShopBundle>(
        future: _future,
        onRetry: _refresh,
        loadingHeight: 400,
        builder: (context, data) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _WalletBar(wallet: data.wallet),
            const SizedBox(height: 14),
            _EarnCard(
                available: data.dailyAvailable, onDone: _refresh),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Your chests',
              trailing: Text('${data.chestList.length} waiting',
                  style: const TextStyle(fontSize: 11, color: AC.textFaint)),
              child: data.chestList.isEmpty
                  ? const EmptyState(
                      icon: Icons.inventory_2_rounded,
                      title: 'No chests yet',
                      subtitle:
                          'Claim the daily chest and win duels to earn more.',
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < data.chestList.length; i++) ...[
                          if (i > 0) const Divider(height: 20),
                          _ChestRow(chest: data.chestList[i], onOpen: _open),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            _FanBudgetCard(data: data, onDone: _refresh),
            if (kRealMoneyTopUpsEnabled) ...[
              const SizedBox(height: 14),
              const _TopUpPlaceholder(),
            ],
            const SizedBox(height: 14),
            const _CoinsInfoCard(),
          ],
        ),
      ),
    );
  }
}

class _ShopBundle {
  _ShopBundle(
      {required this.wallet, required this.chests, required this.fanBudget});

  final Map<String, dynamic> wallet;
  final Map<String, dynamic> chests;
  final Map<String, dynamic> fanBudget;

  int get vineros => wallet.intOr('vcoin');
  int get vpoints => wallet.intOr('vpoints');
  int get rate => wallet.intOr('rate', 100);
  bool get dailyAvailable => chests['daily_available'] == true;
  List<Map<String, dynamic>> get chestList => chests.rows('chests');
  bool get canAppeal => fanBudget['available'] == true;
  double get boardApproval => fanBudget.dbl('board_approval', 50);
}

class _WalletBar extends StatelessWidget {
  const _WalletBar({required this.wallet});
  final Map<String, dynamic> wallet;

  @override
  Widget build(BuildContext context) {
    final vineros = wallet.intOr('vcoin');
    final vpoints = wallet.intOr('vpoints');
    final rank = wallet.intOr('vpoints_rank');
    return Row(
      children: [
        Expanded(
          child: StatChip(
              label: 'Vineros',
              value: '$vineros',
              icon: Icons.toll_rounded,
              color: AC.gold),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatChip(
              label: 'V-Points',
              value: '$vpoints',
              icon: Icons.star_rounded,
              color: AC.teal),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatChip(
              label: 'Rank',
              value: rank > 0 ? '#$rank' : '—',
              icon: Icons.trending_up_rounded,
              color: AC.blue),
        ),
      ],
    );
  }
}

class _ChestRow extends StatelessWidget {
  const _ChestRow({required this.chest, required this.onOpen});

  final Map<String, dynamic> chest;
  final Future<void> Function(String id) onOpen;

  @override
  Widget build(BuildContext context) {
    final id = chest.str('id', chest.str('chest_id'));
    final kind = chest.str('kind', chest.str('tier', 'BRONZE'));
    final colour = AC.tier(kind);
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: colour.withValues(alpha: .15),
            border: Border.all(color: colour.withValues(alpha: .4)),
          ),
          child: Icon(Icons.inventory_2_rounded, size: 19, color: colour),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text('$kind chest',
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(76, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          onPressed: id.isEmpty ? null : () => onOpen(id),
          child: const Text('OPEN'),
        ),
      ],
    );
  }
}

class _FanBudgetCard extends StatelessWidget {
  const _FanBudgetCard({required this.data, required this.onDone});

  final _ShopBundle data;
  final Future<void> Function() onDone;

  Future<void> _appeal(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ArenaApi.instance.appealToFans();
      messenger.showSnackBar(
          const SnackBar(content: Text('The fans answered your call.')));
      await onDone();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Fan budget',
      trailing: Text('Board ${data.boardApproval.round()}/100',
          style: const TextStyle(fontSize: 11, color: AC.textFaint)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.canAppeal
                ? 'Your supporters can fund one emergency transfer per season.'
                : 'You have already used the fan appeal this season.',
            style: const TextStyle(fontSize: 13, color: AC.textDim),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AC.teal,
              foregroundColor: const Color(0xFF04211B),
            ),
            onPressed: data.canAppeal ? () => _appeal(context) : null,
            child: const Text('Ask the fans for help'),
          ),
        ],
      ),
    );
  }
}

class _EarnCard extends StatelessWidget {
  const _EarnCard({required this.available, required this.onDone});

  final bool available;
  final Future<void> Function() onDone;

  Future<void> _claim(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ArenaApi.instance.dailyChest();
      messenger.showSnackBar(
          const SnackBar(content: Text('Daily chest claimed.')));
      await onDone();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AC.radius),
        border: Border.all(color: AC.teal.withValues(alpha: .35)),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF0B2A24), AC.surface],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AC.teal.withValues(alpha: .16),
            ),
            child: const Icon(Icons.redeem_rounded, color: AC.teal, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Earn Vineros for free',
                    style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                    available
                        ? 'Your daily chest is ready to claim.'
                        : 'Come back tomorrow for the next chest.',
                    style: const TextStyle(fontSize: 12, color: AC.textDim)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AC.teal,
              foregroundColor: const Color(0xFF04211B),
              minimumSize: const Size(74, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            onPressed: available ? () => _claim(context) : null,
            child: const Text('CLAIM'),
          ),
        ],
      ),
    );
  }
}

class _TopUpPlaceholder extends StatelessWidget {
  const _TopUpPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SectionCard(
      title: 'Top up',
      child: EmptyState(
        icon: Icons.shopping_bag_rounded,
        title: 'Coming soon',
        subtitle:
            'Vinero packs will be available through Google Play Billing in a future update.',
      ),
    );
  }
}

class _CoinsInfoCard extends StatelessWidget {
  const _CoinsInfoCard();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'About Vineros',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vineros are an in-game currency with no real-world value. They '
            'cannot be exchanged for money and are earned by playing.',
            style: TextStyle(fontSize: 13, height: 1.45, color: AC.textDim),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => launchUrl(
              Uri.parse('https://vinero.app/legal/coins.html'),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 17),
            label: const Text('Read the currency policy'),
          ),
        ],
      ),
    );
  }
}
