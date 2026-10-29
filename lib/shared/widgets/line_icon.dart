import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A Lucide line glyph from `assets/icons/`, drawn like an [Icon].
///
/// Size and colour fall back to the ambient [IconTheme], so a [LineIcon]
/// dropped into `DocketButton.leading` or an `IconButton` picks up the same
/// tint an `Icon` would. The SVGs stroke with `currentColor`, which the
/// [ColorFilter] replaces wholesale.
class LineIcon extends StatelessWidget {
  const LineIcon(this.asset, {super.key, this.size, this.color});

  final String asset;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final IconThemeData theme = IconTheme.of(context);
    final double s = size ?? theme.size ?? 24;
    final Color c = color ?? theme.color ?? const Color(0xFF000000);

    return ExcludeSemantics(
      child: SvgPicture.asset(
        asset,
        width: s,
        height: s,
        colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
      ),
    );
  }
}
