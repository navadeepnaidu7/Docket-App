import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;

enum PassAddIcon { train, bus, flight, movie, event, more, pnr, photo, pdf }

/// App-icon framing with continuous corners and optically sized vector symbols.
/// Labels and interaction semantics belong to the surrounding tile.
class PassAddArt extends StatelessWidget {
  const PassAddArt(this.kind, {super.key});

  final PassAddIcon kind;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final style = _style(kind);
    final colors = dark
        ? const [Color(0xFF303239), Color(0xFF191B20)]
        : [style.top, style.bottom];
    final ink = dark
        ? style.top
        : kind == PassAddIcon.photo
        ? const Color(0xFF343A43)
        : const Color(0xFFFFFFFF);

    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.maxWidth;
          return SizedBox.square(
            dimension: side,
            child: ClipRSuperellipse(
              borderRadius: BorderRadius.circular(side * 0.285),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: colors,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          stops: const [0, 0.5, 1],
                          colors: [
                            const Color(
                              0xFFFFFFFF,
                            ).withValues(alpha: dark ? 0.06 : 0.10),
                            const Color(0x00FFFFFF),
                            const Color(0x00000000),
                          ],
                        ),
                      ),
                    ),
                    Center(
                      child: kind == PassAddIcon.bus
                          ? SizedBox.square(
                              dimension: side * 0.60,
                              child: CustomPaint(painter: _BusSymbol(ink)),
                            )
                          : Icon(
                              style.symbol,
                              size: side * style.scale,
                              color: ink,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

typedef _IconStyle = ({Color top, Color bottom, IconData symbol, double scale});

_IconStyle _style(PassAddIcon kind) => switch (kind) {
  PassAddIcon.train => (
    top: const Color(0xFF51B5FF),
    bottom: const Color(0xFF0874EC),
    symbol: CupertinoIcons.tram_fill,
    scale: 0.54,
  ),
  PassAddIcon.bus => (
    top: const Color(0xFF50DE98),
    bottom: const Color(0xFF13AE6C),
    symbol: CupertinoIcons.bus,
    scale: 0.60,
  ),
  PassAddIcon.flight => (
    top: const Color(0xFF70D7FF),
    bottom: const Color(0xFF2197E9),
    symbol: CupertinoIcons.airplane,
    scale: 0.58,
  ),
  PassAddIcon.movie => (
    top: const Color(0xFFBF91FF),
    bottom: const Color(0xFF8056DE),
    symbol: CupertinoIcons.film_fill,
    scale: 0.54,
  ),
  PassAddIcon.event => (
    top: const Color(0xFFFFAD6E),
    bottom: const Color(0xFFF87549),
    symbol: CupertinoIcons.ticket_fill,
    scale: 0.58,
  ),
  PassAddIcon.more => (
    top: const Color(0xFF9AA9BE),
    bottom: const Color(0xFF627089),
    symbol: CupertinoIcons.rectangle_stack_fill,
    scale: 0.55,
  ),
  PassAddIcon.pnr => (
    top: const Color(0xFF98A9FF),
    bottom: const Color(0xFF6279EC),
    symbol: CupertinoIcons.number,
    scale: 0.53,
  ),
  PassAddIcon.photo => (
    top: const Color(0xFFE5ECF5),
    bottom: const Color(0xFFBAC8DA),
    symbol: CupertinoIcons.camera_fill,
    scale: 0.57,
  ),
  PassAddIcon.pdf => (
    top: const Color(0xFFFFCF6B),
    bottom: const Color(0xFFFFA43A),
    symbol: CupertinoIcons.doc_text_fill,
    scale: 0.54,
  ),
};

/// A front-facing filled bus, drawn on the same 24-unit grid as the glyphs.
class _BusSymbol extends CustomPainter {
  const _BusSymbol(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final body = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(5, 2, 14, 18),
          const Radius.circular(3),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(2, 6, 2, 7),
          const Radius.circular(0.8),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(20, 6, 2, 7),
          const Radius.circular(0.8),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(7, 18, 3, 4),
          const Radius.circular(0.9),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(14, 18, 3, 4),
          const Radius.circular(0.9),
        ),
      );
    final cutouts = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(7, 5, 10, 7),
          const Radius.circular(1.5),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(9, 3.4, 6, 0.7),
          const Radius.circular(0.3),
        ),
      )
      ..addOval(Rect.fromCircle(center: const Offset(8.5, 16), radius: 1))
      ..addOval(Rect.fromCircle(center: const Offset(15.5, 16), radius: 1));
    canvas.drawPath(
      Path.combine(PathOperation.difference, body, cutouts),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_BusSymbol oldDelegate) => oldDelegate.color != color;
}
