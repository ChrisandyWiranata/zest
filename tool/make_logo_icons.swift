import CoreGraphics
import ImageIO
import Foundation

// Membangun sumber ikon 1024x1024 dari logo asli:
//   - outline hitam di sekeliling glyph (gaya stiker, konsisten dgn aksen hitam glyph)
//   - logo-zest-1024.png   : kanvas transparan (adaptive foreground / favicon / in-app)
//   - logo-zest-bg-1024.png: latar penuh #121214 (iOS / web / Android legacy)
let iconRoot = URL(fileURLWithPath: "assets/icon/")
let srcURL = iconRoot.appendingPathComponent("logo-zest.png")
let out1 = iconRoot.appendingPathComponent("logo-zest-1024.png")
let out2 = iconRoot.appendingPathComponent("logo-zest-bg-1024.png")

guard let srcRef = CGImageSourceCreateWithURL(srcURL as CFURL, nil),
      let srcImg = CGImageSourceCreateImageAtIndex(srcRef, 0, nil) else {
  fatalError("cannot read \(srcURL.path)")
}

// 1) Baca piksel logo (RGBA premultiplied) lalu buat silhouette hitam (rgb 0, alpha asli).
let srcW = srcImg.width, srcH = srcImg.height
let bpr = srcW * 4
var buf = [UInt8](repeating: 0, count: bpr * srcH)
let readCtx = CGContext(
  data: &buf, width: srcW, height: srcH, bitsPerComponent: 8, bytesPerRow: bpr,
  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
readCtx.draw(srcImg, in: CGRect(x: 0, y: 0, width: srcW, height: srcH))

// Silhouette: buang warna, pertahankan alpha.
let minAlpha: UInt8 = 24
var sil = [UInt8](repeating: 0, count: bpr * srcH)
for i in 0..<(srcW * srcH) {
  let a = buf[i * 4 + 3]
  if a >= minAlpha {
    sil[i * 4] = 0      // r
    sil[i * 4 + 1] = 0  // g
    sil[i * 4 + 2] = 0  // b
    sil[i * 4 + 3] = a
  }
}
let silData = Data(sil)
let silProvider = CGDataProvider(data: silData as CFData)!
let silImg = CGImage(
  width: srcW, height: srcH, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bpr,
  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
  provider: silProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
)!

// 2) Canvas 1024².
let canvas: CGFloat = 1024
let outlineW: CGFloat = 30
let targetH: CGFloat = canvas * 0.92
let scale = targetH / CGFloat(srcH)
let drawW = CGFloat(srcW) * scale
let drawH = CGFloat(srcH) * scale
let ox: CGFloat = (canvas - drawW) / 2
let oy: CGFloat = (canvas - drawH) / 2

func newCtx(opaque: Bool) -> CGContext {
  let ctx = CGContext(
    data: nil, width: Int(canvas), height: Int(canvas), bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  )!
  if opaque {
    ctx.setFillColor(CGColor(srgbRed: 0x12/255, green: 0x12/255, blue: 0x14/255, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: canvas, height: canvas))
  }
  return ctx
}

func writePNG(_ ctx: CGContext, to url: URL) {
  let out = ctx.makeImage()!
  let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
  CGImageDestinationAddImage(dest, out, nil)
  CGImageDestinationFinalize(dest)
}

func drawOutlinedGlyph(_ ctx: CGContext) {
  let rect = CGRect(x: ox, y: oy, width: drawW, height: drawH)
  // Outline hitam: gambar silhouette 9x dengan offset, lalu glyph asli di atas.
  let offsets: [(CGFloat, CGFloat)] = [
    (-1, -1), (0, -1), (1, -1),
    (-1, 0), (0, 0), (1, 0),
    (-1, 1), (0, 1), (1, 1),
  ]
  for (dx, dy) in offsets {
    ctx.draw(silImg, in: rect.offsetBy(dx: dx * outlineW, dy: dy * outlineW))
  }
  ctx.draw(srcImg, in: rect)
}

let clear = newCtx(opaque: false)
drawOutlinedGlyph(clear)
writePNG(clear, to: out1)

let filled = newCtx(opaque: true)
drawOutlinedGlyph(filled)
writePNG(filled, to: out2)

print("wrote \(out1.path) and \(out2.path)")