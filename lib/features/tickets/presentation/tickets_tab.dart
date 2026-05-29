import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'wallet_ticket_card.dart';

class TicketsTab extends StatefulWidget {
  const TicketsTab({super.key});

  @override
  State<TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends State<TicketsTab> {
  int _filterIndex = 0;
  late PageController _pageCtrl;
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

  void _onScroll() => setState(() => _page = _pageCtrl.page ?? 0);

  List<MockTicket> get _filtered => mockTickets
      .where((t) => _filterIndex == 0
          ? t.status == TicketStatus.active
          : t.status == TicketStatus.expired)
      .toList();

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final double fabClearance =
        MediaQuery.of(context).padding.bottom + 16 + 58 + 20;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Filter pills ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              _FilterPill(
                label: 'Active',
                selected: _filterIndex == 0,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _filterIndex = 0;
                    _page = 0;
                    _pageCtrl.jumpToPage(0);
                  });
                },
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: 'Expired',
                selected: _filterIndex == 1,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _filterIndex = 1;
                    _page = 0;
                    _pageCtrl.jumpToPage(0);
                  });
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Cards + dot indicator ────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? _EmptyState(isActive: _filterIndex == 0)
              : Stack(
                  children: [
                    PageView.builder(
                      controller: _pageCtrl,
                      scrollDirection: Axis.vertical,
                      physics: const BouncingScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final double delta = (_page - index).clamp(-1.0, 1.0);
                        return _RollPage(
                          delta: delta,
                          padding: EdgeInsets.fromLTRB(20, 0, 44, fabClearance),
                          child: WalletTicketCard(ticket: filtered[index]),
                        );
                      },
                    ),
                    // Right-side dot indicator
                    if (filtered.length > 1)
                      Positioned(
                        right: 14,
                        top: 0,
                        bottom: fabClearance,
                        child: Center(
                          child: _DotIndicator(
                            count: filtered.length,
                            page: _page,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ── Roll page transform ───────────────────────────────────────────────────────

class _RollPage extends StatelessWidget {
  const _RollPage({
    required this.delta,
    required this.child,
    required this.padding,
  });

  final double delta;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final double tilt = delta * 0.38;
    final double scale = 1.0 - delta.abs() * 0.08;
    final double translateY = delta * 24;

    final Matrix4 m = Matrix4.identity()
      ..setEntry(3, 2, 0.001)
      ..rotateX(tilt)
      ..scale(scale)
      ..translate(0.0, translateY);

    return Padding(
      padding: padding,
      child: Center(
        child: Transform(
          transform: m,
          alignment: delta < 0 ? Alignment.bottomCenter : Alignment.topCenter,
          child: child,
        ),
      ),
    );
  }
}

// ── Dot indicator ─────────────────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.count, required this.page});
  final int count;
  final double page;

  static const int _dotThreshold = 5;
  static const double _trackH = 48.0;

  @override
  Widget build(BuildContext context) {
    if (count <= _dotThreshold) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (i) {
          final double distance = (page - i).abs().clamp(0.0, 1.0);
          final double size = lerpDouble(10, 6, distance)!;
          final double opacity = lerpDouble(1.0, 0.25, distance)!;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            margin: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E).withValues(alpha: opacity),
              shape: BoxShape.circle,
            ),
          );
        }),
      );
    }

    final double pillH = (_trackH / count).clamp(6.0, _trackH * 0.5);
    final double travel = _trackH - pillH;
    final double offset = (page / (count - 1)).clamp(0.0, 1.0) * travel;

    return SizedBox(
      width: 4,
      height: _trackH,
      child: Stack(
        children: [
          Container(
            width: 4,
            height: _trackH,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            top: offset,
            child: Container(
              width: 4,
              height: pillH,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E).withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter pill ───────────────────────────────────────────────────────────────

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1F3A60) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF1F3A60)
                : Colors.black.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF8E8E93),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.confirmation_number_outlined,
            size: 44,
            color: Colors.black.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 12),
          Text(
            isActive ? 'No active tickets' : 'No expired tickets',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}
