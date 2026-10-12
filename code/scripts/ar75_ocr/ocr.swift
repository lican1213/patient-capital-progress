import Foundation
import Vision
import AppKit

// 用法：ocr <image> [nx ny]；按 nx×ny 分块（带重叠）识别，输出：文本\tx\ty\tw\th（整图归一化坐标，原点左下）
let args = CommandLine.arguments
let path = args[1]
let nx = args.count > 2 ? Int(args[2])! : 1
let ny = args.count > 3 ? Int(args[3])! : 1
guard let img = NSImage(contentsOfFile: path),
      let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write("cannot load \(path)\n".data(using: .utf8)!); exit(1)
}
let ov = 0.04
for i in 0..<nx {
    for j in 0..<ny {
        let x0 = max(0, Double(i) / Double(nx) - ov), x1 = min(1, Double(i + 1) / Double(nx) + ov)
        let y0 = max(0, Double(j) / Double(ny) - ov), y1 = min(1, Double(j + 1) / Double(ny) + ov)
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = false
        req.recognitionLanguages = ["zh-Hans", "en-US"]
        req.regionOfInterest = CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
        try VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])
        for obs in req.results ?? [] {
            guard let top = obs.topCandidates(1).first else { continue }
            let b = obs.boundingBox
            let gx = x0 + b.origin.x * (x1 - x0), gy = y0 + b.origin.y * (y1 - y0)
            print("\(top.string)\t\(gx)\t\(gy)\t\(b.size.width * (x1 - x0))\t\(b.size.height * (y1 - y0))")
        }
    }
}
