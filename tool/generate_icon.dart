// Run with: dart run tool/generate_icon.dart
// Generates assets/icon/app_icon.png and assets/icon/app_icon_fg.png

import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

const int kSize = 1024;
const int kFgSize = 768; // foreground canvas for adaptive icon (centered on 1024)

// Brand colors
final bgColor = img.ColorRgb8(0x0D, 0x0D, 0x0D);
final orange = img.ColorRgb8(0xFF, 0x6B, 0x2B);
final gold = img.ColorRgb8(0xFF, 0xB3, 0x47);
final white = img.ColorRgb8(0xFF, 0xFF, 0xFF);
final transparent = img.ColorRgba8(0, 0, 0, 0);

void main() {
  _generateFullIcon();
  _generateFgIcon();
  print('Icons generated in assets/icon/');
}

// Full icon (square, bg included) — used for iOS and legacy Android
void _generateFullIcon() {
  final canvas = img.Image(width: kSize, height: kSize);
  img.fill(canvas, color: bgColor);
  _drawSymbol(canvas, kSize ~/ 2, kSize ~/ 2, kSize * 0.72);
  final out = File('assets/icon/app_icon.png');
  out.writeAsBytesSync(img.encodePng(canvas));
  print('  app_icon.png (${out.lengthSync()} bytes)');
}

// Foreground only (transparent bg) — used for Android adaptive icon
void _generateFgIcon() {
  final canvas = img.Image(width: kSize, height: kSize);
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));
  _drawSymbol(canvas, kSize ~/ 2, kSize ~/ 2, kSize * 0.55);
  final out = File('assets/icon/app_icon_fg.png');
  out.writeAsBytesSync(img.encodePng(canvas));
  print('  app_icon_fg.png (${out.lengthSync()} bytes)');
}

// Core drawing: a pulse wave morphing into a growth arrow
//   cx, cy  = center of canvas
//   scale   = controls overall symbol size
void _drawSymbol(img.Image canvas, int cx, int cy, double scale) {
  // ── The path: flat → spike-up → dip → recovery → rising slope → arrowhead
  // All coordinates are relative to center, then scaled
  final pts = <List<double>>[
    [-0.50,  0.00], // start flat left
    [-0.25,  0.00], // still flat
    [-0.12, -0.30], // spike up (heartbeat peak)
    [ 0.00,  0.18], // dip down
    [ 0.10,  0.00], // recovery
    [ 0.48, -0.38], // end high right (growth)
  ];

  // Convert to absolute canvas coords
  List<int> xs = pts.map((p) => (cx + p[0] * scale).round()).toList();
  List<int> ys = pts.map((p) => (cy + p[1] * scale).round()).toList();

  final strokeW = (scale * 0.060).round().clamp(6, 60);

  // Draw the path segments
  for (int i = 0; i < pts.length - 1; i++) {
    // Blend from orange to gold across the path
    final t = i / (pts.length - 2);
    final c = _lerpColor(orange, gold, t);
    _drawThickLine(canvas, xs[i], ys[i], xs[i + 1], ys[i + 1], strokeW, c);
  }

  // Arrowhead at the end
  final ex = xs.last, ey = ys.last;
  final dx = ex - xs[xs.length - 2];
  final dy = ey - ys[ys.length - 2];
  _drawArrowHead(canvas, ex, ey, dx, dy, (strokeW * 2.8).round(), gold);

  // Pulse dot at the spike peak
  final dotR = (strokeW * 1.4).round();
  img.fillCircle(canvas, x: xs[2], y: ys[2], radius: dotR, color: white);
  img.fillCircle(canvas, x: xs[2], y: ys[2], radius: (dotR * 0.55).round(), color: orange);
}

// Thick line drawn as a series of filled circles along the path
void _drawThickLine(
    img.Image canvas, int x1, int y1, int x2, int y2, int r, img.Color color) {
  final dx = x2 - x1, dy = y2 - y1;
  final len = math.sqrt(dx * dx + dy * dy);
  if (len == 0) return;
  final steps = (len / (r * 0.4)).ceil().clamp(1, 2000);
  for (int i = 0; i <= steps; i++) {
    final t = i / steps;
    final x = (x1 + dx * t).round();
    final y = (y1 + dy * t).round();
    img.fillCircle(canvas, x: x, y: y, radius: r ~/ 2, color: color);
  }
}

// Filled arrowhead triangle
void _drawArrowHead(img.Image canvas, int tx, int ty, int dx, int dy, int size,
    img.Color color) {
  final len = math.sqrt(dx * dx + dy * dy);
  if (len == 0) return;
  final ux = dx / len, uy = dy / len;
  // Perpendicular
  final px = -uy, py = ux;
  // Three vertices: tip + two base corners
  final ax = tx, ay = ty;
  final bx = tx - (ux * size).round() + (px * size * 0.5).round();
  final by = ty - (uy * size).round() + (py * size * 0.5).round();
  final cx2 = tx - (ux * size).round() - (px * size * 0.5).round();
  final cy2 = ty - (uy * size).round() - (py * size * 0.5).round();

  // Rasterise the triangle by filling horizontal spans
  final xs = [ax, bx, cx2], ys = [ay, by, cy2];
  final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
  for (int y = minY; y <= maxY; y++) {
    final xCrossings = <int>[];
    for (int e = 0; e < 3; e++) {
      final x0 = xs[e], y0 = ys[e];
      final x1e = xs[(e + 1) % 3], y1e = ys[(e + 1) % 3];
      if ((y0 <= y && y < y1e) || (y1e <= y && y < y0)) {
        final xCross = x0 + (y - y0) * (x1e - x0) ~/ (y1e - y0);
        xCrossings.add(xCross);
      }
    }
    if (xCrossings.length == 2) {
      final lx = xCrossings.reduce(math.min);
      final rx = xCrossings.reduce(math.max);
      for (int x = lx; x <= rx; x++) {
        if (x >= 0 && x < canvas.width && y >= 0 && y < canvas.height) {
          canvas.setPixel(x, y, color);
        }
      }
    }
  }
}

img.Color _lerpColor(img.ColorRgb8 a, img.ColorRgb8 b, double t) {
  return img.ColorRgb8(
    (a.r + (b.r - a.r) * t).round(),
    (a.g + (b.g - a.g) * t).round(),
    (a.b + (b.b - a.b) * t).round(),
  );
}
