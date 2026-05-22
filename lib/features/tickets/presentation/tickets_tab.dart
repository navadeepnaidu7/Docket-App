import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'wallet_ticket_card.dart';

class TicketsTab extends StatefulWidget {
  const TicketsTab({super.key});

  @override
  State<TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends State<TicketsTab> {
  int _filterIndex = 0; // 0 = Active, 1 = Expired

  @override
  Widget build(BuildContext context) {
    final filtered = mockTickets
        .where((t) => _filterIndex == 0
            ? t.status == TicketStatus.active
            : t.status == TicketStatus.expired)
        .toList();

    return Column(
      children: [
        // ── Active / Expired filter ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Row(
            children: [
              _FilterChip(
                label: 'Active',
                selected: _filterIndex == 0,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _filterIndex = 0);
                },
              ),
              const SizedBox(width: 10),
              _FilterChip(
                label: 'Expired',
                selected: _filterIndex == 1,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _filterIndex = 1);
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Ticket cards ─────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.confirmation_number_outlined,
                          color: Colors.grey.shade400, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _filterIndex == 0
                            ? 'No active tickets'
                            : 'No expired tickets',
                        style: const TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              : PageView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      child: Center(
                        child: WalletTicketCard(ticket: filtered[index]),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1C1C1E)
              : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF1C1C1E) : Colors.white,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF8E8E93),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
