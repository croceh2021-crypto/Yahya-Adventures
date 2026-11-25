import Foundation
import Vision
import ImageIO

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: recognize-screen <image.png>\n", stderr)
    exit(2)
}

let imageURL = URL(fileURLWithPath: CommandLine.arguments[1])
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = false

do {
    let supported = try request.supportedRecognitionLanguages()
    let languages = ["en-US", "ar-SA"].filter { supported.contains($0) }
    guard !languages.isEmpty else {
        fputs("No supported OCR language was found\n", stderr)
        exit(1)
    }

    for language in languages {
        request.recognitionLanguages = [language]
        let handler = VNImageRequestHandler(url: imageURL, options: [:])
        try handler.perform([request])
        for observation in request.results ?? [] {
            if let candidate = observation.topCandidates(1).first {
                print(candidate.string)
            }
        }
    }
} catch {
    fputs("Screen OCR failed: \(error)\n", stderr)
    exit(1)
}
