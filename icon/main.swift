import Cocoa
import ImageIO
import UniformTypeIdentifiers

// Peek 앱 아이콘 — 남색→자주 그라데이션 라운드 스퀘어 위, 기울어진 노란 작은 창에 빨간 압정이 꽂혀 있다
// 좌표는 Paper 시안(「Peek 툴바」 파일 · 아이콘 가-3, 남색→자주 그라데이션)의 412 단위 그대로, 좌상단 원점.

func hex(_ v: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255,
            green: CGFloat((v >> 8) & 0xff) / 255,
            blue: CGFloat(v & 0xff) / 255, alpha: a)
}

func rad(_ d: CGFloat) -> CGFloat { d * .pi / 180 }

func render(size S: CGFloat) -> CGImage {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8,
                        bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.setAllowsAntialiasing(true)

    // 아트워크 영역: 1024 캔버스에서 824 정사각 (macOS 표준 여백)
    let side = S * 824.0 / 1024.0
    let inset = (S - side) / 2
    let k = side / 412.0                     // 시안 1단위 → 픽셀

    // 좌상단 원점, 시안 단위로 그린다
    ctx.translateBy(x: 0, y: S)
    ctx.scaleBy(x: 1, y: -1)
    ctx.translateBy(x: inset, y: inset)
    ctx.scaleBy(x: k, y: k)

    // 그림자는 CTM을 안 따르므로 픽셀로 넘긴다 (아래쪽 = 음수 y)
    func shadow(_ dy: CGFloat, _ blur: CGFloat, _ a: CGFloat) {
        ctx.setShadow(offset: CGSize(width: 0, height: -dy * k), blur: blur * k, color: hex(0x000000, a))
    }
    func rr(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
        CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil)
    }

    // 바탕
    let card = rr(0, 0, 412, 412, 92)
    ctx.saveGState()
    ctx.addPath(card)
    ctx.clip()
    let bg = CGGradient(colorsSpace: cs, colors: [hex(0x4A5A8C), hex(0x3A2F63), hex(0x120F22)] as CFArray, locations: [0, 0.45, 1])!
    // CSS 160deg: 위에서 아래로, 약간 오른쪽으로 흐른다
    let dx = sin(rad(160)) * 206, dy = -cos(rad(160)) * 206
    ctx.drawLinearGradient(bg, start: CGPoint(x: 206 - dx, y: 206 - dy), end: CGPoint(x: 206 + dx, y: 206 + dy), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.setFillColor(hex(0xFFFFFF, 0.08))
    ctx.fill(CGRect(x: 0, y: 0, width: 412, height: 1))

    // 뒤 화면
    let screen = rr(62, 118, 250, 180, 26)
    ctx.addPath(screen)
    ctx.setFillColor(hex(0xFFFFFF, 0.10))
    ctx.fillPath()
    ctx.addPath(rr(63, 119, 248, 178, 25))
    ctx.setStrokeColor(hex(0xFFFFFF, 0.10))
    ctx.setLineWidth(2)
    ctx.strokePath()

    // 노란 작은 창: (170,96) 168×112, 왼쪽 위 모서리 기준 -8도 (Paper 회전 기준과 같다)
    ctx.saveGState()
    ctx.translateBy(x: 170, y: 96)
    ctx.rotate(by: rad(-8))

    ctx.saveGState()
    shadow(14, 30, 0.55)
    ctx.addPath(rr(0, 0, 168, 112, 22))
    ctx.setFillColor(hex(0xFFD60A))
    ctx.fillPath()
    ctx.restoreGState()

    // 재생 막대
    ctx.addPath(rr(22, 84, 124, 8, 4))
    ctx.setFillColor(hex(0x111114, 0.22))
    ctx.fillPath()
    ctx.addPath(rr(22, 84, 124 * 0.58, 8, 4))
    ctx.setFillColor(hex(0x111114))
    ctx.fillPath()

    // 압정 그림자
    ctx.saveGState()
    ctx.translateBy(x: 38, y: 52)
    ctx.rotate(by: rad(-14))
    ctx.addEllipse(in: CGRect(x: 0, y: 0, width: 40, height: 14))
    ctx.setFillColor(hex(0x000000, 0.25))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.restoreGState()

    // 압정: (236,40) 72×120, 왼쪽 위 모서리 기준 28도
    ctx.saveGState()
    ctx.translateBy(x: 236, y: 40)
    ctx.rotate(by: rad(28))

    func fill(_ c: CGColor, _ build: (CGMutablePath) -> Void) {
        let p = CGMutablePath()
        build(p)
        ctx.addPath(p)
        ctx.setFillColor(c)
        ctx.fillPath()
    }
    // 받침
    fill(hex(0xD92F25)) { p in
        p.move(to: CGPoint(x: 14, y: 70))
        p.addCurve(to: CGPoint(x: 58, y: 70), control1: CGPoint(x: 14, y: 64), control2: CGPoint(x: 58, y: 64))
        p.addLine(to: CGPoint(x: 58, y: 76))
        p.addCurve(to: CGPoint(x: 14, y: 76), control1: CGPoint(x: 58, y: 84), control2: CGPoint(x: 14, y: 84))
        p.closeSubpath()
    }
    // 몸통
    fill(hex(0xFF453A)) { p in
        p.addLines(between: [CGPoint(x: 24, y: 30), CGPoint(x: 48, y: 30), CGPoint(x: 44, y: 66), CGPoint(x: 28, y: 66)])
        p.closeSubpath()
    }
    fill(hex(0xFF8A80, 0.7)) { p in
        p.addLines(between: [CGPoint(x: 28, y: 30), CGPoint(x: 34, y: 30), CGPoint(x: 32, y: 66), CGPoint(x: 29, y: 66)])
        p.closeSubpath()
    }
    // 머리
    fill(hex(0xD92F25)) { p in p.addEllipse(in: CGRect(x: 12, y: 10, width: 48, height: 24)) }
    fill(hex(0xFF453A)) { p in
        p.move(to: CGPoint(x: 12, y: 22))
        p.addCurve(to: CGPoint(x: 60, y: 22), control1: CGPoint(x: 12, y: 6), control2: CGPoint(x: 60, y: 6))
        p.addCurve(to: CGPoint(x: 12, y: 22), control1: CGPoint(x: 60, y: 30), control2: CGPoint(x: 12, y: 30))
        p.closeSubpath()
    }
    fill(hex(0xFFFFFF, 0.55)) { p in p.addEllipse(in: CGRect(x: 20, y: 10.5, width: 16, height: 7)) }
    ctx.restoreGState()

    ctx.restoreGState()
    return ctx.makeImage()!
}

let dir = CommandLine.arguments[1]
for s in [16, 32, 64, 128, 256, 512, 1024] {
    let img = render(size: CGFloat(s))
    let url = URL(fileURLWithPath: "\(dir)/icon_\(s).png") as CFURL
    let dest = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
}
print("rendered")
