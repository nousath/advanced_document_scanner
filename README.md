# 📄 advanced_document_scanner

Camera-based document scanner for Flutter with a built-in editor (highlight, crop/cut, rotate) and advanced export options (JPG/PNG/GIF + low/medium/high/max presets).

> **Platforms:** ✅ Android | ✅ iOS

---

## ✨ Features

### 📷 Scan
- Uses the `camera` plugin
- Captures at **maximum supported resolution** (best source)
- Multi-page capture

### 🤖 Native document scanner (optional)
- **Android:** Google ML Kit Document Scanner (Play services)
  - Uses dependency `com.google.android.gms:play-services-mlkit-document-scanner:16.0.0`
- **iOS:** VisionKit document scanner (`VNDocumentCameraViewController`)
- Returns page images and (when available) a generated PDF

### ✍️ Edit
- Highlight (marker)
- Crop / Cut
- Rotate

### 📤 Export
- Formats: **JPG / PNG / GIF**
- Presets: **low / medium / high / max**
- Optional overrides: `targetWidth`, `targetHeight`, `jpgQuality`

---

## 🚀 Installation

```yaml
dependencies:
  advanced_document_scanner: ^0.0.1
```

---

## 🔐 Permissions

### Android
Add in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA"/>
```

### iOS
Add in `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to scan documents.</string>
```

---

## ✅ Usage

### 1) Capture + Edit

```dart
final scanner = AdvancedDocumentScanner();

final result = await scanner.captureAndEdit(
  pageLimit: 10,
  multiPage: true,
);

final source = (result.editedImagePaths?.isNotEmpty ?? false)
    ? result.editedImagePaths!
    : result.originalImagePaths;
```

### 2) Scan + Edit (ML Kit Android / VisionKit iOS)

```dart
final scanner = AdvancedDocumentScanner();

final result = await scanner.scanWithMlKit(
  pageLimit: 10,
  allowGallery: true,
  returnJpeg: true,
  returnPdf: true,
  openEditorAfterScan: true,
);

// Optional:
final pdfPath = result.pdfPath;
```

---

## 📤 Export (ALL options)

### A) Export with preset (low / medium / high / max)

```dart
final outputDir = await scanner.getDefaultExportDir(
  folderName: 'advanced_document_scanner_exports',
);

final files = await scanner.exportImages(
  imagePaths: source,
  outputDir: outputDir,
  options: const AdsExportOptions(
    format: AdsImageFormat.jpg,
    preset: AdsQualityPreset.high,
  ),
);
```

### B) Export as PNG (lossless)

```dart
final pngFiles = await scanner.exportImages(
  imagePaths: source,
  outputDir: outputDir,
  options: const AdsExportOptions(
    format: AdsImageFormat.png,
    preset: AdsQualityPreset.high,
  ),
);
```

### C) Export as GIF (single-frame)

```dart
final gifFiles = await scanner.exportImages(
  imagePaths: source,
  outputDir: outputDir,
  options: const AdsExportOptions(
    format: AdsImageFormat.gif,
    preset: AdsQualityPreset.medium,
  ),
);
```

### D) Custom width/height override

```dart
final customSize = await scanner.exportImages(
  imagePaths: source,
  outputDir: outputDir,
  options: const AdsExportOptions(
    format: AdsImageFormat.jpg,
    preset: AdsQualityPreset.high,
    targetWidth: 1600,
    targetHeight: 2200,
  ),
);
```

### E) Override JPG quality (0–100)

```dart
final customQuality = await scanner.exportImages(
  imagePaths: source,
  outputDir: outputDir,
  options: const AdsExportOptions(
    format: AdsImageFormat.jpg,
    preset: AdsQualityPreset.high,
    jpgQuality: 85,
  ),
);
```

---

## 🧩 Open editor for existing images

```dart
final editedPaths = await scanner.openEditor(
  imagePaths: source,
  enableHighlight: true,
  enableCrop: true,
  enableCut: true,
  enableRotate: true,
);
```

---

## ☕ Sponsor a cup of tea

If this package saves your time, consider supporting development ❤️

- GitHub Sponsors: https://github.com/sponsors/nousath

---

## 📄 License
MIT
