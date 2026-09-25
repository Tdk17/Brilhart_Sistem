import 'package:flutter/material.dart';

class BrilhartLogo extends StatelessWidget {
  const BrilhartLogo({
    super.key,
    this.height = 72,
    this.width,
    this.fit = BoxFit.contain,
  });

  final double height;
  final double? width;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/brilhart_logo.png',
      height: height,
      width: width,
      fit: fit,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => SizedBox(
        height: height,
        width: width,
        child: const Center(
          child: Icon(
            Icons.format_paint_outlined,
            color: Color(0xFFD4AF37),
            size: 36,
          ),
        ),
      ),
    );
  }
}
