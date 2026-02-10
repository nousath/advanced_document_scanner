import Flutter
import UIKit
import VisionKit
import PDFKit

/// Native scanner bridge.
///
/// iOS implementation uses VisionKit's VNDocumentCameraViewController.
public class AdvancedDocumentScannerPlugin: NSObject, FlutterPlugin, VNDocumentCameraViewControllerDelegate {

  private var channel: FlutterMethodChannel?
  private var pendingResult: FlutterResult?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "advanced_document_scanner/native_scanner", binaryMessenger: registrar.messenger())
    let instance = AdvancedDocumentScannerPlugin()
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "scan":
      startScan(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startScan(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if pendingResult != nil {
      result(FlutterError(code: "IN_PROGRESS", message: "Another scan is already running.", details: nil))
      return
    }
    guard VNDocumentCameraViewController.isSupported else {
      result(FlutterError(code: "UNSUPPORTED", message: "VNDocumentCameraViewController is not supported on this device.", details: nil))
      return
    }

    guard let presenter = UIApplication.shared.ads_topMostViewController() else {
      result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "Unable to find a view controller to present scanner.", details: nil))
      return
    }

    pendingResult = result

    let scanner = VNDocumentCameraViewController()
    scanner.delegate = self
    presenter.present(scanner, animated: true, completion: nil)
  }

  // MARK: - VNDocumentCameraViewControllerDelegate

  public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
    controller.dismiss(animated: true) {
      self.finishSuccess(imagePaths: [], pdfPath: nil)
    }
  }

  public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
    controller.dismiss(animated: true) {
      self.finishError(code: "SCAN_FAILED", message: error.localizedDescription)
    }
  }

  public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
    controller.dismiss(animated: true) {
      let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("ads_vkit", isDirectory: true)
      try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

      var imagePaths: [String] = []
      let pdfDoc = PDFDocument()

      for i in 0..<scan.pageCount {
        let image = scan.imageOfPage(at: i)
        let name = "vkit_page_\(Int(Date().timeIntervalSince1970 * 1000))_\(i).jpg"
        let url = tmpDir.appendingPathComponent(name)

        if let data = image.jpegData(compressionQuality: 0.98) {
          try? data.write(to: url, options: .atomic)
          imagePaths.append(url.path)
        }

        if let pdfPage = PDFPage(image: image) {
          pdfDoc.insert(pdfPage, at: pdfDoc.pageCount)
        }
      }

      var pdfPath: String? = nil
      if pdfDoc.pageCount > 0 {
        let pdfName = "vkit_scan_\(Int(Date().timeIntervalSince1970 * 1000)).pdf"
        let pdfURL = tmpDir.appendingPathComponent(pdfName)
        if pdfDoc.write(to: pdfURL) {
          pdfPath = pdfURL.path
        }
      }

      self.finishSuccess(imagePaths: imagePaths, pdfPath: pdfPath)
    }
  }

  // MARK: - Finish helpers

  private func finishSuccess(imagePaths: [String], pdfPath: String?) {
    guard let res = pendingResult else { return }
    pendingResult = nil
    res(["imagePaths": imagePaths, "pdfPath": pdfPath as Any])
  }

  private func finishError(code: String, message: String) {
    guard let res = pendingResult else { return }
    pendingResult = nil
    res(FlutterError(code: code, message: message, details: nil))
  }
}

// MARK: - Top most VC helper

private extension UIApplication {
  func ads_topMostViewController(base: UIViewController? = nil) -> UIViewController? {
    let baseVC: UIViewController?
    if let base = base {
      baseVC = base
    } else {
      baseVC = connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }?.rootViewController
    }

    guard let root = baseVC else { return nil }
    if let nav = root as? UINavigationController {
      return ads_topMostViewController(base: nav.visibleViewController)
    }
    if let tab = root as? UITabBarController {
      return ads_topMostViewController(base: tab.selectedViewController)
    }
    if let presented = root.presentedViewController {
      return ads_topMostViewController(base: presented)
    }
    return root
  }
}
