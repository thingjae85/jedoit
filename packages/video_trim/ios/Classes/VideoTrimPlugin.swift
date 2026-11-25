import AVFoundation
import Flutter

/// 동영상의 한 구간을 잘라 720p MP4로 내보낸다. 결과 파일의 바이트를 돌려주고 임시 파일은 지운다.
public class VideoTrimPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "jeoduit/video_trim", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(VideoTrimPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "trim" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String,
          let start = args["start"] as? Double,
          let duration = args["duration"] as? Double,
          duration > 0 else {
      result(FlutterError(code: "bad_args", message: nil, details: nil))
      return
    }

    let source = path.hasPrefix("file://") ? URL(string: path)! : URL(fileURLWithPath: path)
    let asset = AVURLAsset(url: source)
    let preset = AVAssetExportSession.exportPresets(compatibleWith: asset).contains(AVAssetExportPreset1280x720)
      ? AVAssetExportPreset1280x720
      : AVAssetExportPresetMediumQuality
    guard let export = AVAssetExportSession(asset: asset, presetName: preset) else {
      result(FlutterError(code: "export_unavailable", message: nil, details: nil))
      return
    }
    let out = FileManager.default.temporaryDirectory
      .appendingPathComponent("trim-\(UUID().uuidString).mp4")
    export.outputURL = out
    export.outputFileType = .mp4
    export.shouldOptimizeForNetworkUse = true
    export.timeRange = CMTimeRange(
      start: CMTime(seconds: max(0, start), preferredTimescale: 600),
      duration: CMTime(seconds: duration, preferredTimescale: 600))

    export.exportAsynchronously {
      let status = export.status
      let message = export.error?.localizedDescription
      var data: Data? = nil
      if status == .completed {
        data = try? Data(contentsOf: out)
      }
      try? FileManager.default.removeItem(at: out)
      DispatchQueue.main.async {
        if let data = data {
          result(FlutterStandardTypedData(bytes: data))
        } else {
          result(FlutterError(code: "export_failed", message: message, details: nil))
        }
      }
    }
  }
}
