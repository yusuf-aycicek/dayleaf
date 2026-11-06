import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';

/// Yusuf Ayçiçek's personal mark: a black rounded square with a white
/// terminal prompt ">ya" and a blinking cursor. Strictly black and white,
/// drawn in code (no image file). It is a fixed-size mark, so it ignores
/// the system text scale, and the cursor stops blinking when the system
/// asks for reduced motion.
class YaLogo extends StatefulWidget {
  const YaLogo({super.key, this.size = 40});

  final double size;

  @override
  State<YaLogo> createState() => _YaLogoState();
}

class _YaLogoState extends State<YaLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1060),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _blink.stop();
      _blink.value = 0;
    } else if (!_blink.isAnimating) {
      _blink.repeat();
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Semantics(
      label: AppLocalizations.of(context).logoLabel,
      image: true,
      child: ExcludeSemantics(
        child: Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(s * 0.24),
            // Keeps the black square visible on a dark background.
            border: Border.all(color: Colors.white24, width: s * 0.02),
          ),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: s * 0.1),
          // Never overflows the square, whatever font is available.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '>ya',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontVariations: const [FontVariation('wght', 700)],
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: s * 0.3,
                    height: 1,
                    letterSpacing: -s * 0.01,
                  ),
                ),
                SizedBox(width: s * 0.03),
                AnimatedBuilder(
                  animation: _blink,
                  // On for the first half of each period, off for the second.
                  builder: (context, child) => Opacity(
                    opacity: _blink.value < 0.5 ? 1 : 0,
                    child: child,
                  ),
                  child: Container(
                    width: s * 0.1,
                    height: s * 0.32,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
