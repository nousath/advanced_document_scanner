import 'dart:io';

import 'package:image/image.dart' as img;

import '../models.dart';

class AdsExportService {
  Future<String> exportOne({
    required String inputPath,
    required String outputPath,
    required AdsExportOptions options,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Unable to decode image: $inputPath');
    }

    final preset = _presetParams(options);

    // Determine target dimensions
    int targetW;
    int targetH;
    if (options.targetWidth != null || options.targetHeight != null) {
      final w = options.targetWidth;
      final h = options.targetHeight;
      if (w != null && h != null) {
        targetW = w;
        targetH = h;
      } else if (w != null) {
        targetW = w;
        targetH = (decoded.height * (w / decoded.width)).round();
      } else {
        targetH = h!;
        targetW = (decoded.width * (h / decoded.height)).round();
      }
    } else {
      // scale so that max side <= preset.maxSide
      final maxSide = preset.maxSide;
      final curMax = decoded.width > decoded.height ? decoded.width : decoded.height;
      if (maxSide == null || curMax <= maxSide) {
        targetW = decoded.width;
        targetH = decoded.height;
      } else {
        final scale = maxSide / curMax;
        targetW = (decoded.width * scale).round();
        targetH = (decoded.height * scale).round();
      }
    }

    final resized = (targetW == decoded.width && targetH == decoded.height)
        ? decoded
        : img.copyResize(
            decoded,
            width: targetW,
            height: targetH,
            interpolation: img.Interpolation.average,
          );

    List<int> out;
    switch (options.format) {
      case AdsImageFormat.jpg:
        final q = options.jpgQuality ?? preset.jpgQuality;
        out = img.encodeJpg(resized, quality: q);
        break;
      case AdsImageFormat.png:
        out = img.encodePng(resized, level: preset.pngLevel);
        break;
      case AdsImageFormat.gif:
        // single-frame gif
        out = img.encodeGif(resized);
        break;
    }

    final f = File(outputPath);
    await f.parent.create(recursive: true);
    await f.writeAsBytes(out, flush: true);
    return f.path;
  }
}

class _Preset {
  final int? maxSide;
  final int jpgQuality;
  final int pngLevel;

  const _Preset({required this.maxSide, required this.jpgQuality, required this.pngLevel});
}

_Preset _presetParams(AdsExportOptions options) {
  switch (options.preset) {
    case AdsQualityPreset.max:
      return const _Preset(maxSide: null, jpgQuality: 95, pngLevel: 6);
    case AdsQualityPreset.high:
      return const _Preset(maxSide: 2500, jpgQuality: 90, pngLevel: 6);
    case AdsQualityPreset.medium:
      return const _Preset(maxSide: 1600, jpgQuality: 80, pngLevel: 7);
    case AdsQualityPreset.low:
      return const _Preset(maxSide: 1024, jpgQuality: 65, pngLevel: 8);
  }
}
