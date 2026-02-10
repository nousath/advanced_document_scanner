import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'models.dart';
import 'ui/capture_page.dart';
import 'ui/editor_page.dart';
import 'util/export_service.dart';

/// Main API for [advanced_document_scanner].
///
/// Note: These methods open Flutter pages using the nearest Navigator.
class AdvancedDocumentScanner {
  const AdvancedDocumentScanner();

  static const MethodChannel _native = MethodChannel('advanced_document_scanner/native_scanner');

  BuildContext _resolveContext(BuildContext? context) {
    if (context != null) return context;
    final root = WidgetsBinding.instance.renderViewElement;
    final ctx = root;
    if (ctx == null) {
      throw StateError(
        'No BuildContext available. Pass a context (e.g., context from a button onPressed).',
      );
    }
    return ctx;
  }

  /// Opens camera capture flow (multi-page) and then editor for captured pages.
  ///
  /// Returns both original captured images (max resolution) and edited images.
  Future<AdsScanResult> captureAndEdit({
    BuildContext? context,
    int pageLimit = 10,
    bool multiPage = true,
  }) async {
    final ctx = _resolveContext(context);

    final originals = await Navigator.of(ctx).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => AdsCapturePage(
          pageLimit: pageLimit,
          multiPage: multiPage,
        ),
        fullscreenDialog: true,
      ),
    );

    final originalPaths = originals ?? <String>[];
    if (originalPaths.isEmpty) {
      return const AdsScanResult(originalImagePaths: <String>[]);
    }

    final edited = await openEditor(
      context: ctx,
      imagePaths: originalPaths,
      enableHighlight: true,
      enableCrop: true,
      enableCut: true,
      enableRotate: true,
    );

    return AdsScanResult(originalImagePaths: originalPaths, editedImagePaths: edited);
  }

  /// Opens the **native document scanner UI**.
  ///
  /// - Android: Google ML Kit Document Scanner (Play services)
  /// - iOS: VisionKit document scanner
  ///
  /// Returns captured page images and (when available) a PDF path.
  /// Optionally opens the Flutter editor after scanning.
  Future<AdsScanResult> scanWithMlKit({
    BuildContext? context,
    int pageLimit = 10,
    bool allowGallery = true,
    bool returnPdf = true,
    bool returnJpeg = true,
    bool openEditorAfterScan = true,
  }) async {
    final ctx = _resolveContext(context);

    final map = await _native.invokeMapMethod<String, dynamic>(
      'scan',
      <String, dynamic>{
        'pageLimit': pageLimit,
        'allowGallery': allowGallery,
        'returnPdf': returnPdf,
        'returnJpeg': returnJpeg,
      },
    );

    final imagePaths = (map?['imagePaths'] as List?)?.cast<String>() ?? <String>[];
    final pdfPath = map?['pdfPath'] as String?;

    if (imagePaths.isEmpty) {
      return AdsScanResult(originalImagePaths: const <String>[], pdfPath: pdfPath);
    }

    if (!openEditorAfterScan) {
      return AdsScanResult(originalImagePaths: imagePaths, pdfPath: pdfPath);
    }

    final edited = await openEditor(
      context: ctx,
      imagePaths: imagePaths,
      enableHighlight: true,
      enableCrop: true,
      enableCut: true,
      enableRotate: true,
    );

    return AdsScanResult(originalImagePaths: imagePaths, editedImagePaths: edited, pdfPath: pdfPath);
  }

  /// Opens the built-in editor for [imagePaths] and returns edited image paths.
  Future<List<String>> openEditor({
    BuildContext? context,
    required List<String> imagePaths,
    bool enableHighlight = true,
    bool enableCrop = true,
    bool enableCut = true,
    bool enableRotate = true,
  }) async {
    final ctx = _resolveContext(context);

    final out = await Navigator.of(ctx).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => AdsEditorPage(
          imagePaths: imagePaths,
          enableHighlight: enableHighlight,
          enableCrop: enableCrop,
          enableCut: enableCut,
          enableRotate: enableRotate,
        ),
        fullscreenDialog: true,
      ),
    );

    return out ?? <String>[];
  }

  /// Exports [imagePaths] to [outputDir] using [options].
  ///
  /// The plugin always expects the source images to be the *best quality* images.
  /// It will downscale/compress during export based on the preset.
  Future<List<String>> exportImages({
    required List<String> imagePaths,
    required String outputDir,
    AdsExportOptions options = const AdsExportOptions(),
  }) async {
    final dir = Directory(outputDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final service = AdsExportService();
    final out = <String>[];

    for (var i = 0; i < imagePaths.length; i++) {
      final inputPath = imagePaths[i];
      final baseName = p.basenameWithoutExtension(inputPath);
      final ext = switch (options.format) {
        AdsImageFormat.jpg => 'jpg',
        AdsImageFormat.png => 'png',
        AdsImageFormat.gif => 'gif',
      };

      final outputPath = p.join(outputDir, '${baseName}_export_${options.preset.name}.$ext');
      final saved = await service.exportOne(
        inputPath: inputPath,
        outputPath: outputPath,
        options: options,
      );
      out.add(saved);
    }

    return out;
  }

  /// Convenience helper for examples.
  /// Returns an app-private directory path suitable for exports.
  Future<String> getDefaultExportDir({String folderName = 'exports'}) async {
    final base = await getApplicationDocumentsDirectory();
    final out = Directory(p.join(base.path, folderName));
    if (!await out.exists()) {
      await out.create(recursive: true);
    }
    return out.path;
  }
}
