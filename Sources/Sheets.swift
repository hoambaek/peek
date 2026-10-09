import Cocoa

// 주소 입력·사이트 추가 화면에서 쓰는 작은 뷰들

let peekYellow = NSColor(calibratedRed: 1, green: 0xD6/255.0, blue: 0x0A/255.0, alpha: 1)
let sheetFill = NSColor(calibratedRed: 36/255, green: 36/255, blue: 40/255, alpha: 0.97)

func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, alpha: CGFloat = 1) -> NSTextField {
    let l = NSTextField(labelWithString: text)
    l.font = .systemFont(ofSize: size, weight: weight)
    l.textColor = NSColor.white.withAlphaComponent(alpha)
    l.lineBreakMode = .byTruncatingTail
    return l
}

// 위에서 아래로 배치하는 카드. 안쪽 클릭이 뒤의 막으로 새지 않는다.
final class CardView: NSView {
    override var isFlipped: Bool { true }
    override func mouseDown(with event: NSEvent) {}
    override var mouseDownCanMoveWindow: Bool { false }

    func style(radius: CGFloat, fill: NSColor = sheetFill, border: CGFloat = 0.12) {
        wantsLayer = true
        layer?.cornerRadius = radius
        layer?.backgroundColor = fill.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(border).cgColor
    }
}

// 글자만 있는 작은 버튼 (지우기 등)
final class TextButton: NSButton {
    init(_ title: String, size: CGFloat = 11, alpha: CGFloat = 0.45) {
        super.init(frame: .zero)
        isBordered = false
        setButtonType(.momentaryChange)
        attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: size), .foregroundColor: NSColor.white.withAlphaComponent(alpha)])
    }
    required init?(coder: NSCoder) { fatalError() }
    override var mouseDownCanMoveWindow: Bool { false }
}

// 채운 버튼 (메뉴에 추가 · 닫기 · 열기)
final class FillButton: NSButton {
    init(_ title: String, fill: NSColor, text: NSColor, weight: NSFont.Weight = .semibold) {
        super.init(frame: .zero)
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = fill.cgColor
        attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: weight), .foregroundColor: text])
    }
    required init?(coder: NSCoder) { fatalError() }
    override var mouseDownCanMoveWindow: Bool { false }
    var fitWidth: CGFloat { ceil(attributedTitle.size().width) + 28 }
}

// 목록 한 줄: 아이콘 · 제목 · 보조 글 · (선택) 지우기 ✕
final class RowView: NSView {
    var onClick: (() -> Void)?
    var onRemove: (() -> Void)?
    var onHover: (() -> Void)?
    var highlighted = false { didSet { refresh() } }

    private let icon = NSImageView()
    private let title: NSTextField
    private let detail: NSTextField
    private let enterMark = label("↩", size: 12, alpha: 0.45)
    private var remove: HoverButton?
    private var area: NSTrackingArea?
    private let hasIcon: Bool
    private let showsEnter: Bool

    init(title t: String, detail d: String?, iconName: String?, removable: Bool, showsEnter: Bool) {
        title = label(t, size: d == nil ? 14 : 13, weight: d == nil ? .regular : .medium, alpha: 0.9)
        detail = label(d ?? "", size: 12, alpha: 0.45)
        hasIcon = iconName != nil
        self.showsEnter = showsEnter
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        if let iconName {
            icon.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 12, weight: .regular))
            icon.contentTintColor = NSColor.white.withAlphaComponent(0.5)
            addSubview(icon)
        }
        addSubview(title)
        if d != nil { addSubview(detail) }
        addSubview(enterMark)
        if removable {
            let b = HoverButton()
            b.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: L("지우기", "Remove"))?
                .withSymbolConfiguration(.init(pointSize: 9, weight: .semibold))
            b.imagePosition = .imageOnly
            b.layer?.cornerRadius = 6
            b.contentTintColor = NSColor.white.withAlphaComponent(0.6)
            b.target = self
            b.action = #selector(removeTapped)
            addSubview(b)
            remove = b
        }
        refresh()
    }
    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func layout() {
        super.layout()
        let h = bounds.height
        var x: CGFloat = 10
        if hasIcon {
            icon.frame = NSRect(x: x, y: (h - 14) / 2, width: 14, height: 14)
            x += 24
        }
        var right = bounds.width - 6
        if let remove {
            remove.frame = NSRect(x: right - 24, y: (h - 24) / 2, width: 24, height: 24)
            right -= 30
        } else if showsEnter {
            enterMark.sizeToFit()
            enterMark.frame.origin = NSPoint(x: right - enterMark.frame.width - 4, y: (h - enterMark.frame.height) / 2)
            right -= enterMark.frame.width + 12
        }
        title.sizeToFit()
        let tw = min(title.frame.width, right - x)
        title.frame = NSRect(x: x, y: ((h - title.frame.height) / 2).rounded(), width: tw, height: title.frame.height)
        if detail.superview != nil {
            detail.sizeToFit()
            let dx = title.frame.maxX + 8
            detail.frame = NSRect(x: dx, y: title.frame.minY + 1, width: max(0, right - dx), height: detail.frame.height)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let a = area { removeTrackingArea(a) }
        let a = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(a)
        area = a
    }
    override func mouseEntered(with event: NSEvent) { onHover?() }
    override func mouseDown(with event: NSEvent) { onClick?() }
    @objc private func removeTapped() { onRemove?() }

    private func refresh() {
        layer?.backgroundColor = NSColor.white.withAlphaComponent(highlighted ? 0.10 : 0).cgColor
        enterMark.isHidden = !(showsEnter && highlighted)
        title.textColor = NSColor.white.withAlphaComponent(highlighted ? 1 : 0.85)
    }
}

// 포커스를 받는 순간을 알려 주는 입력 칸. 커서도 노란색으로 바꾼다.
final class FocusField: NSTextField {
    var onFocus: (() -> Void)?
    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok {
            (currentEditor() as? NSTextView)?.insertionPointColor = peekYellow
            onFocus?()
        }
        return ok
    }
}

// 둥근 상자 안의 입력 칸. 포커스를 받으면 노란 테두리를 두른다.
final class BoxField: NSView {
    let field = FocusField()
    var focused = false { didSet { refresh() } }

    init(placeholder: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 9
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 14)
        field.textColor = .white
        field.cell?.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.placeholderAttributedString = NSAttributedString(string: placeholder, attributes: [
            .font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.white.withAlphaComponent(0.35)])
        field.onFocus = { [weak self] in self?.focused = true }
        addSubview(field)
        refresh()
    }
    required init?(coder: NSCoder) { fatalError() }

    override var mouseDownCanMoveWindow: Bool { false }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(field) }

    override func layout() {
        super.layout()
        field.frame = NSRect(x: 12, y: ((bounds.height - 20) / 2).rounded(), width: bounds.width - 24, height: 20)
    }

    private func refresh() {
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = (focused ? peekYellow.withAlphaComponent(0.7) : NSColor.white.withAlphaComponent(0.12)).cgColor
        layer?.shadowColor = peekYellow.cgColor
        layer?.shadowOpacity = focused ? 0.35 : 0
        layer?.shadowRadius = 3
        layer?.shadowOffset = .zero
    }
}

/// 주소를 목록에 보여 줄 때 앞의 https://, www. 와 끝의 / 를 뗀다
func displayURL(_ s: String) -> String {
    var t = s
    for p in ["https://", "http://"] where t.hasPrefix(p) { t.removeFirst(p.count) }
    if t.hasPrefix("www.") { t.removeFirst(4) }
    if t.hasSuffix("/") { t.removeLast() }
    return t
}
