import 'package:flutter/material.dart';

import '../api/client.dart';
import '../theme.dart';

class PickDetailScreen extends StatefulWidget {
  const PickDetailScreen({super.key, required this.ticker, required this.api});
  final String ticker;
  final ApiClient api;

  @override
  State<PickDetailScreen> createState() => _PickDetailScreenState();
}

class _PickDetailScreenState extends State<PickDetailScreen> {
  bool _busy = false;

  Future<void> _openTrade() async {
    setState(() => _busy = true);
    try {
      final r = await widget.api.openTrade(widget.ticker);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r['message']?.toString() ?? 'Trade submitted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.ticker)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.ticker,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 32, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Detailed view + chart coming next iteration.',
                style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _openTrade,
                icon: const Icon(Icons.flash_on),
                label: Text(_busy ? 'Submitting...' : 'Quick Buy \$10,000'),
                style: FilledButton.styleFrom(
                  backgroundColor: VineroxTheme.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
