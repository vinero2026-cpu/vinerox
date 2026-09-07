import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'theme.dart';

/// Fans / Board style progress meter.
class MeterBar extends StatelessWidget {
  const MeterBar({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.trailing,
  });

  final String label;
  final double value; // 0..1
  final Color color;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final pct = value.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: .6,
                    fontWeight: FontWeight.w700,
                    color: AC.textDim)),
            const Spacer(),
            Text(trailing ?? '${(pct * 100).round()}%',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 7,
              backgroundColor: AC.bgAlt,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }
}

class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AC.textDim;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AC.surface,
        borderRadius: BorderRadius.circular(AC.radiusSm),
        border: Border.all(color: AC.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: c),
            const SizedBox(width: 7),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 9,
                      letterSpacing: .7,
                      fontWeight: FontWeight.w700,
                      color: AC.textFaint)),
              Text(value,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: c)),
            ],
          ),
        ],
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
    this.accent,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsets padding;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: AC.panel(border: accent?.withValues(alpha: .35)),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(title!.toUpperCase(),
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w800,
                          color: accent ?? AC.textDim)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// Club crest. Falls back to initials when the crest asset is unknown.
class CrestBadge extends StatelessWidget {
  const CrestBadge({
    super.key,
    required this.crest,
    required this.fallbackName,
    this.size = 48,
    this.color,
  });

  final String crest;
  final String fallbackName;
  final double size;
  final Color? color;

  static final _known = {for (var i = 1; i <= 50; i++) 'cr${i.toString().padLeft(2, '0')}'};

  @override
  Widget build(BuildContext context) {
    final id = crest.replaceAll('.svg', '');
    final accent = color ?? AC.gold;

    if (_known.contains(id)) {
      return SizedBox(
        width: size,
        height: size,
        child: SvgPicture.asset('assets/crests/$id.svg', fit: BoxFit.contain),
      );
    }

    // The backend also stores crests as raw emoji.
    final isEmoji = crest.isNotEmpty &&
        !RegExp(r'^[\x00-\x7F]+$').hasMatch(crest) &&
        crest.runes.length <= 4;

    final initials = fallbackName
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: .16),
        border: Border.all(color: accent.withValues(alpha: .55), width: 2),
      ),
      child: Text(
        isEmoji ? crest : (initials.isEmpty ? 'SA' : initials),
        style: TextStyle(
          fontFamily: isEmoji ? null : 'Fredoka',
          fontSize: size * (isEmoji ? .48 : .36),
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }
}

/// Loading / error / empty handling in one place so no screen ships a
/// spinner that never resolves.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.future,
    required this.builder,
    this.onRetry,
    this.loadingHeight = 220,
  });

  final Future<T> future;
  final Widget Function(BuildContext, T) builder;
  final VoidCallback? onRetry;
  final double loadingHeight;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: loadingHeight,
            child: const Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          );
        }
        if (snap.hasError) {
          return ErrorTile(
            message: '${snap.error}',
            onRetry: onRetry,
          );
        }
        return builder(context, snap.data as T);
      },
    );
  }
}

class ErrorTile extends StatelessWidget {
  const ErrorTile({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: AC.panel(border: AC.bear.withValues(alpha: .4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_off_rounded, size: 18, color: AC.bear),
              SizedBox(width: 8),
              Text('Could not load',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(color: AC.textDim, fontSize: 13)),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.inbox_rounded,
    this.action,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
      child: Column(
        children: [
          Icon(icon, size: 38, color: AC.textFaint),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AC.textDim, fontSize: 13)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
