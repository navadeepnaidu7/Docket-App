import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../domain/card_number.dart';
import '../domain/card_surface.dart';

const String _visaSvg =
    '<svg viewBox="0 7.55 24 8.7" xmlns="http://www.w3.org/2000/svg">'
    '<path fill="currentColor" d="M9.112 8.262L5.97 15.758H3.92L2.374 9.775c-.094-.368-.175-.503-.461-.658C1.447 8.864.677 8.627 0 8.479l.046-.217h3.3a.904.904 0 01.894.764l.817 4.338 2.018-5.102zm8.033 5.049c.008-1.979-2.736-2.088-2.717-2.972.006-.269.262-.555.822-.628a3.66 3.66 0 011.913.336l.34-1.59a5.207 5.207 0 00-1.814-.333c-1.917 0-3.266 1.02-3.278 2.479-.012 1.079.963 1.68 1.698 2.04.756.367 1.01.603 1.006.931-.005.504-.602.725-1.16.734-.975.015-1.54-.263-1.992-.473l-.351 1.642c.453.208 1.289.39 2.156.398 2.037 0 3.37-1.006 3.377-2.564m5.061 2.447H24l-1.565-7.496h-1.656a.883.883 0 00-.826.55l-2.909 6.946h2.036l.405-1.12h2.488zm-2.163-2.656l1.02-2.815.588 2.815zm-8.16-4.84l-1.603 7.496H8.34l1.605-7.496z"/>'
    '</svg>';

const String _mastercardSvg =
    '<svg viewBox="0 0 38 24" xmlns="http://www.w3.org/2000/svg">'
    '<circle cx="13" cy="12" r="10" fill="#EB001B"/>'
    '<circle cx="25" cy="12" r="10" fill="#F79E1B"/>'
    '<path fill="#FF5F00" d="M19 4A10 10 0 0 1 19 20A10 10 0 0 1 19 4Z"/>'
    '</svg>';

const String _rupaySvg =
    '<svg viewBox="0 0 71.867 18.905" xmlns="http://www.w3.org/2000/svg">'
    '<g transform="matrix(0.35277777,0,0,-0.35277777,67.797845,1.4031532)"><path fill="#008C44" d="m 0,0 11.488,-22.811 -24.15,-22.822 z"/></g>'
    '<g transform="matrix(0.35277777,0,0,-0.35277777,64.991459,1.4031532)"><path fill="#F47920" d="M 0,0 11.471,-22.811 -12.663,-45.633 Z"/></g>'
    '<g transform="matrix(0.35277777,0,0,-0.35277777,0.01611121,14.573442)"><path fill="currentColor" d="m 0,0 11.454,41.266 h 18.312 c 5.723,0 9.546,-0.906 11.491,-2.773 1.931,-1.852 2.303,-4.875 1.139,-9.124 -0.704,-2.503 -1.774,-4.604 -3.244,-6.264 -1.458,-1.663 -3.381,-2.978 -5.749,-3.945 2.009,-0.483 3.287,-1.442 3.86,-2.88 0.57,-1.438 0.504,-3.535 -0.188,-6.284 L 35.682,4.232 35.678,4.076 C 35.276,2.462 35.395,1.598 36.05,1.528 L 35.628,0 H 23.24 c 0.042,0.971 0.119,1.839 0.201,2.568 0.09,0.746 0.201,1.324 0.311,1.721 l 1.155,4.121 c 0.582,2.143 0.618,3.638 0.078,4.499 -0.545,0.884 -1.765,1.319 -3.691,1.319 H 16.088 L 12.118,0 Z m 18.664,23.527 h 5.576 c 1.954,0 3.396,0.279 4.285,0.856 0.893,0.582 1.556,1.565 1.945,2.987 0.403,1.446 0.304,2.454 -0.274,3.027 -0.577,0.582 -1.958,0.865 -4.129,0.865 h -5.256 z"/></g>'
    '<g transform="matrix(0.35277777,0,0,-0.35277777,26.966392,3.8309332)"><path fill="currentColor" d="m 0,0 -8.444,-30.451 h -10.261 l 1.261,4.461 c -1.806,-1.774 -3.654,-3.121 -5.517,-3.982 -1.848,-0.876 -3.798,-1.307 -5.851,-1.307 -1.697,0 -3.154,0.308 -4.327,0.919 -1.187,0.609 -2.071,1.535 -2.666,2.756 -0.528,1.069 -0.758,2.389 -0.668,3.966 0.095,1.552 0.643,4.17 1.659,7.836 L -30.438,0 h 11.224 l -4.367,-15.728 c -0.638,-2.302 -0.79,-3.92 -0.479,-4.801 0.324,-0.889 1.189,-1.348 2.593,-1.348 1.414,0 2.603,0.512 3.585,1.557 0.996,1.036 1.765,2.581 2.343,4.637 L -11.208,0 Z"/></g>'
    '<g transform="matrix(0.35277777,0,0,-0.35277777,25.52981,14.573442)"><path fill="currentColor" d="m 0,0 11.442,41.266 h 15.74 c 3.473,0 6.161,-0.205 8.078,-0.655 1.913,-0.431 3.413,-1.131 4.528,-2.118 1.397,-1.291 2.253,-2.889 2.605,-4.806 0.331,-1.917 0.135,-4.15 -0.59,-6.772 C 40.521,22.302 38.274,18.767 35.072,16.297 31.86,13.859 27.886,12.634 23.143,12.634 H 15.777 L 12.278,0 Z m 18.566,22.712 h 3.958 c 2.559,0 4.358,0.316 5.412,0.926 1.02,0.618 1.745,1.716 2.187,3.277 0.442,1.582 0.328,2.688 -0.34,3.306 -0.643,0.615 -2.286,0.926 -4.915,0.926 h -3.95 z"/></g>'
    '<g transform="matrix(0.35277777,0,0,-0.35277777,44.934987,14.573442)"><path fill="currentColor" d="m 0,0 0.114,2.892 c -1.81,-1.355 -3.643,-2.379 -5.486,-3.019 -1.835,-0.652 -3.789,-0.983 -5.882,-0.983 -3.179,0 -5.396,0.864 -6.678,2.536 -1.266,1.675 -1.474,4.08 -0.61,7.148 0.827,3.028 2.298,5.257 4.42,6.682 2.11,1.442 5.634,2.474 10.578,3.134 0.627,0.102 1.467,0.184 2.519,0.311 3.655,0.423 5.707,1.397 6.149,2.986 0.23,0.87 0.09,1.512 -0.45,1.906 -0.521,0.409 -1.495,0.61 -2.901,0.61 -1.167,0 -2.106,-0.242 -2.876,-0.745 -0.769,-0.508 -1.343,-1.25 -1.732,-2.294 h -10.943 c 0.988,3.428 3.007,6.018 6.038,7.75 3.02,1.762 7.002,2.61 11.934,2.61 2.319,0 4.396,-0.217 6.232,-0.688 1.839,-0.451 3.183,-1.094 4.055,-1.872 1.073,-0.971 1.708,-2.078 1.889,-3.302 0.209,-1.221 -0.02,-2.971 -0.66,-5.261 L 11.003,3.424 C 10.852,2.868 10.823,2.372 10.905,1.921 11.003,1.491 11.191,1.123 11.523,0.86 L 11.27,0 Z M 2.728,13.597 C 1.536,13.118 -0.013,12.659 -1.938,12.155 -4.961,11.344 -6.662,10.262 -7.03,8.923 -7.285,8.062 -7.182,7.399 -6.761,6.895 c 0.415,-0.479 1.136,-0.721 2.152,-0.721 1.863,0 3.359,0.471 4.474,1.401 1.118,0.942 1.954,2.421 2.539,4.461 0.102,0.434 0.192,0.746 0.25,0.979 z"/></g>'
    '<g transform="matrix(0.35277777,0,0,-0.35277777,48.940953,18.806421)"><path fill="currentColor" d="m 0,0 2.491,9.013 h 3.212 c 1.073,0 1.917,0.212 2.515,0.598 0.607,0.401 1.02,1.077 1.258,1.987 0.119,0.401 0.192,0.823 0.242,1.302 0.032,0.508 0.032,1.045 0,1.667 L 8.004,42.45 H 19.365 L 19.189,23.974 29.107,42.45 H 39.672 L 22.138,12.146 C 20.148,8.759 18.702,6.432 17.784,5.162 16.878,3.908 16.018,2.933 15.183,2.273 14.101,1.36 12.893,0.713 11.589,0.336 10.282,-0.049 8.292,-0.241 5.617,-0.241 c -0.77,0 -1.656,0.015 -2.614,0.065 C 2.052,-0.139 1.037,-0.082 0,0"/></g>'
    '</svg>';

/// The network stamp on the card face and in its number field.
class NetworkMark extends StatelessWidget {
  const NetworkMark({super.key, required this.network, required this.surface});

  final CardNetwork? network;
  final CardSurfaceStyle surface;

  static Future<void> warmUp(
    CardNetwork? mark,
    CardSurfaceStyle surface,
  ) async {
    if (mark == null) return;
    final BytesLoader loader;
    if ([
      CardNetwork.amex,
      CardNetwork.discover,
      CardNetwork.unionpay,
      CardNetwork.jcb,
      CardNetwork.diners,
    ].contains(mark)) {
      loader = SvgAssetLoader('assets/wallet/networks/${mark.name}.svg');
    } else {
      final source = switch (mark) {
        CardNetwork.visa => _visaSvg,
        CardNetwork.mastercard => _mastercardSvg,
        _ =>
          surface.light
              ? _rupaySvg
              : _rupaySvg.replaceFirst('#008C44', '#1FAE5A'),
      };
      final ink = mark == CardNetwork.visa
          ? (surface.light ? const Color(0xFF1434CB) : Colors.white)
          : surface.ink;
      loader = SvgStringLoader(source, theme: SvgTheme(currentColor: ink));
    }
    await svg.cache.putIfAbsent(
      loader.cacheKey(null),
      () => loader.loadBytes(null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CardNetwork? mark = network;
    if (mark == null) return const SizedBox(width: 18, height: 18);
    if (mark == CardNetwork.amex ||
        mark == CardNetwork.discover ||
        mark == CardNetwork.unionpay ||
        mark == CardNetwork.jcb ||
        mark == CardNetwork.diners) {
      final logo = SvgPicture.asset(
        'assets/wallet/networks/${mark.name}.svg',
        width: 68,
        height: 30,
        fit: BoxFit.contain,
        colorFilter:
            (mark == CardNetwork.amex || mark == CardNetwork.discover) &&
                !surface.light
            ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
            : null,
        semanticsLabel: mark.label,
      );
      // Under loose row constraints the SVG sizes itself from its height,
      // making Discover's wide wordmark spill past the intended stamp width.
      // A tight box keeps just this mark at the other networks' optical scale.
      return mark == CardNetwork.discover
          ? SizedBox(width: 68, height: 18, child: logo)
          : logo;
    }
    final Color visa = surface.light ? const Color(0xFF1434CB) : Colors.white;
    final Color ruPayWord = surface.ink;
    final String svg = switch (mark) {
      CardNetwork.visa => _visaSvg,
      CardNetwork.mastercard => _mastercardSvg,
      CardNetwork.rupay =>
        surface.light
            ? _rupaySvg
            : _rupaySvg.replaceFirst('#008C44', '#1FAE5A'),
      _ => '',
    };
    final double height = switch (mark) {
      CardNetwork.visa => 18,
      CardNetwork.mastercard => 26,
      CardNetwork.rupay => 20,
      _ => 30,
    };
    final double width = switch (mark) {
      CardNetwork.visa => 50,
      CardNetwork.mastercard => 40,
      CardNetwork.rupay => 76,
      _ => 68,
    };
    final Color ink = switch (mark) {
      CardNetwork.visa => visa,
      CardNetwork.mastercard => surface.ink,
      CardNetwork.rupay => ruPayWord,
      _ => surface.ink,
    };
    return SvgPicture.string(
      svg,
      width: width,
      height: height,
      theme: SvgTheme(currentColor: ink),
      semanticsLabel: mark.label,
    );
  }
}
