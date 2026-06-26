import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/onboarding_content.dart';

class TextCarousel extends StatefulWidget {
  const TextCarousel({super.key, required this.items});

  final List<CarouselItem> items;

  @override
  State<TextCarousel> createState() => _TextCarouselState();
}

class _TextCarouselState extends State<TextCarousel>
    with SingleTickerProviderStateMixin {
  static const int _visibleCount = 5;
  static const double _rowHeight = 62.0;

  late final AnimationController _slideController;
  late final Animation<double> _slideAnimation;

  late List<CarouselItem> _window;
  int _sourceIndex = 0;
  int _currentHighlightIndex = 3; // Starts at index 3 relative to _window (corresponds to middle visible item)
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Initialize _window of size 6 (indices 0 to 5)
    _window = List<CarouselItem>.generate(
      _visibleCount + 1,
      (int i) {
        final int index = (i - 1) % widget.items.length;
        return widget.items[index < 0 ? index + widget.items.length : index];
      },
    );
    
    // The next item to slide in from the top should be items[_sourceIndex]
    _sourceIndex = (widget.items.length - 2) % widget.items.length;
    if (_sourceIndex < 0) _sourceIndex += widget.items.length;

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // smooth scroll speed
    );
    
    _slideAnimation = Tween<double>(
      begin: -_rowHeight,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOutCubic,
    ));

    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;

    // Start sliding down and shift highlighted index to 2 (corresponds to middle item as it slides down)
    setState(() {
      _currentHighlightIndex = 2;
    });

    _slideController.forward(from: 0.0).then((_) {
      if (!mounted) return;
      setState(() {
        // Shift items
        _window.removeLast();
        _window.insert(0, widget.items[_sourceIndex]);
        _sourceIndex = (_sourceIndex - 1 + widget.items.length) % widget.items.length;

        // Reset positions
        _currentHighlightIndex = 3;
        _slideController.value = 0.0;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double visibleHeight = _rowHeight * _visibleCount;
    const double totalHeight = _rowHeight * (_visibleCount + 1); // 324.0

    return IntrinsicWidth(
      child: SizedBox(
        height: visibleHeight,
        child: ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.transparent,
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
                Colors.transparent,
              ],
              // 0.0 to 0.20 (index 0) is fully transparent
              // 0.20 to 0.40 (index 1) fades in from transparent to black
              // 0.40 to 0.60 (index 2) is fully black (highlighted)
              // 0.60 to 0.80 (index 3) fades out from black to transparent
              // 0.80 to 1.0 (index 4) is fully transparent
              stops: <double>[0.0, 0.20, 0.40, 0.60, 0.80, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _slideAnimation,
              builder: (BuildContext context, Widget? child) {
                return Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: OverflowBox(
                    minHeight: totalHeight,
                    maxHeight: totalHeight,
                    alignment: Alignment.topLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List<Widget>.generate(_window.length, (int index) {
                        final bool highlighted = index == _currentHighlightIndex;
                        final CarouselItem item = _window[index];
                        return SizedBox(
                          height: _rowHeight,
                          child: _CarouselRow(
                            key: ValueKey<String>('${item.label}-$index'),
                            item: item,
                            highlighted: highlighted,
                          ),
                        );
                      }),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CarouselRow extends StatelessWidget {
  const _CarouselRow({
    super.key,
    required this.item,
    required this.highlighted,
  });

  final CarouselItem item;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        // Smoothly animate the width and opacity of the icon + spacer so that only the highlighted item displays the icon
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          width: highlighted ? 38 : 0,
          child: AnimatedOpacity(
            opacity: highlighted ? 1 : 0,
            duration: const Duration(milliseconds: 280),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: [
                  Icon(item.icon, color: const Color(0xFF007AFF), size: 28),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
        ),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            color: highlighted
                ? Colors.black
                : Colors.black.withValues(alpha: 0.18),
            fontSize: highlighted ? 38 : 26,
            fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: -0.6,
          ),
          child: Text(item.label),
        ),
      ],
    );
  }
}