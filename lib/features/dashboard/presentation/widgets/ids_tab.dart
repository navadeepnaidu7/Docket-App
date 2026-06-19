import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

import '../../../../shared/widgets/roll_page_stack.dart';
import '../../../ids/domain/id_document.dart';
import '../../../ids/presentation/wallet_id_card.dart';
import '../../../passport/domain/passport_profile.dart';
import '../wallet_passport_card.dart';
import 'dot_indicator.dart';

class IdsTab extends StatefulWidget {
  const IdsTab({
    super.key,
    required this.passports,
    required this.idDocs,
    required this.onDeletePassport,
    required this.onDeleteId,
    required this.pageNotifier,
  });

  final List<PassportProfile> passports;
  final List<IdDocument> idDocs;
  final void Function(PassportProfile) onDeletePassport;
  final void Function(IdDocument) onDeleteId;
  final ValueNotifier<double> pageNotifier;

  @override
  State<IdsTab> createState() => _IdsTabState();
}

class _IdsTabState extends State<IdsTab> {
  late final PageController _pageCtrl;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _pageCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _pageCtrl.removeListener(_onScroll);
    _pageCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    setState(() => _page = _pageCtrl.page ?? 0);
    widget.pageNotifier.value = _page;
  }

  @override
  Widget build(BuildContext context) {
    final double fabClearance =
        MediaQuery.of(context).padding.bottom + 16 + 58 + 20;
    final items = <Object>[...widget.passports, ...widget.idDocs];
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(32, 0, 32, fabClearance),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EmptyDocsPreview(),
              const SizedBox(height: 28),
              Text(
                'No Documents Yet',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E),
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap + to add a passport or ID card.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF8E8E93) : const Color(0xFF64748B),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        PageView.builder(
          controller: _pageCtrl,
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final double delta = (_page - index).clamp(-1.0, 1.0);
            return RollPageStack(
              delta: delta,
              padding: EdgeInsets.fromLTRB(20, 8, 28, fabClearance),
              child: item is PassportProfile
                  ? WalletPassportCard(
                      profile: item,
                      onLongPress: () => widget.onDeletePassport(item),
                    )
                  : WalletIdCard(
                      document: item as IdDocument,
                      onLongPress: () => widget.onDeleteId(item),
                    ),
            );
          },
        ),
        if (items.length > 1)
          Positioned(
            right: 12,
            top: 0,
            bottom: fabClearance,
            child: Center(
              child: DotIndicator(count: items.length, page: _page),
            ),
          ),
      ],
    );
  }
}

class EmptyDocsPreview extends StatefulWidget {
  const EmptyDocsPreview({super.key});

  @override
  State<EmptyDocsPreview> createState() => _EmptyDocsPreviewState();
}

class _EmptyDocsPreviewState extends State<EmptyDocsPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (context, _) {
        final double shimmerX = lerpDouble(-130, 130, _shimmerCtrl.value)!;
        return SizedBox(
          width: 220,
          height: 164,
          child: Stack(
            alignment: Alignment.center,
            children: [
              GhostDocCard(
                offset: const Offset(-18, 14),
                rotation: -0.13,
                scale: 0.90,
                color: const Color(0xFF2A9D8F),
                shimmerX: shimmerX - 28,
                alpha: 0.48,
              ),
              GhostDocCard(
                offset: const Offset(16, 4),
                rotation: 0.10,
                scale: 0.95,
                color: const Color(0xFF7C5CBF),
                shimmerX: shimmerX + 18,
                alpha: 0.56,
              ),
              GhostDocCard(
                offset: Offset.zero,
                rotation: -0.02,
                scale: 1.0,
                color: const Color(0xFF4C7CFF),
                shimmerX: shimmerX,
                alpha: 0.70,
              ),
            ],
          ),
        );
      },
    );
  }
}

class GhostDocCard extends StatelessWidget {
  const GhostDocCard({
    super.key,
    required this.offset,
    required this.rotation,
    required this.scale,
    required this.color,
    required this.shimmerX,
    required this.alpha,
  });

  final Offset offset;
  final double rotation;
  final double scale;
  final Color color;
  final double shimmerX;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: rotation,
        child: Transform.scale(
          scale: scale,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 168,
              height: 108,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Colors.white.withValues(alpha: 0.52),
                border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.16 * alpha),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withValues(alpha: 0.16 * alpha),
                            Colors.white.withValues(alpha: 0.34),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    top: 20,
                    child: Container(
                      width: 42,
                      height: 30,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18 * alpha),
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                  for (int i = 0; i < 3; i++)
                    Positioned(
                      left: 18,
                      right: 22 + i * 18,
                      bottom: 22 + i * 15,
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.16 * alpha),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  Positioned(
                    left: shimmerX,
                    top: -26,
                    bottom: -26,
                    child: Transform.rotate(
                      angle: -0.45,
                      child: Container(
                        width: 34,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.38 * alpha),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
