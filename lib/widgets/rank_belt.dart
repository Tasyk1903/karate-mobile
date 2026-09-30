import 'package:flutter/material.dart';

class RankBelt extends StatelessWidget {
  const RankBelt({
    super.key,
    required this.color,
    required this.stripes,
    this.height = 10,
    this.width,
  });
  final Color color;
  final List<Color> stripes;
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(2),
      border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final stripeWidth =
            ((constraints.maxWidth - 8) /
                    (stripes.isEmpty ? 1 : stripes.length * 1.6))
                .clamp(1.0, 5.0);
        return Stack(
          children: [
            for (var i = 0; i < stripes.length; i++)
              Positioned(
                right: 4 + i * stripeWidth * 1.6,
                top: 0,
                bottom: 0,
                child: ColoredBox(
                  color: stripes[i],
                  child: SizedBox(width: stripeWidth),
                ),
              ),
          ],
        );
      },
    ),
  );
}
