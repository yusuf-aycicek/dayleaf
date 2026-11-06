import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'background.dart';
import 'templates.dart';
import 'wallpaper_content.dart';

class RenderedWallpaper {
  RenderedWallpaper(this.image, this.report);

  final ui.Image image;
  final LayoutReport report;

  void dispose() => image.dispose();
}

/// Draws wallpapers with `dart:ui` only (no widgets), so the same code runs
/// in the app and in the background job's engine.
abstract final class WallpaperRenderer {
  static Future<RenderedWallpaper> render({
    required WallpaperContent content,
    required WallpaperTemplate template,
    required BackgroundSpec background,
    required int width,
    required int height,
  }) async {
    final size = Size(width.toDouble(), height.toDouble());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & size);
    background.paint(canvas, size);
    final report = template.paint(canvas, size, content, background);
    final picture = recorder.endRecording();
    try {
      return RenderedWallpaper(await picture.toImage(width, height), report);
    } finally {
      picture.dispose();
    }
  }

  /// A copy of [wallpaper] with a small app-name label in the bottom-right
  /// corner. Only shared images get it, never the wallpaper itself.
  static Future<ui.Image> withWatermark(
    ui.Image wallpaper,
    String label,
  ) async {
    final w = wallpaper.width.toDouble(), h = wallpaper.height.toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
    canvas.drawImage(wallpaper, Offset.zero, Paint());

    final fontSize = w * 0.026;
    final paragraph =
        (ui.ParagraphBuilder(
                ui.ParagraphStyle(fontFamily: 'Manrope', fontSize: fontSize),
              )
              ..pushStyle(
                ui.TextStyle(
                  color: const Color(0xF2FFFFFF),
                  fontFamily: 'Manrope',
                  fontSize: fontSize,
                  letterSpacing: fontSize * 0.04,
                  fontWeight: FontWeight.w700,
                  fontVariations: [const ui.FontVariation('wght', 700)],
                ),
              )
              ..addText(label))
            .build()
          ..layout(const ui.ParagraphConstraints(width: double.infinity));
    final padX = fontSize * 0.8, padY = fontSize * 0.45, margin = w * 0.04;
    final pill = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        w - margin - paragraph.longestLine - padX * 2,
        h - margin - paragraph.height - padY * 2,
        paragraph.longestLine + padX * 2,
        paragraph.height + padY * 2,
      ),
      Radius.circular(paragraph.height),
    );
    canvas.drawRRect(pill, Paint()..color = const Color(0x66000000));
    canvas.drawParagraph(paragraph, Offset(pill.left + padX, pill.top + padY));
    paragraph.dispose();

    final picture = recorder.endRecording();
    try {
      return await picture.toImage(wallpaper.width, wallpaper.height);
    } finally {
      picture.dispose();
    }
  }

  static Future<Uint8List> encodePng(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  /// Raw RGBA bytes: what the Android side copies into a Bitmap without
  /// decoding a PNG.
  static Future<Uint8List> encodeRgba(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data!.buffer.asUint8List();
  }
}
