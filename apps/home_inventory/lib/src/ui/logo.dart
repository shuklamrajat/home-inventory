import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

/// House Tag: a house-shaped label on a gold string, tallied. The same
/// artwork as brand/logo.svg. The tag drops onto its nail, then swings.
void housetallyLogo(Canvas c, Size size, SceneFrame f) {
  onLogoGrid(c, size, (c) {
    c.drawRect(
      const Rect.fromLTWH(0, 0, 512, 512),
      Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(512, 512), const [Color(0xFFD06A44), Color(0xFF6B2F4E)]),
    );
    c.drawCircle(const Offset(120, 420), 150, Paint()..color = const Color(0xFFF2B33D).withValues(alpha: .14));

    final intro = f.intro.clamp(0.0, 1.0);
    final drop = (1 - Curves.bounceOut.transform(intro)) * -90;
    // Rests tilted at -6°, swings a little either side of that.
    final swing = -6 + math.sin(f.loop * 2 * 2 * math.pi) * 6 + (1 - intro) * 14;

    c.save();
    c.translate(0, drop);
    // Pivot on the nail, where the string hangs from.
    c.translate(256, 118.2);
    c.rotate(swing * math.pi / 180);
    c.translate(-256, -118.2);
    c.translate(256, 256);
    c.scale(0.84);
    c.translate(-256, -256);

    c.drawPath(
      Path()
        ..moveTo(256, 92)
        ..cubicTo(226, 120, 230, 160, 256, 176),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFF2B33D),
    );
    c.translate(256, 176);
    final tag = Path()
      ..moveTo(0, 0)
      ..lineTo(132, 104)
      ..lineTo(132, 292)
      ..arcToPoint(const Offset(112, 312), radius: const Radius.circular(20))
      ..lineTo(-112, 312)
      ..arcToPoint(const Offset(-132, 292), radius: const Radius.circular(20))
      ..lineTo(-132, 104)
      ..close();
    c.drawPath(tag.shift(const Offset(10, 14)), Paint()..color = const Color(0xFF3A1524).withValues(alpha: .35));
    const paper = Color(0xFFFFF4E0);
    c.drawPath(tag, Paint()..color = paper);
    c.drawPath(
      tag,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeJoin = StrokeJoin.round
        ..color = paper,
    );
    c.drawCircle(const Offset(0, 58), 18, Paint()..color = const Color(0xFFC2573A));
    c.drawCircle(const Offset(0, 58), 9, Paint()..color = const Color(0xFF5D2E46));

    // Tally marks appear one by one, then the strike.
    final marks = Paint()
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFA1452C);
    const xs = <double>[-76, -36, 4, 44];
    for (var i = 0; i < xs.length; i++) {
      final k = ((intro - .35 - i * .1) / .12).clamp(0.0, 1.0);
      if (k > 0) c.drawLine(Offset(xs[i], 150), Offset(xs[i], 150 + 100 * k), marks);
    }
    final s = ((intro - .8) / .2).clamp(0.0, 1.0);
    if (s > 0) {
      c.drawLine(
        const Offset(-96, 236),
        Offset.lerp(const Offset(-96, 236), const Offset(84, 162), s)!,
        marks..color = const Color(0xFFF2B33D),
      );
    }
    c.restore();

    c.save();
    c.translate(256, 256);
    c.scale(0.84);
    c.translate(-256, -256);
    c.drawCircle(const Offset(256, 88), 12, Paint()..color = const Color(0xFFF2B33D));
    c.restore();
  });
}
