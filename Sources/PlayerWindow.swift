import Cocoa
import WebKit

// 그림자 막·말풍선처럼 보이기만 하고 클릭은 아래 웹뷰로 흘려보내는 뷰
class PassthroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let v = super.hitTest(point)
        return v === self ? nil : v
    }
}

// 툴바 줄. 버튼이 없는 빈 곳을 잡고 끌면 창이 움직인다.
final class TopBar: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
    override var mouseDownCanMoveWindow: Bool { true }
}

// 위쪽 그라데이션 막. 레이어 크기를 뷰에 맞춰 둔다.
final class ScrimView: PassthroughView {
    private let gradient = CAGradientLayer()
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        gradient.colors = [NSColor.black.withAlphaComponent(0.85).cgColor,
                           NSColor.black.withAlphaComponent(0.55).cgColor,
                           NSColor.black.withAlphaComponent(0).cgColor]
        gradient.locations = [0, 0.5, 1]
        // AppKit 좌표는 아래가 0이라 위(1)에서 아래(0)로 흐르게 한다
        gradient.startPoint = CGPoint(x: 0.5, y: 1)
        gradient.endPoint = CGPoint(x: 0.5, y: 0)
        layer?.addSublayer(gradient)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        CATransaction.commit()
    }
}

// 마우스를 올리면 뒤가 밝아지는 툴바 버튼
final class HoverButton: NSButton {
    var restAlpha: CGFloat = 0 { didSet { refresh() } }
    var hoverAlpha: CGFloat = 0.14
    var tip: (name: String, key: String?)?
    var onHover: ((HoverButton, Bool) -> Void)?
    private var area: NSTrackingArea?
    private var hovering = false

    init() {
        super.init(frame: .zero)
        isBordered = false
        bezelStyle = .regularSquare
        setButtonType(.momentaryChange)
        focusRingType = .none
        wantsLayer = true
        layer?.cornerRadius = 7
        contentTintColor = NSColor.white.withAlphaComponent(0.88)
    }
    required init?(coder: NSCoder) { fatalError() }

    override var mouseDownCanMoveWindow: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let a = area { removeTrackingArea(a) }
        let a = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                               owner: self, userInfo: nil)
        addTrackingArea(a)
        area = a
    }

    override func mouseEntered(with event: NSEvent) { hovering = true; refresh(); onHover?(self, true) }
    override func mouseExited(with event: NSEvent) { hovering = false; refresh(); onHover?(self, false) }

    func resetHover() { hovering = false; refresh() }

    private func refresh() {
        layer?.backgroundColor = NSColor.white.withAlphaComponent(hovering ? max(hoverAlpha, restAlpha + 0.08) : restAlpha).cgColor
    }
}

// 버튼 아래 뜨는 이름·단축키 말풍선
final class TipView: PassthroughView {
    private let label = NSTextField(labelWithString: "")
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.backgroundColor = NSColor(calibratedRed: 28/255, green: 28/255, blue: 30/255, alpha: 0.92).cgColor
        shadow = NSShadow()
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.35
        layer?.shadowRadius = 6
        layer?.shadowOffset = CGSize(width: 0, height: -4)
        addSubview(label)
    }
    required init?(coder: NSCoder) { fatalError() }

    func set(name: String, key: String?) {
        let t = NSMutableAttributedString(string: name, attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white])
        if let key {
            t.append(NSAttributedString(string: "  " + key, attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.white.withAlphaComponent(0.55)]))
        }
        label.attributedStringValue = t
        label.sizeToFit()
        setFrameSize(NSSize(width: ceil(label.frame.width) + 16, height: 24))
        label.setFrameOrigin(NSPoint(x: 8, y: ((24 - label.frame.height) / 2).rounded()))
    }
}

// 마우스 진입/이동/이탈을 컨트롤러로 넘기는 컨테이너
final class HoverView: NSView {
    var onHover: ((NSPoint?) -> Void)?
    var onLayout: (() -> Void)?
    private var area: NSTrackingArea?

    override func layout() {
        super.layout()
        onLayout?()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let a = area { removeTrackingArea(a) }
        let a = NSTrackingArea(rect: bounds,
                               options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                               owner: self, userInfo: nil)
        addTrackingArea(a)
        area = a
    }

    private func point(_ e: NSEvent) -> NSPoint { convert(e.locationInWindow, from: nil) }
    override func mouseEntered(with event: NSEvent) { onHover?(point(event)) }
    override func mouseMoved(with event: NSEvent) { onHover?(point(event)) }
    override func mouseExited(with event: NSEvent) { onHover?(nil) }
}

// 주소 입력 화면의 어두운 막. 막을 누르면 닫는다.
final class DimView: NSView {
    var onClick: (() -> Void)?
    override func mouseDown(with event: NSEvent) { onClick?() }
    override var mouseDownCanMoveWindow: Bool { false }
}

// 주소 칸 상자. 안쪽 클릭이 막으로 새지 않게 막는다.
final class SheetView: NSView {
    override func mouseDown(with event: NSEvent) {}
    override var mouseDownCanMoveWindow: Bool { false }
}

final class FloatPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class PlayerController: NSObject, WKNavigationDelegate, WKUIDelegate, NSWindowDelegate, NSTextFieldDelegate {

    static let safariUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Safari/605.1.15"

    let panel: FloatPanel
    let web: WKWebView
    private let container = HoverView()
    private let chrome = PassthroughView()     // 막 + 툴바 + 말풍선을 한꺼번에 띄우고 숨긴다
    private let scrim = ScrimView()
    private let bar = TopBar()
    private let tipView = TipView()
    private var barVisible = false
    private var menuOpen = false
    private var hideTimer: Timer?
    private var tipTimer: Timer?
    private let barHeight: CGFloat = 44
    private let scrimHeight: CGFloat = 110
    private let slideOffset: CGFloat = 6       // 나타날 때 위에서 내려오는 거리
    private let showZone: CGFloat = 12         // 창 맨 위 끝에 닿을 때만 연다 (페이지 상단 버튼을 가리지 않게)
    private let keepZone: CGFloat = 60         // 열린 뒤에는 툴바 줄 + 여유까지만 유지한다
    private let hideDelay: TimeInterval = 0.6

    private var closeButton: HoverButton!
    private var serviceButton: HoverButton!
    private var backButton: HoverButton!
    private var reloadButton: HoverButton!
    private let divider = NSView()
    private var fillButton: HoverButton!
    private var opacityButton: HoverButton!
    private var pinButton: HoverButton!
    private var urlObservation: NSKeyValueObservation?
    private var ruleList: WKContentRuleList?

    // 주소 입력 화면
    private let urlDim = DimView()
    private let urlGlow = NSView()
    private let urlSheet = SheetView()
    private let urlField = NSTextField()
    private let urlOpen = NSButton()
    private let urlHint = NSTextField(labelWithString: "")
    private let urlGlobe = NSImageView()
    private let recentCard = CardView()
    private var recentItems: [String] = []
    private var recentRows: [RowView] = []
    private var recentIndex = -1
    private var urlPrefill = ""

    // 사이트 추가 화면
    private let siteDim = DimView()
    private let siteCard = CardView()
    private let siteTitle = label(L("사이트 추가", "Add Site"), size: 15, weight: .semibold)
    private let nameLabel = label(L("이름", "Name"), size: 11, weight: .semibold, alpha: 0.5)
    private let addrLabel = label(L("주소", "URL"), size: 11, weight: .semibold, alpha: 0.5)
    private let nameBox = BoxField(placeholder: L("메뉴에 보일 이름", "Name shown in the menu"))
    private let addrBox = BoxField(placeholder: "youtube.com/@channel")
    private let siteClose = FillButton(L("닫기", "Close"), fill: NSColor.white.withAlphaComponent(0.10),
                                       text: NSColor.white.withAlphaComponent(0.9), weight: .medium)
    private let siteAdd = FillButton(L("메뉴에 추가", "Add to Menu"), fill: peekYellow,
                                     text: NSColor(calibratedRed: 17/255, green: 17/255, blue: 20/255, alpha: 1))
    private let siteDivider = NSView()
    private let mySitesLabel = label(L("내 사이트", "My Sites"), size: 11, weight: .semibold, alpha: 0.5)
    private var siteRows: [RowView] = []

    override init() {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()                       // 로그인 유지
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.allowsAirPlayForMediaPlayback = true
        cfg.preferences.setValue(true, forKey: "allowsPictureInPictureMediaPlayback")
        cfg.preferences.isElementFullscreenEnabled = false      // 네이티브 전체화면 대신 창 안 전체화면
        cfg.userContentController.addUserScript(
            WKUserScript(source: Shim.fullscreen, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
        cfg.userContentController.addUserScript(
            WKUserScript(source: AdBlock.skipScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )

        web = WKWebView(frame: .zero, configuration: cfg)
        web.customUserAgent = PlayerController.safariUA
        web.allowsBackForwardNavigationGestures = true
        web.setValue(false, forKey: "drawsBackground")
        if #available(macOS 13.3, *) { web.isInspectable = true }

        let saved = PlayerController.savedFrame()
        panel = FloatPanel(contentRect: saved,
                           styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                           backing: .buffered, defer: false)
        super.init()

        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = false          // 순서 주의: 이 값을 나중에 켜면 hidesOnDeactivate가 되살아난다
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .black
        panel.delegate = self
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.minSize = NSSize(width: 320, height: 200)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        buildUI()
        applyPin()
        applyOpacity()
        applyAspect()

        web.navigationDelegate = self
        web.uiDelegate = self

        AdBlock.compile { [weak self] list in
            guard let self else { return }
            self.ruleList = list
            self.applyAdBlock(reload: false)
        }

        load(Prefs.lastURL)
    }

    // MARK: - UI

    private static let opacitySteps: [Double] = [1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4]

    private func symbol(_ name: String, _ size: CGFloat = 13) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: size, weight: .medium))
    }

    private func buildUI() {
        container.frame = panel.contentLayoutRect
        container.autoresizingMask = [.width, .height]
        container.addSubview(web)

        chrome.wantsLayer = true
        chrome.alphaValue = 0
        chrome.isHidden = true
        chrome.addSubview(scrim)
        chrome.addSubview(bar)
        tipView.isHidden = true
        chrome.addSubview(tipView)
        container.addSubview(chrome)
        buildURLSheet()
        buildSiteSheet()

        func iconButton(_ sym: String, _ name: String, _ key: String?, _ sel: Selector, size: CGFloat = 13) -> HoverButton {
            let b = HoverButton()
            b.image = symbol(sym, size)
            b.imagePosition = .imageOnly
            b.tip = (name, key)
            b.setAccessibilityLabel(name)
            b.target = self
            b.action = sel
            b.onHover = { [weak self] b, inside in self?.buttonHover(b, inside) }
            bar.addSubview(b)
            return b
        }

        closeButton  = iconButton("xmark", L("닫기", "Close"), "⌘W", #selector(closePanel), size: 12)
        backButton   = iconButton("chevron.left", L("뒤로", "Back"), nil, #selector(goBack))
        reloadButton = iconButton("arrow.clockwise", L("새로고침", "Reload"), "⌘R", #selector(reloadPage), size: 12)
        fillButton   = iconButton("viewfinder", L("영상만 채우기", "Fit video"), "⌘E", #selector(toggleVideoFS))
        pinButton    = iconButton("pin.fill", L("항상 위", "Keep on top"), "⌘T", #selector(togglePin), size: 12)

        serviceButton = iconButton("chevron.down", L("서비스 바꾸기", "Switch service"), nil, #selector(showServiceMenu(_:)), size: 9)
        serviceButton.imagePosition = .imageTrailing
        serviceButton.restAlpha = 0.14
        serviceButton.hoverAlpha = 0.22
        serviceButton.tip = nil
        serviceButton.contentTintColor = NSColor.white.withAlphaComponent(0.6)

        opacityButton = iconButton("circle.lefthalf.filled", L("투명도", "Opacity"), nil, #selector(showOpacityMenu(_:)))
        opacityButton.imagePosition = .imageLeading

        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.2).cgColor
        bar.addSubview(divider)

        panel.contentView = container
        container.onLayout = { [weak self] in self?.relayout() }
        container.onHover = { [weak self] p in self?.handleHover(p) }

        // 링크 이동·SPA 이동 모두 따라가며 서비스 이름을 맞춘다
        urlObservation = web.observe(\.url, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.updateServiceTitle() }
        }
        updateServiceTitle()
    }

    private func setTitle(_ b: HoverButton, _ text: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat) {
        b.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: NSColor.white.withAlphaComponent(alpha)])
    }

    private func updateServiceTitle() {
        let name = Catalog.match(web.url)?.name
            ?? web.url?.host?.replacingOccurrences(of: "www.", with: "")
            ?? "Peek"
        setTitle(serviceButton, name + " ", size: 13, weight: .semibold, alpha: 1)
        layoutBar()
    }

    /// 웹뷰는 언제나 창 전체. 막과 툴바는 그 위에 뜨는 오버레이라 화면이 밀리지 않는다.
    private func relayout() {
        let b = container.bounds
        web.frame = b
        chrome.frame = NSRect(x: 0, y: b.height - scrimHeight + (barVisible ? 0 : slideOffset),
                              width: b.width, height: scrimHeight)
        scrim.frame = chrome.bounds
        bar.frame = NSRect(x: 0, y: scrimHeight - barHeight, width: b.width, height: barHeight)
        layoutBar()
        layoutURLSheet()
        layoutSiteSheet()
    }

    private func layoutBar() {
        guard closeButton != nil else { return }
        let w = bar.bounds.width, size: CGFloat = 28
        let y = ((barHeight - size) / 2).rounded()

        // 오른쪽부터 채운다: 핀 · 투명도 · 채우기 │ 새로고침 · 뒤로
        var x = w - 10
        func placeRight(_ v: NSView, _ width: CGFloat, gap: CGFloat = 2) {
            x -= width
            v.frame = NSRect(x: x, y: y, width: width, height: size)
            x -= gap
        }
        placeRight(pinButton, size)
        opacityButton.sizeToFit()
        placeRight(opacityButton, ceil(opacityButton.frame.width) + 16)
        placeRight(fillButton, size, gap: 0)
        x -= 13
        divider.frame = NSRect(x: x + 6, y: ((barHeight - 16) / 2).rounded(), width: 1, height: 16)
        placeRight(reloadButton, size)
        placeRight(backButton, size)

        closeButton.frame = NSRect(x: 10, y: y, width: size, height: size)
        let sx = closeButton.frame.maxX + 6
        serviceButton.sizeToFit()
        let sw = min(ceil(serviceButton.frame.width) + 18, max(60, x - 8 - sx))
        serviceButton.frame = NSRect(x: sx, y: y, width: sw, height: size)
    }

    // MARK: 호버 판정

    private func handleHover(_ p: NSPoint?) {
        guard let p else { scheduleHide(); return }
        let fromTop = container.bounds.height - p.y
        if fromTop <= showZone {
            showBar()
        } else if barVisible && fromTop <= keepZone {
            cancelHide()
        } else {
            scheduleHide()
        }
    }

    /// 메뉴가 닫힌 뒤처럼 이벤트 없이 상태가 바뀌었을 때 현재 마우스 위치로 다시 판정한다
    private func reevaluateHover() {
        let p = container.convert(panel.mouseLocationOutsideOfEventStream, from: nil)
        handleHover(container.bounds.contains(p) ? p : nil)
    }

    private func cancelHide() {
        hideTimer?.invalidate()
        hideTimer = nil
    }

    private func scheduleHide() {
        guard barVisible, !menuOpen, hideTimer == nil else { return }
        hideTimer = Timer.scheduledTimer(withTimeInterval: hideDelay, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.hideTimer = nil
            self.hideBar()
        }
    }

    private func showBar() {
        cancelHide()
        guard !barVisible else { return }
        barVisible = true
        if chrome.isHidden {
            chrome.isHidden = false
            chrome.alphaValue = 0
        }
        let target = chrome.frame.offsetBy(dx: 0, dy: -(chrome.frame.minY - (container.bounds.height - scrimHeight)))
        NSAnimationContext.runAnimationGroup { c in
            c.duration = 0.18
            c.timingFunction = CAMediaTimingFunction(name: .easeOut)
            chrome.animator().alphaValue = 1
            chrome.animator().frame = target
        }
    }

    private func hideBar() {
        guard barVisible, !menuOpen else { return }
        barVisible = false
        hideTip()
        let target = NSRect(x: 0, y: container.bounds.height - scrimHeight + slideOffset,
                            width: container.bounds.width, height: scrimHeight)
        NSAnimationContext.runAnimationGroup({ c in
            c.duration = 0.2
            c.timingFunction = CAMediaTimingFunction(name: .easeIn)
            chrome.animator().alphaValue = 0
            chrome.animator().frame = target
        }, completionHandler: { [weak self] in
            // 숨는 도중 다시 열렸으면 그대로 둔다
            guard let self, !self.barVisible else { return }
            self.chrome.isHidden = true
        })
    }

    // MARK: 말풍선

    private func buttonHover(_ b: HoverButton, _ inside: Bool) {
        tipTimer?.invalidate()
        guard inside, let tip = b.tip else { hideTip(); return }
        tipTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self, self.barVisible, !self.menuOpen else { return }
            self.tipView.set(name: tip.name, key: tip.key)
            let f = self.bar.convert(b.frame, to: self.chrome)
            let w = self.tipView.frame.width
            let x = min(max(8, f.midX - w / 2), self.chrome.bounds.width - w - 8)
            self.tipView.setFrameOrigin(NSPoint(x: x.rounded(), y: f.minY - 4 - 24))
            self.tipView.isHidden = false
        }
    }

    private func hideTip() {
        tipTimer?.invalidate()
        tipView.isHidden = true
    }

    // MARK: 툴바 메뉴

    private func popUp(_ menu: NSMenu, below b: HoverButton) {
        hideTip()
        menu.appearance = NSAppearance(named: .darkAqua)
        menuOpen = true
        cancelHide()
        let at = NSPoint(x: b.frame.minX, y: b.frame.minY - 4)
        menu.popUp(positioning: nil, at: at, in: bar)   // 메뉴가 닫힐 때까지 여기서 멈춘다
        menuOpen = false
        b.resetHover()
        reevaluateHover()
    }

    @objc private func showServiceMenu(_ sender: HoverButton) {
        let menu = NSMenu()
        fillServiceMenu(menu)
        popUp(menu, below: sender)
    }

    /// 툴바와 메뉴막대가 함께 쓰는 서비스 목록: 기본 서비스 · 내 사이트 · 사이트 추가 · 주소 입력
    func fillServiceMenu(_ menu: NSMenu) {
        let current = Catalog.match(web.url)?.id
        func add(_ s: Service) {
            let it = NSMenuItem(title: s.name, action: #selector(pickService(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = s.url
            it.state = s.id == current ? .on : .off
            menu.addItem(it)
        }
        for (i, group) in Catalog.groups.enumerated() {
            if i > 0 { menu.addItem(.separator()) }
            group.compactMap(Catalog.service(id:)).forEach(add)
        }
        let mine = Catalog.mine
        if !mine.isEmpty {
            menu.addItem(.separator())
            if #available(macOS 14.0, *) {
                menu.addItem(.sectionHeader(title: L("내 사이트", "My Sites")))
            } else {
                let h = NSMenuItem(title: L("내 사이트", "My Sites"), action: nil, keyEquivalent: "")
                h.isEnabled = false
                menu.addItem(h)
            }
            mine.forEach(add)
        }
        menu.addItem(.separator())
        let addSite = NSMenuItem(title: L("사이트 추가…", "Add Site…"), action: #selector(openAddSite), keyEquivalent: "")
        addSite.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 11, weight: .medium))
        addSite.target = self
        menu.addItem(addSite)
        let custom = NSMenuItem(title: L("주소 직접 입력…", "Open URL…"), action: #selector(openURLPrompt), keyEquivalent: "l")
        custom.keyEquivalentModifierMask = [.command]
        custom.target = self
        menu.addItem(custom)
    }

    @objc private func showOpacityMenu(_ sender: HoverButton) {
        let menu = NSMenu()
        for v in PlayerController.opacitySteps {
            let it = NSMenuItem(title: "\(Int(v * 100))%", action: #selector(pickOpacity(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = v
            it.state = abs(Prefs.opacity - v) < 0.01 ? .on : .off
            menu.addItem(it)
        }
        popUp(menu, below: sender)
    }

    @objc private func pickService(_ sender: NSMenuItem) {
        guard let u = sender.representedObject as? String else { return }
        load(u)
        show()
    }

    @objc private func openURLPrompt() { promptURL() }

    @objc private func pickOpacity(_ sender: NSMenuItem) {
        guard let v = sender.representedObject as? Double else { return }
        Prefs.opacity = v
        applyOpacity()
    }

    // MARK: - 동작

    func load(_ urlString: String) {
        guard let u = URL(string: urlString) else { return }
        Prefs.lastURL = urlString
        web.load(URLRequest(url: u))
    }

    func show() {
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        // macOS 14부터 ignoringOtherApps는 무시되어 키 입력이 앞 앱으로 간다
        if #available(macOS 14.0, *) { NSApp.activate() } else { NSApp.activate(ignoringOtherApps: true) }
    }

    // MARK: - 주소 입력 화면

    private func buildURLSheet() {
        urlDim.wantsLayer = true
        urlDim.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor
        urlDim.isHidden = true
        urlDim.onClick = { [weak self] in self?.closeURLSheet() }
        container.addSubview(urlDim)

        // 칸 바깥의 노란 빛 테두리
        urlGlow.wantsLayer = true
        urlGlow.layer?.cornerRadius = 16
        urlGlow.layer?.backgroundColor = peekYellow.withAlphaComponent(0.18).cgColor
        urlDim.addSubview(urlGlow)

        urlSheet.wantsLayer = true
        urlSheet.layer?.cornerRadius = 12
        urlSheet.layer?.backgroundColor = NSColor(calibratedRed: 36/255, green: 36/255, blue: 40/255, alpha: 0.96).cgColor
        urlSheet.layer?.borderWidth = 1
        urlSheet.layer?.borderColor = NSColor.white.withAlphaComponent(0.14).cgColor
        urlDim.addSubview(urlSheet)

        urlGlobe.image = symbol("globe", 14)
        urlGlobe.contentTintColor = NSColor.white.withAlphaComponent(0.55)
        urlSheet.addSubview(urlGlobe)

        urlField.isBordered = false
        urlField.drawsBackground = false
        urlField.focusRingType = .none
        urlField.font = .systemFont(ofSize: 16)
        urlField.textColor = .white
        urlField.cell?.usesSingleLineMode = true
        urlField.cell?.isScrollable = true
        urlField.lineBreakMode = .byTruncatingTail
        urlField.placeholderAttributedString = NSAttributedString(
            string: L("주소를 입력하거나 붙여넣으세요", "Type or paste a URL"),
            attributes: [.font: NSFont.systemFont(ofSize: 16), .foregroundColor: NSColor.white.withAlphaComponent(0.4)])
        urlField.delegate = self
        urlSheet.addSubview(urlField)

        urlOpen.isBordered = false
        urlOpen.wantsLayer = true
        urlOpen.layer?.cornerRadius = 8
        urlOpen.layer?.backgroundColor = peekYellow.cgColor
        urlOpen.attributedTitle = NSAttributedString(string: L("열기 ↩", "Open ↩"), attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 17/255, green: 17/255, blue: 20/255, alpha: 1)])
        urlOpen.target = self
        urlOpen.action = #selector(submitURL)
        urlSheet.addSubview(urlOpen)

        recentCard.style(radius: 12, border: 0.10)
        urlDim.addSubview(recentCard)

        urlHint.font = .systemFont(ofSize: 12)
        urlHint.textColor = NSColor.white.withAlphaComponent(0.6)
        urlHint.alignment = .center
        urlDim.addSubview(urlHint)
    }

    private func layoutURLSheet() {
        let b = container.bounds
        urlDim.frame = b
        let w = min(480, b.width - 32), h: CGFloat = 48
        let hasRecent = !recentItems.isEmpty
        let top = max(16, (b.height * (hasRecent ? 0.16 : 0.29)).rounded())
        let f = NSRect(x: ((b.width - w) / 2).rounded(), y: b.height - top - h, width: w, height: h)
        urlSheet.frame = f
        urlGlow.frame = f.insetBy(dx: -4, dy: -4)
        urlGlobe.frame = NSRect(x: 16, y: (h - 16) / 2, width: 16, height: 16)
        urlOpen.sizeToFit()
        let ow = ceil(urlOpen.frame.width) + 24
        urlOpen.frame = NSRect(x: w - 8 - ow, y: (h - 32) / 2, width: ow, height: 32)
        let fh: CGFloat = 22
        urlField.frame = NSRect(x: 42, y: ((h - fh) / 2).rounded(), width: urlOpen.frame.minX - 10 - 42, height: fh)

        var below = f.minY - 10
        recentCard.isHidden = !hasRecent
        if hasRecent {
            // 창 높이에 들어가는 줄만 보인다
            let room = below - 40
            let fit = max(1, Int((room - 36) / 36))
            let shown = min(recentRows.count, fit)
            let ch = 6 + 24 + CGFloat(shown) * 36 + 6
            recentCard.frame = NSRect(x: f.minX, y: below - ch, width: w, height: ch)
            for (i, row) in recentRows.enumerated() {
                row.isHidden = i >= shown
                row.frame = NSRect(x: 6, y: 30 + CGFloat(i) * 36, width: w - 12, height: 36)
            }
            below = recentCard.frame.minY - 10
        }
        urlHint.stringValue = hasRecent
            ? L("↑↓ 고르기   ·   ↩ 열기   ·   esc 닫기", "↑↓ select   ·   ↩ open   ·   esc close")
            : L("esc 누르면 닫힙니다  ·  ⌘L로 언제든 열기", "esc to close  ·  ⌘L anytime")
        urlHint.frame = NSRect(x: f.minX, y: below - 16, width: w, height: 16)
    }

    /// 칸에 쓴 글자로 최근 주소를 거른다. 처음 채워 둔 현재 주소 그대로면 전부 보인다.
    private func refreshRecent() {
        let q = urlField.stringValue.trimmingCharacters(in: .whitespaces).lowercased()
        let all = Prefs.recentURLs
        recentItems = (q.isEmpty || urlField.stringValue == urlPrefill)
            ? all
            : all.filter { $0.lowercased().contains(q) }
        recentIndex = -1
        recentCard.subviews.forEach { $0.removeFromSuperview() }
        let head = label(L("최근 연 주소", "Recent"), size: 11, weight: .semibold, alpha: 0.45)
        head.frame = NSRect(x: 16, y: 12, width: 200, height: 14)
        recentCard.addSubview(head)
        let clear = TextButton(L("지우기", "Clear"))
        clear.target = self
        clear.action = #selector(clearRecent)
        clear.sizeToFit()
        clear.frame = NSRect(x: min(480, container.bounds.width - 32) - 16 - clear.frame.width, y: 10,
                             width: clear.frame.width, height: 18)
        recentCard.addSubview(clear)
        recentRows = recentItems.enumerated().map { i, u in
            let r = RowView(title: displayURL(u), detail: nil, iconName: "clock", removable: false, showsEnter: true)
            r.onClick = { [weak self] in self?.openRecent(i) }
            r.onHover = { [weak self] in self?.selectRecent(i) }
            recentCard.addSubview(r)
            return r
        }
        layoutURLSheet()
    }

    private func selectRecent(_ i: Int) {
        recentIndex = i
        for (j, r) in recentRows.enumerated() { r.highlighted = j == i }
    }

    private func openRecent(_ i: Int) {
        guard recentItems.indices.contains(i) else { return }
        urlField.stringValue = recentItems[i]
        submitURL()
    }

    @objc private func clearRecent() {
        Prefs.recentURLs = []
        refreshRecent()
        panel.makeFirstResponder(urlField)
    }

    func promptURL() {
        closeSiteSheet()
        show()
        hideTip()
        urlPrefill = web.url?.absoluteString ?? ""
        urlField.stringValue = urlPrefill
        refreshRecent()
        urlDim.alphaValue = 0
        urlDim.isHidden = false
        NSAnimationContext.runAnimationGroup { c in
            c.duration = 0.15
            urlDim.animator().alphaValue = 1
        }
        panel.makeFirstResponder(urlField)
        (urlField.currentEditor() as? NSTextView)?.insertionPointColor = peekYellow
        urlField.currentEditor()?.selectAll(nil)
    }

    private func closeURLSheet() {
        guard !urlDim.isHidden else { return }
        panel.makeFirstResponder(web)
        NSAnimationContext.runAnimationGroup({ c in
            c.duration = 0.12
            urlDim.animator().alphaValue = 0
        }, completionHandler: { [weak self] in self?.urlDim.isHidden = true })
    }

    @objc private func submitURL() {
        var s = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        closeURLSheet()
        guard !s.isEmpty else { return }
        if !s.hasPrefix("http://") && !s.hasPrefix("https://") { s = "https://" + s }
        Prefs.addRecent(s)
        load(s)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        let f = obj.object as? NSTextField
        if f === nameBox.field { nameBox.focused = false }
        if f === addrBox.field { addrBox.focused = false }
    }

    func controlTextDidChange(_ obj: Notification) {
        if (obj.object as? NSTextField) === urlField { refreshRecent() }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
        if control === urlField {
            switch sel {
            case #selector(NSResponder.insertNewline(_:)):
                if recentIndex >= 0 { openRecent(recentIndex) } else { submitURL() }
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                closeURLSheet(); return true
            case #selector(NSResponder.moveDown(_:)):
                guard !recentItems.isEmpty else { return false }
                selectRecent(min(recentIndex + 1, recentItems.count - 1)); return true
            case #selector(NSResponder.moveUp(_:)):
                guard !recentItems.isEmpty else { return false }
                selectRecent(max(recentIndex - 1, -1)); return true
            default: return false
            }
        }
        // 사이트 추가 화면의 두 칸
        switch sel {
        case #selector(NSResponder.insertNewline(_:)): addSite(); return true
        case #selector(NSResponder.cancelOperation(_:)): closeSiteSheet(); return true
        default: return false
        }
    }

    // MARK: - 사이트 추가 화면

    private func buildSiteSheet() {
        siteDim.wantsLayer = true
        siteDim.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor
        siteDim.isHidden = true
        siteDim.onClick = { [weak self] in self?.closeSiteSheet() }
        container.addSubview(siteDim)

        siteCard.style(radius: 14)
        siteCard.layer?.shadowColor = NSColor.black.cgColor
        siteCard.layer?.shadowOpacity = 0.55
        siteCard.layer?.shadowRadius = 30
        siteCard.layer?.shadowOffset = CGSize(width: 0, height: -24)
        siteDim.addSubview(siteCard)

        for v in [siteTitle, nameLabel, addrLabel, nameBox, addrBox, siteClose, siteAdd, siteDivider, mySitesLabel] as [NSView] {
            siteCard.addSubview(v)
        }
        nameBox.field.delegate = self
        addrBox.field.delegate = self
        nameBox.field.nextKeyView = addrBox.field
        addrBox.field.nextKeyView = nameBox.field
        siteClose.target = self
        siteClose.action = #selector(closeSiteSheet)
        siteAdd.target = self
        siteAdd.action = #selector(addSite)
        siteDivider.wantsLayer = true
        siteDivider.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.10).cgColor
    }

    private func layoutSiteSheet() {
        let b = container.bounds
        siteDim.frame = b
        let w = min(420, b.width - 32), inner = w - 36
        var y: CGFloat = 18
        siteTitle.frame = NSRect(x: 18, y: y, width: inner, height: 20); y += 20 + 12
        nameLabel.frame = NSRect(x: 18, y: y, width: inner, height: 14); y += 14 + 6
        nameBox.frame = NSRect(x: 18, y: y, width: inner, height: 36); y += 36 + 12
        addrLabel.frame = NSRect(x: 18, y: y, width: inner, height: 14); y += 14 + 6
        addrBox.frame = NSRect(x: 18, y: y, width: inner, height: 36); y += 36 + 14
        let aw = siteAdd.fitWidth, cw = siteClose.fitWidth
        siteAdd.frame = NSRect(x: w - 18 - aw, y: y, width: aw, height: 30)
        siteClose.frame = NSRect(x: siteAdd.frame.minX - 8 - cw, y: y, width: cw, height: 30)
        y += 30

        let hasSites = !siteRows.isEmpty
        siteDivider.isHidden = !hasSites
        mySitesLabel.isHidden = !hasSites
        if hasSites {
            y += 14
            siteDivider.frame = NSRect(x: 18, y: y, width: inner, height: 1); y += 1 + 12
            mySitesLabel.frame = NSRect(x: 18, y: y, width: inner, height: 14); y += 14 + 6
            // 창 높이에 들어가는 줄만 보인다
            let room = b.height - 32 - y - 18
            let fit = max(1, Int(room / 34))
            for (i, row) in siteRows.enumerated() {
                row.isHidden = i >= fit
                row.frame = NSRect(x: 18, y: y + CGFloat(i) * 34, width: inner, height: 32)
            }
            y += CGFloat(min(siteRows.count, fit)) * 34 - 2
        }
        y += 18
        let top = max(16, ((b.height - y) / 2 - 20).rounded())
        siteCard.frame = NSRect(x: ((b.width - w) / 2).rounded(), y: b.height - top - y, width: w, height: y)
    }

    private func refreshSites() {
        siteRows.forEach { $0.removeFromSuperview() }
        siteRows = Prefs.mySites.enumerated().map { i, site in
            let r = RowView(title: site.name, detail: displayURL(site.url), iconName: nil, removable: true, showsEnter: false)
            r.onHover = { [weak self] in self?.siteRows.enumerated().forEach { $1.highlighted = $0 == i } }
            r.onRemove = { [weak self] in self?.removeSite(i) }
            r.onClick = { [weak self] in
                self?.closeSiteSheet()
                self?.load(site.url)
            }
            siteCard.addSubview(r)
            return r
        }
        layoutSiteSheet()
    }

    @objc private func openAddSite() {
        closeURLSheet()
        show()
        hideTip()
        nameBox.field.stringValue = web.title ?? ""
        addrBox.field.stringValue = web.url.map { displayURL($0.absoluteString) } ?? ""
        refreshSites()
        siteDim.alphaValue = 0
        siteDim.isHidden = false
        NSAnimationContext.runAnimationGroup { c in
            c.duration = 0.15
            siteDim.animator().alphaValue = 1
        }
        panel.makeFirstResponder(nameBox.field)
        nameBox.field.currentEditor()?.selectAll(nil)
    }

    @objc private func closeSiteSheet() {
        guard !siteDim.isHidden else { return }
        panel.makeFirstResponder(web)
        NSAnimationContext.runAnimationGroup({ c in
            c.duration = 0.12
            siteDim.animator().alphaValue = 0
        }, completionHandler: { [weak self] in self?.siteDim.isHidden = true })
    }

    @objc private func addSite() {
        let name = nameBox.field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        var url = addrBox.field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { NSSound.beep(); panel.makeFirstResponder(nameBox.field); return }
        guard !url.isEmpty else { NSSound.beep(); panel.makeFirstResponder(addrBox.field); return }
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") { url = "https://" + url }
        Prefs.mySites.append(Site(name: name, url: url))
        nameBox.field.stringValue = ""
        addrBox.field.stringValue = ""
        refreshSites()
        updateServiceTitle()
        panel.makeFirstResponder(nameBox.field)
    }

    private func removeSite(_ i: Int) {
        var list = Prefs.mySites
        guard list.indices.contains(i) else { return }
        list.remove(at: i)
        Prefs.mySites = list
        refreshSites()
        updateServiceTitle()
    }

    @objc func goBack() { if web.canGoBack { web.goBack() } }
    @objc func reloadPage() { web.reload() }
    @objc func closePanel() { panel.orderOut(nil) }

    @objc func toggleVideoFS() {
        web.evaluateJavaScript("window.__peekToggleVideoFS && window.__peekToggleVideoFS()", completionHandler: nil)
    }

    @objc func togglePin() {
        Prefs.pinned.toggle()
        applyPin()
    }

    func applyPin() {
        if Prefs.pinned {
            panel.level = Prefs.aboveFullscreen ? .screenSaver : .floating
        } else {
            panel.level = .normal
        }
        pinButton?.image = symbol(Prefs.pinned ? "pin.fill" : "pin.slash", 12)
        pinButton?.contentTintColor = Prefs.pinned
            ? NSColor(calibratedRed: 1, green: 0xD6/255.0, blue: 0x0A/255.0, alpha: 1)   // #FFD60A
            : NSColor.white.withAlphaComponent(0.88)
    }

    func applyOpacity() {
        panel.alphaValue = CGFloat(Prefs.opacity)
        guard let opacityButton else { return }
        setTitle(opacityButton, " \(Int((Prefs.opacity * 100).rounded()))%", size: 12, weight: .medium, alpha: 0.88)
        layoutBar()
    }

    func applyAdBlock(reload: Bool) {
        guard let list = ruleList else { return }
        let ucc = web.configuration.userContentController
        ucc.remove(list)
        if Prefs.adBlock { ucc.add(list) }
        if reload { web.reload() }
    }

    func applyAspect() {
        if Prefs.lockAspect {
            panel.contentAspectRatio = NSSize(width: 16, height: 9)
        } else {
            panel.resizeIncrements = NSSize(width: 1, height: 1)
        }
    }

    // MARK: - 창 위치 저장

    private static func savedFrame() -> NSRect {
        if let s = Prefs.frame {
            let r = NSRectFromString(s)
            if r.width > 200 && r.height > 150 { return r }
        }
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let w: CGFloat = 720, h: CGFloat = 405
        return NSRect(x: screen.maxX - w - 40, y: screen.minY + 40, width: w, height: h)
    }

    func windowDidMove(_ n: Notification) { Prefs.frame = NSStringFromRect(panel.frame) }
    func windowDidResize(_ n: Notification) { Prefs.frame = NSStringFromRect(panel.frame) }

    // MARK: - WebKit

    func webView(_ w: WKWebView, createWebViewWith cfg: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let u = action.request.url { w.load(URLRequest(url: u)) }
        return nil
    }

    func webView(_ w: WKWebView, didFail nav: WKNavigation!, withError error: Error) {
        NSLog("[peek] load failed: \(error.localizedDescription)")
    }
    func webView(_ w: WKWebView, didFailProvisionalNavigation nav: WKNavigation!, withError error: Error) {
        NSLog("[peek] provisional failed: \(error.localizedDescription)")
    }
    func webView(_ w: WKWebView, didFinish nav: WKNavigation!) {
        if let u = w.url?.absoluteString { Prefs.lastURL = u }
    }
}
