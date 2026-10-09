import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    var player: PlayerController!
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)   // Dock 아이콘 없이 메뉴막대 상주
        buildMainMenu()

        player = PlayerController()
        player.show()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "play.rectangle.on.rectangle",
                                           accessibilityDescription: "Peek")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    // MARK: - 메뉴막대 메뉴

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let services = NSMenu()
        player.fillServiceMenu(services)

        let svcRoot = NSMenuItem(title: L("서비스 열기", "Open Service"), action: nil, keyEquivalent: "")
        svcRoot.submenu = services
        menu.addItem(svcRoot)
        menu.addItem(.separator())

        func toggle(_ title: String, _ on: Bool, _ sel: Selector) {
            let it = NSMenuItem(title: title, action: sel, keyEquivalent: "")
            it.target = self
            it.state = on ? .on : .off
            menu.addItem(it)
        }
        toggle(L("항상 위에 표시", "Keep on Top"), Prefs.pinned, #selector(togglePin))
        toggle(L("다른 앱 전체화면 위에도", "Show over Full-Screen Apps"), Prefs.aboveFullscreen, #selector(toggleAboveFS))
        toggle(L("16:9 비율 고정", "Lock 16:9 Aspect Ratio"), Prefs.lockAspect, #selector(toggleAspect))
        toggle(L("광고 차단 (YouTube·Twitch)", "Block Ads (YouTube · Twitch)"), Prefs.adBlock, #selector(toggleAdBlock))

        let opac = NSMenu()
        for v in [1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4] {
            let it = NSMenuItem(title: "\(Int(v * 100))%", action: #selector(setOpacity(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = v
            it.state = abs(Prefs.opacity - v) < 0.01 ? .on : .off
            opac.addItem(it)
        }
        let opacRoot = NSMenuItem(title: L("투명도", "Opacity"), action: nil, keyEquivalent: "")
        opacRoot.submenu = opac
        menu.addItem(opacRoot)

        menu.addItem(.separator())
        let showIt = NSMenuItem(title: L("창 보이기", "Show Window"), action: #selector(showWindow), keyEquivalent: "")
        showIt.target = self
        menu.addItem(showIt)
        let quit = NSMenuItem(title: L("Peek 종료", "Quit Peek"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    @objc private func openURL() { player.promptURL() }
    @objc private func showWindow() { player.show() }
    @objc private func togglePin() { player.togglePin() }
    @objc private func toggleAboveFS() { Prefs.aboveFullscreen.toggle(); player.applyPin() }
    @objc private func toggleAspect() { Prefs.lockAspect.toggle(); player.applyAspect() }
    @objc private func toggleAdBlock() { Prefs.adBlock.toggle(); player.applyAdBlock(reload: true) }
    @objc private func setOpacity(_ sender: NSMenuItem) {
        guard let v = sender.representedObject as? Double else { return }
        Prefs.opacity = v
        player.applyOpacity()
    }

    // MARK: - 단축키용 메인 메뉴

    private func buildMainMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L("Peek 종료", "Quit Peek"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let ctrlItem = NSMenuItem()
        let ctrl = NSMenu(title: L("제어", "Controls"))
        func add(_ title: String, _ key: String, _ sel: Selector, _ mods: NSEvent.ModifierFlags = [.command]) {
            let it = NSMenuItem(title: title, action: sel, keyEquivalent: key)
            it.keyEquivalentModifierMask = mods
            it.target = self
            ctrl.addItem(it)
        }
        add(L("주소 열기", "Open URL"), "l", #selector(openURL))
        add(L("새로고침", "Reload"), "r", #selector(reload))
        add(L("영상만 채우기", "Fit Video to Window"), "e", #selector(videoFS))
        add(L("항상 위 토글", "Toggle Keep on Top"), "t", #selector(togglePin))
        add(L("창 닫기", "Close Window"), "w", #selector(hideWindow))
        ctrlItem.submenu = ctrl
        main.addItem(ctrlItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: L("편집", "Edit"))
        edit.addItem(withTitle: L("잘라내기", "Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: L("복사", "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: L("붙여넣기", "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: L("전체 선택", "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        NSApp.mainMenu = main
    }

    @objc private func reload() { player.reloadPage() }
    @objc private func videoFS() { player.toggleVideoFS() }
    @objc private func hideWindow() { player.closePanel() }
}
