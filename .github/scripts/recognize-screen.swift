import Foundation
import Vision

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: recognize-screen <image.png>\n", stderr)
    exit(2)
}

let imageURL = URL(fileURLWithPath: CommandLine.arguments[1])
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = false
request.recognitionLanguages = ["en-US"]

do {
    let handler = VNImageRequestHandler(url: imageURL, options: [:])
    try handler.perform([request])
    for observation in request.results ?? [] {
        if let candidate = observation.topCandidates(1).first {
            print(candidate.string)
        }
    }
} catch {
    fputs("Screen OCR failed: \(error)\n", stderr)
    exit(1)
}
