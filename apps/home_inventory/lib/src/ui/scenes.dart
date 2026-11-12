// Housetally's illustrations, drawn in code so they scale, theme and move.
import 'dart:math' as math;

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

const _gold = Color(0xFFF2B33D);
const _plum = Color(0xFF5D2E46);
const _leaf = Color(0xFF66BB6A);

/// Housetally's mascot: a little house with a face whose windows light up
/// and whose chimney puffs.
void housetally(Canvas c, Offset bottom, double size, SceneFrame f, {double lit = 1, double blink = 0}) {
  if (size <= 1) return;
  c.save();
  c.translate(bottom.dx, bottom.dy);
  c.scale(size / 100);
  final wall = f.dark ? const Color(0xFFF3E3D3) : const Color(0xFFFFF4E6);
  final roof = f.scheme.primary;
  // Chimney and smoke.
  Ink2.rrect(c, const Rect.fromLTWH(18, -98, 14, 30), 3, Ink2.fill(Color.lerp(roof, Colors.black, 0.25)!));
  for (var i = 0; i < 3; i++) {
    final t = (f.loop * 1.5 + i / 3) % 1;
    c.drawCircle(
      Offset(25 + 8 * math.sin(t * 6), -104 - t * 40),
      5 + 6 * t,
      Ink2.fill(f.scheme.outline.withValues(alpha: 0.35 * (1 - t))),
    );
  }
  // Body.
  Ink2.rrect(c, const Rect.fromLTWH(-40, -60, 80, 60), 8, Ink2.fill(wall));
  c.drawPath(
    Path()
      ..moveTo(-50, -56)
      ..lineTo(0, -100)
      ..lineTo(50, -56)
      ..close(),
    Ink2.fill(roof),
  );
  // Window eyes that light up.
  final glow = Color.lerp(const Color(0xFF8D6E63), _gold, lit)!;
  for (final x in [-20.0, 20.0]) {
    final h = 16 * (1 - blink) + 2;
    Ink2.rrect(c, Rect.fromCenter(center: Offset(x, -38), width: 16, height: h), 3, Ink2.fill(glow));
    if (lit > 0.5) Ink2.glow(c, Offset(x, -38), 18, _gold.withValues(alpha: 0.35 * lit));
  }
  // Door smile.
  c.drawArc(
    Rect.fromCenter(center: const Offset(0, -20), width: 22, height: 14),
    0.2,
    math.pi - 0.4,
    false,
    Ink2.stroke(Color.lerp(roof, Colors.black, 0.3)!, 3),
  );
  Ink2.rrect(c, const Rect.fromLTWH(-8, -14, 16, 14), 4, Ink2.fill(Color.lerp(roof, Colors.black, 0.2)!));
  c.restore();
}

double _blink(double loop) {
  final t = (loop * 2) % 1;
  return t > 0.93 ? math.sin((t - 0.93) / 0.07 * math.pi) : 0;
}

/// Tally marks: [n] strokes in groups of five, drawn up to [progress].
void _tally(Canvas c, Offset o, double unit, int n, double progress, Color color) {
  final shown = (n * progress).floor();
  final paint = Ink2.stroke(color, unit * 0.18);
  for (var i = 0; i < shown; i++) {
    final group = i ~/ 5, k = i % 5;
    final gx = o.dx + group * unit * 2.6;
    if (k < 4) {
      c.drawLine(Offset(gx + k * unit * 0.5, o.dy), Offset(gx + k * unit * 0.5, o.dy + unit * 1.4), paint);
    } else {
      c.drawLine(Offset(gx - unit * 0.3, o.dy + unit * 1.1), Offset(gx + unit * 1.8, o.dy + unit * 0.2), paint);
    }
  }
}

void _sofa(Canvas c, Rect r, Color col) {
  Ink2.rrect(
    c,
    Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.6),
    r.height * 0.2,
    Ink2.fill(Color.lerp(col, Colors.black, 0.15)!),
  );
  Ink2.rrect(
    c,
    Rect.fromLTWH(r.left - r.width * 0.06, r.top + r.height * 0.35, r.width * 1.12, r.height * 0.45),
    r.height * 0.15,
    Ink2.fill(col),
  );
  c.drawLine(
    Offset(r.left + r.width * 0.08, r.bottom - r.height * 0.2),
    Offset(r.left + r.width * 0.08, r.bottom),
    Ink2.stroke(Colors.brown.shade800, 3),
  );
  c.drawLine(
    Offset(r.right - r.width * 0.08, r.bottom - r.height * 0.2),
    Offset(r.right - r.width * 0.08, r.bottom),
    Ink2.stroke(Colors.brown.shade800, 3),
  );
}

void _lamp(Canvas c, Offset base, double h, bool on) {
  c.drawLine(base, base.translate(0, -h * 0.8), Ink2.stroke(const Color(0xFF5D4037), 3));
  final shade = Path()
    ..moveTo(base.dx - h * 0.22, base.dy - h * 0.75)
    ..lineTo(base.dx + h * 0.22, base.dy - h * 0.75)
    ..lineTo(base.dx + h * 0.12, base.dy - h)
    ..lineTo(base.dx - h * 0.12, base.dy - h)
    ..close();
  if (on) Ink2.glow(c, base.translate(0, -h * 0.7), h * 0.6, _gold.withValues(alpha: 0.45));
  c.drawPath(shade, Ink2.fill(on ? _gold : const Color(0xFFBCAAA4)));
}

void _plant(Canvas c, Offset base, double h, double sway) {
  Ink2.rrect(
    c,
    Rect.fromCenter(center: base.translate(0, -h * 0.15), width: h * 0.4, height: h * 0.3),
    4,
    Ink2.fill(const Color(0xFFD87C4A)),
  );
  for (var i = -2; i <= 2; i++) {
    final a = -math.pi / 2 + i * 0.35 + sway * 0.08;
    final tip = base.translate(0, -h * 0.3) + Offset(math.cos(a), math.sin(a)) * h * 0.7;
    c.drawLine(base.translate(0, -h * 0.3), tip, Ink2.stroke(_leaf, h * 0.09));
  }
}

void _tv(Canvas c, Rect r, double on, Color tint) {
  Ink2.rrect(c, r, 6, Ink2.fill(const Color(0xFF263238)));
  Ink2.rrect(c, r.deflate(4), 4, Ink2.fill(Color.lerp(const Color(0xFF37474F), tint, on)!));
  c.drawLine(r.bottomCenter, r.bottomCenter.translate(0, 8), Ink2.stroke(const Color(0xFF263238), 3));
}

/// Onboarding 1: a cut-away house fills room by room; each new thing adds a
/// tally mark.
void roomsScene(Canvas c, Size s, SceneFrame f) {
  final w = s.width, h = s.height;
  Ink2.glow(c, Offset(w * 0.5, h * 0.5), w * 0.5, _gold.withValues(alpha: 0.18));
  final build = phase(f.intro, 0, 0.35, Curves.easeOutBack);
  final house = Rect.fromLTWH(w * 0.12, h * 0.34, w * 0.76, h * 0.5);
  final roofPeak = Offset(w * 0.5, h * 0.34 - h * 0.2 * build);
  c.drawPath(
    Path()
      ..moveTo(house.left - w * 0.05, house.top + 4)
      ..lineTo(roofPeak.dx, roofPeak.dy)
      ..lineTo(house.right + w * 0.05, house.top + 4)
      ..close(),
    Ink2.fill(f.scheme.primary),
  );
  final body = Rect.fromLTRB(house.left, house.bottom - house.height * build, house.right, house.bottom);
  Ink2.rrect(c, body, 6, Ink2.fill(f.dark ? const Color(0xFF3E2C28) : const Color(0xFFFFF4E6)));
  if (build < 0.95) return;
  final midX = house.center.dx, midY = house.center.dy;
  final wall = Ink2.stroke(f.scheme.primary.withValues(alpha: 0.5), 3);
  c.drawLine(Offset(midX, house.top), Offset(midX, house.bottom), wall);
  c.drawLine(Offset(house.left, midY), Offset(house.right, midY), wall);
  final rooms = [
    Rect.fromLTRB(house.left, house.top, midX, midY),
    Rect.fromLTRB(midX, house.top, house.right, midY),
    Rect.fromLTRB(house.left, midY, midX, house.bottom),
    Rect.fromLTRB(midX, midY, house.right, house.bottom),
  ];
  final pops = [for (var i = 0; i < 4; i++) phase(f.intro, 0.35 + i * 0.12, 0.55 + i * 0.12, Curves.easeOutBack)];
  // Lights come on behind each room as it fills.
  for (var i = 0; i < 4; i++) {
    if (pops[i] > 0) c.drawRect(rooms[i].deflate(3), Ink2.fill(_gold.withValues(alpha: 0.12 * pops[i])));
  }
  final r0 = rooms[0], r1 = rooms[1], r2 = rooms[2], r3 = rooms[3];
  if (pops[0] > 0) {
    _sofa(
      c,
      Rect.fromCenter(
        center: r0.center.translate(0, r0.height * 0.18),
        width: r0.width * 0.6 * pops[0],
        height: r0.height * 0.4 * pops[0],
      ),
      const Color(0xFF8D6E63),
    );
  }
  if (pops[1] > 0) {
    _tv(
      c,
      Rect.fromCenter(
        center: r1.center.translate(0, -r1.height * 0.05),
        width: r1.width * 0.55 * pops[1],
        height: r1.height * 0.42 * pops[1],
      ),
      0.6 + 0.4 * f.wave().abs(),
      f.scheme.primary,
    );
  }
  if (pops[2] > 0) _lamp(c, Offset(r2.center.dx, r2.bottom - 4), r2.height * 0.75 * pops[2], pops[2] > 0.9);
  if (pops[3] > 0) _plant(c, Offset(r3.center.dx, r3.bottom - 4), r3.height * 0.7 * pops[3], f.wave());
  // Tally board.
  final board = Rect.fromLTWH(w * 0.06, h * 0.06, w * 0.34, h * 0.14);
  final b = phase(f.intro, 0.3, 0.5);
  if (b > 0) {
    Ink2.rrect(c, board, 10, Ink2.fill(f.dark ? f.scheme.surfaceContainerHigh : Colors.white.withValues(alpha: b)));
    _tally(
      c,
      board.topLeft + Offset(board.width * 0.12, board.height * 0.22),
      board.height * 0.45,
      7,
      phase(f.intro, 0.4, 0.95, Curves.linear),
      f.scheme.primary,
    );
  }
  housetally(
    c,
    Offset(w * 0.82, h * 0.22 + 3 * f.wave()),
    w * 0.22 * phase(f.intro, 0.6, 0.9, Curves.easeOutBack),
    f,
    lit: phase(f.intro, 0.8, 1),
    blink: _blink(f.loop),
  );
}

/// Onboarding 2: a receipt prints out under a shield that ticks.
void warrantyScene(Canvas c, Size s, SceneFrame f) {
  final w = s.width, h = s.height;
  final o = Offset(w * 0.56, h * 0.42);
  Ink2.glow(c, o, w * 0.45, f.brand.success.withValues(alpha: 0.18));
  // Receipt.
  final print = phase(f.intro, 0.1, 0.6);
  final rx = w * 0.16, rw = w * 0.32;
  final rh = h * 0.62 * print;
  final top = h * 0.2;
  final receipt = Path()..moveTo(rx, top);
  receipt.lineTo(rx + rw, top);
  receipt.lineTo(rx + rw, top + rh);
  for (var i = 0; i < 6; i++) {
    final x = rx + rw - (i + 0.5) * rw / 6;
    receipt.lineTo(x, top + rh + (i.isEven ? 8 : 0));
  }
  receipt.lineTo(rx, top + rh);
  receipt.close();
  c.drawPath(receipt.shift(const Offset(3, 4)), Ink2.fill(Colors.black.withValues(alpha: 0.1)));
  c.drawPath(receipt, Ink2.fill(f.dark ? const Color(0xFFEDE7E3) : Colors.white));
  for (var i = 0; i < 5; i++) {
    final y = top + 18 + i * h * 0.09;
    if (y > top + rh - 8) break;
    c.drawLine(
      Offset(rx + 12, y),
      Offset(rx + rw - 12 - (i.isOdd ? rw * 0.3 : 0), y),
      Ink2.stroke(const Color(0xFFBCAAA4), 4),
    );
  }
  // Shield.
  final pop = phase(f.intro, 0.35, 0.75, Curves.easeOutBack);
  final r = w * 0.2 * pop;
  if (r > 1) {
    final sc = o.translate(w * 0.06, 3 * f.wave());
    final shield = Path()
      ..moveTo(sc.dx, sc.dy - r)
      ..quadraticBezierTo(sc.dx + r * 0.9, sc.dy - r * 0.85, sc.dx + r * 0.9, sc.dy - r * 0.55)
      ..quadraticBezierTo(sc.dx + r * 0.8, sc.dy + r * 0.6, sc.dx, sc.dy + r)
      ..quadraticBezierTo(sc.dx - r * 0.8, sc.dy + r * 0.6, sc.dx - r * 0.9, sc.dy - r * 0.55)
      ..quadraticBezierTo(sc.dx - r * 0.9, sc.dy - r * 0.85, sc.dx, sc.dy - r)
      ..close();
    c.drawPath(shield, Paint()..shader = f.brand.linear.createShader(Rect.fromCircle(center: sc, radius: r)));
    final tick = Path()
      ..moveTo(sc.dx - r * 0.35, sc.dy)
      ..lineTo(sc.dx - r * 0.08, sc.dy + r * 0.28)
      ..lineTo(sc.dx + r * 0.4, sc.dy - r * 0.25);
    final m = tick.computeMetrics().first;
    c.drawPath(m.extractPath(0, m.length * phase(f.intro, 0.7, 1)), Ink2.stroke(Colors.white, r * 0.14));
  }
  // Countdown ring.
  final ring = phase(f.intro, 0.5, 0.9);
  if (ring > 0) {
    final cc = Offset(w * 0.8, h * 0.78);
    c.drawCircle(cc, w * 0.09, Ink2.fill(f.dark ? f.scheme.surfaceContainerHigh : Colors.white));
    c.drawArc(
      Rect.fromCircle(center: cc, radius: w * 0.07),
      -math.pi / 2,
      2 * math.pi * (0.75 - 0.05 * f.loop) * ring,
      false,
      Ink2.stroke(f.brand.warning, 5),
    );
    c.drawLine(cc, cc.translate(0, -w * 0.045), Ink2.stroke(f.scheme.onSurface, 3));
    c.drawLine(cc, cc.translate(w * 0.03, 0), Ink2.stroke(f.scheme.onSurface, 3));
  }
  paintSparkField(c, s, f, _gold, count: 5, seed: 3);
}

/// Onboarding 3 and paywall: photos fly onto a report that seals itself.
void reportScene(Canvas c, Size s, SceneFrame f) {
  final w = s.width, h = s.height;
  final m = math.min(w, h);
  final o = Offset(w * 0.5, h * 0.52);
  Ink2.glow(c, o, m * 0.55, _gold.withValues(alpha: 0.22));
  final up = phase(f.intro, 0, 0.45, Curves.easeOutBack);
  final doc = Rect.fromCenter(
    center: o.translate(0, (1 - up) * h * 0.4 + 3 * f.wave()),
    width: m * 0.5,
    height: m * 0.66,
  );
  Ink2.rrect(c, doc.shift(const Offset(0, 6)), 14, Ink2.fill(Colors.black.withValues(alpha: 0.12)));
  Ink2.rrect(c, doc, 14, Ink2.fill(f.dark ? f.scheme.surfaceContainerHighest : Colors.white));
  final head = Rect.fromLTWH(doc.left, doc.top, doc.width, doc.height * 0.16);
  c.drawRRect(
    RRect.fromRectAndCorners(head, topLeft: const Radius.circular(14), topRight: const Radius.circular(14)),
    Paint()..shader = f.brand.linear.createShader(head),
  );
  // Photo tiles fly in from the sides.
  final tiles = [const Color(0xFF90CAF9), const Color(0xFFA5D6A7), const Color(0xFFFFCC80), const Color(0xFFCE93D8)];
  final tw = doc.width * 0.36, th = doc.height * 0.2;
  for (var i = 0; i < 4; i++) {
    final t = phase(f.intro, 0.3 + i * 0.1, 0.6 + i * 0.1, Curves.easeOutBack);
    if (t <= 0) continue;
    final target = Offset(doc.left + doc.width * (i.isEven ? 0.27 : 0.73), doc.top + doc.height * (i < 2 ? 0.34 : 0.6));
    final from = Offset(i.isEven ? -w * 0.2 : w * 1.2, target.dy - h * 0.2);
    final p = Offset.lerp(from, target, t)!;
    final r = Rect.fromCenter(center: p, width: tw, height: th);
    Ink2.rrect(c, r, 6, Ink2.fill(tiles[i]));
    c.drawPath(
      Path()
        ..moveTo(r.left + 4, r.bottom - 4)
        ..lineTo(r.left + r.width * 0.4, r.top + r.height * 0.45)
        ..lineTo(r.left + r.width * 0.6, r.bottom - r.height * 0.3)
        ..lineTo(r.left + r.width * 0.75, r.top + r.height * 0.55)
        ..lineTo(r.right - 4, r.bottom - 4)
        ..close(),
      Ink2.fill(Colors.white.withValues(alpha: 0.6)),
    );
  }
  for (var i = 0; i < 2; i++) {
    final y = doc.top + doc.height * (0.8 + i * 0.08);
    c.drawLine(Offset(doc.left + 14, y), Offset(doc.right - 14 - i * 30, y), Ink2.stroke(f.scheme.outlineVariant, 4));
  }
  // Wax seal.
  final seal = phase(f.intro, 0.8, 1, Curves.elasticOut);
  if (seal > 0) {
    final sc = Offset(doc.right - doc.width * 0.05, doc.bottom - doc.height * 0.05);
    c.drawCircle(sc, m * 0.07 * seal, Ink2.fill(_plum));
    Ink2.sparkle(c, sc, m * 0.04 * seal, _gold);
  }
  housetally(
    c,
    Offset(doc.left - m * 0.08, doc.bottom + 2),
    m * 0.24 * phase(f.intro, 0.55, 0.85, Curves.easeOutBack),
    f,
    lit: 1,
    blink: _blink(f.loop),
  );
  paintSparkField(c, s, f, _gold, count: 7, seed: 10);
}

/// Empty room: an open box with things bouncing out of it.
void openBoxScene(Canvas c, Size s, SceneFrame f) {
  final w = s.width, h = s.height;
  Ink2.glow(c, Offset(w * 0.5, h * 0.6), w * 0.45, _gold.withValues(alpha: 0.2));
  final base = h * 0.84;
  final box = Rect.fromLTRB(w * 0.26, base - h * 0.3, w * 0.74, base);
  final pop = phase(f.intro, 0, 0.4, Curves.easeOutBack);
  Ink2.shadow(c, Offset(w / 2, base + 4), w * 0.55 * pop, Colors.black);
  // Things hopping out in turn.
  final things = [
    (Icons.chair_rounded, const Color(0xFF8D6E63)),
    (Icons.tv_rounded, const Color(0xFF455A64)),
    (Icons.watch_rounded, _gold),
  ];
  final tp = TextPainter(textDirection: TextDirection.ltr);
  for (var i = 0; i < 3; i++) {
    final t = phase(f.intro, 0.35 + i * 0.15, 0.7 + i * 0.1, Curves.easeOutBack);
    final hop = (math.sin((f.loop * 2 + i / 3) * 2 * math.pi) * 0.5 + 0.5) * h * 0.04;
    final p = Offset(w * (0.38 + i * 0.12), box.top - h * 0.12 * t - hop);
    final icon = things[i].$1;
    tp.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: w * 0.13 * t,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: things[i].$2,
      ),
    );
    tp.layout();
    tp.paint(c, p - Offset(tp.width / 2, tp.height / 2));
  }
  final card = Paint()..shader = const LinearGradient(colors: [Color(0xFFD7A86E), Color(0xFFB9824A)]).createShader(box);
  final b = Rect.fromLTRB(box.left, base - box.height * pop, box.right, base);
  Ink2.rrect(c, b, 6, card);
  // Flaps.
  final flap = Ink2.fill(const Color(0xFFC8955A));
  c.drawPath(
    Path()..addPolygon([
      b.topLeft,
      b.topLeft.translate(-w * 0.08, -h * 0.08 * pop),
      b.topLeft.translate(w * 0.12, -h * 0.05 * pop),
      b.topLeft.translate(w * 0.16, 0),
    ], true),
    flap,
  );
  c.drawPath(
    Path()..addPolygon([
      b.topRight,
      b.topRight.translate(w * 0.08, -h * 0.08 * pop),
      b.topRight.translate(-w * 0.12, -h * 0.05 * pop),
      b.topRight.translate(-w * 0.16, 0),
    ], true),
    flap,
  );
  c.drawLine(Offset(b.center.dx, b.top), Offset(b.center.dx, b.bottom), Ink2.stroke(const Color(0xFFE8C9A0), 6));
}

/// Paywall: boxes stack higher and higher next to the mascot.
void stackProScene(Canvas c, Size s, SceneFrame f) {
  final w = s.width, h = s.height;
  Ink2.glow(c, Offset(w * 0.5, h * 0.5), h * 0.7, _gold.withValues(alpha: 0.22));
  final base = h * 0.9;
  final bw = h * 0.22;
  final positions = [
    Offset(w * 0.5 - bw, base),
    Offset(w * 0.5, base),
    Offset(w * 0.5 + bw, base),
    Offset(w * 0.5 - bw / 2, base - bw),
    Offset(w * 0.5 + bw / 2, base - bw),
    Offset(w * 0.5, base - bw * 2),
  ];
  for (var i = 0; i < positions.length; i++) {
    final t = phase(f.intro, i * 0.08, 0.35 + i * 0.08, Curves.bounceOut);
    if (t <= 0) continue;
    final p = Offset.lerp(positions[i].translate(0, -h), positions[i], t)!;
    final r = Rect.fromLTWH(p.dx - bw / 2 + 2, p.dy - bw + 2, bw - 4, bw - 4);
    Ink2.rrect(
      c,
      r,
      5,
      Paint()..shader = const LinearGradient(colors: [Color(0xFFD7A86E), Color(0xFFB9824A)]).createShader(r),
    );
    c.drawLine(
      Offset(r.center.dx, r.top),
      Offset(r.center.dx, r.top + r.height * 0.4),
      Ink2.stroke(const Color(0xFFE8C9A0), 4),
    );
  }
  // An infinity loop of tally marks drawn over the top.
  final inf = phase(f.intro, 0.6, 1);
  if (inf > 0) {
    final cx = w * 0.5, cy = base - bw * 3.1, a = bw * 0.55;
    final path = Path();
    for (var k = 0; k <= 60; k++) {
      final t = k / 60 * 2 * math.pi;
      final d = 1 + math.sin(t) * math.sin(t);
      final p = Offset(cx + a * math.cos(t) / d, cy + a * math.sin(t) * math.cos(t) / d);
      k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    final m = path.computeMetrics().first;
    c.drawPath(m.extractPath(0, m.length * inf), Ink2.stroke(f.scheme.primary, 6));
    final head = m.getTangentForOffset((m.length * (inf * 0.999 + f.loop)) % m.length)!.position;
    c.drawCircle(head, 6, Ink2.fill(_gold));
  }
  housetally(
    c,
    Offset(w * 0.86, base),
    h * 0.4 * phase(f.intro, 0.4, 0.8, Curves.easeOutBack),
    f,
    blink: _blink(f.loop),
  );
  paintSparkField(c, s, f, _gold, count: 7, seed: 14);
}

/// Empty warranties: the mascot under a gently pulsing shield.
void shieldScene(Canvas c, Size s, SceneFrame f) {
  final w = s.width, h = s.height;
  final o = Offset(w / 2, h * 0.45);
  final pulse = 1 + 0.04 * f.wave();
  final r = w * 0.3 * phase(f.intro, 0, 0.5, Curves.easeOutBack) * pulse;
  Ink2.glow(c, o, w * 0.5, f.brand.success.withValues(alpha: 0.18));
  if (r > 1) {
    final shield = Path()
      ..moveTo(o.dx, o.dy - r)
      ..quadraticBezierTo(o.dx + r * 0.9, o.dy - r * 0.85, o.dx + r * 0.9, o.dy - r * 0.55)
      ..quadraticBezierTo(o.dx + r * 0.8, o.dy + r * 0.6, o.dx, o.dy + r)
      ..quadraticBezierTo(o.dx - r * 0.8, o.dy + r * 0.6, o.dx - r * 0.9, o.dy - r * 0.55)
      ..quadraticBezierTo(o.dx - r * 0.9, o.dy - r * 0.85, o.dx, o.dy - r)
      ..close();
    c.drawPath(shield, Ink2.stroke(f.scheme.primary.withValues(alpha: 0.6), 5));
  }
  housetally(
    c,
    Offset(o.dx, o.dy + r * 0.55),
    w * 0.36 * phase(f.intro, 0.3, 0.7, Curves.easeOutBack),
    f,
    lit: phase(f.intro, 0.6, 1),
    blink: _blink(f.loop),
  );
  paintSparkField(c, s, f, _gold, count: 5, seed: 2);
}
