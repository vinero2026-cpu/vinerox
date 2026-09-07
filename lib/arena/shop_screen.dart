import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'theme.dart';
import 'widgets.dart';

/// SHOP — spends in-game currency only.
///
/// Google Play requires Play Billing for any purchase of virtual currency, so
/// real-money top-up packs are gated behind [kRealMoneyTopUpsEnabled] and stay
/// off on Android until Play Billing is integrated.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late Future<_ShopBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ShopBundle> _load() async {
    final api = ArenaApi.instance;
    final results = await Future.wait([
      api.balances().catchError((_) => <String, dynamic>{}),
      api.blitzCatalog().catchError((_) => <String, dynamic>{}),
      api.chests().catchError((_) => <String, dynamic>{}),
    ]);
    return _ShopBundle(
        wallet: results[0], catalog: results[1], chests: results[2]);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  Future<void> _buy(String cardId, String name) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ArenaApi.instance.blitzBuyCard(cardId);
      messenger.showSnackBar(SnackBar(content: Text('$name added to your deck.')));
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
            _EarnCard(onDone: _refresh),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Card shop',
              trailing: const Text('Paid with Vineros',
                  style: TextStyle(fontSize: 11, color: AC.textFaint)),
              child: data.cards.isEmpty
                  ? const EmptyState(
                      icon: Icons.style_rounded,
                      title: 'Shop is restocking',
                      subtitle: 'New cards arrive with every market session.',
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < data.cards.length; i++) ...[
                          if (i > 0) const Divider(height: 20),
                          _CardRow(
                            card: data.cards[i],
                            balance: data.vineros,
                            onBuy: _buy,
                          ),
                        ],
                      ],
                    ),
            ),
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
      {required this.wallet, required this.catalog, required this.chests});

  final Map<String, dynamic> wallet;
  final Map<String, dynamic> catalog;
  final Map<String, dynamic> chests;

  int get vineros => wallet.intOr('vcoin', wallet.intOr('vineros', 0));
  int get vpoints => wallet.intOr('vpoints', wallet.intOr('points', 0));

  List<Map<String, dynamic>> get cards {
    final direct = catalog.rows('cards');
    if (direct.isNotEmpty) return direct;
    return catalog.rows('catalog');
  }
}

class _WalletBar extends StatelessWidget {
  const _WalletBar({required this.wallet});
  final Map<String, dynamic> wallet;

  @override
  Widget build(BuildContext context) {
    final vineros = wallet.intOr('vcoin', wallet.intOr('vineros', 0));
    final vpoints = wallet.intOr('vpoints', wallet.intOr('points', 0));
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
      ],
    );
  }
}

class _EarnCard extends StatelessWidget {
  const _EarnCard({required this.onDone});
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Earn Vineros for free',
                    style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text('Daily chest, duel wins and derby rewards.',
                    style: TextStyle(fontSize: 12, color: AC.textDim)),
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
            onPressed: () => _claim(context),
            child: const Text('CLAIM'),
          ),
        ],
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.card,
    required this.balance,
    required this.onBuy,
  });

  final Map<String, dynamic> card;
  final int balance;
  final Future<void> Function(String id, String name) onBuy;

  @override
  Widget build(BuildContext context) {
    final id = card.str('id', card.str('card_id'));
    final name = card.str('name', card.str('title', 'Card'));
    final rarity = card.str('rarity', 'COMMON');
    final price = card.intOr('price', card.intOr('cost', 0));
    final owned = card['owned'] == true;
    final affordable = balance >= price;
    final rarityColor = AC.tier(rarity);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: rarityColor.withValues(alpha: .15),
            border: Border.all(color: rarityColor.withValues(alpha: .4)),
          ),
          child: Icon(Icons.style_rounded, size: 19, color: rarityColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(rarity.toUpperCase(),
                  style: TextStyle(
                      fontSize: 10,
                      letterSpacing: .8,
                      fontWeight: FontWeight.w800,
                      color: rarityColor)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (owned)
          const Text('OWNED',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: AC.textFaint))
        else
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(76, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              backgroundColor: affordable ? AC.gold : AC.surfaceHi,
              foregroundColor:
                  affordable ? const Color(0xFF1A1206) : AC.textFaint,
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            onPressed: affordable && id.isNotEmpty ? () => onBuy(id, name) : null,
            child: Text('$price'),
          ),
      ],
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
