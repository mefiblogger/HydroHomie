import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Render page 1 of a PDF at an exact pixel size, so the launch artwork is resampled
// once from vector rather than twice through an intermediate raster.
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let width = Int(CommandLine.arguments[3])!
let height = Int(CommandLine.arguments[4])!

guard let document = CGPDFDocument(input as CFURL), let page = document.page(at: 1) else {
    fatalError("could not open \(input.path)")
}
let box = page.getBoxRect(.cropBox)

guard let context = CGContext(
    data: nil, width: width, height: height,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { fatalError("could not make context") }

context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: width, height: height))
context.interpolationQuality = .high
context.scaleBy(x: CGFloat(width) / box.width, y: CGFloat(height) / box.height)
context.translateBy(x: -box.origin.x, y: -box.origin.y)
context.drawPDFPage(page)

guard let image = context.makeImage(),
      let dest = CGImageDestinationCreateWithURL(
        output as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("could not write")
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("write failed") }
print("\(output.lastPathComponent): \(width)x\(height) from \(Int(box.width))x\(Int(box.height))pt")
