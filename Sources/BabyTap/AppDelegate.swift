import AppKit
import SpriteKit

// アプリ全体の制御。ウィンドウ作成、メニュー、メディアキーブロック、
// MultitouchSupport によるトラックパッド multi-touch 受信を統括する
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var skView: BabyTapView?
    private var scene: BabyTapScene?
    private let mediaKeyBlocker = MediaKeyBlocker()
    private var lastFingerTriggerById: [Int32: CFTimeInterval] = [:]
    private let fingerThrottle: CFTimeInterval = 0.08
    private var keyEventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()
        setupWindow()
        applyKioskPresentationOptions()
        installTrackpadMonitor()
        installKeyMonitor()
        mediaKeyBlocker.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        TrackpadMonitor.shared.stop()
        if let m = keyEventMonitor {
            NSEvent.removeMonitor(m)
            keyEventMonitor = nil
        }
        mediaKeyBlocker.stop()
    }

    // BabyTapView の keyDown が responder chain の関係で呼ばれないケース
    // に備えて、app 全体で .keyDown を拾う local monitor を張る
    private func installKeyMonitor() {
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // OS のキーリピートは無視
            if event.isARepeat { return event }
            // 修飾キー入りは終了ショートカットや menu accelerator を保護するためスルー
            let mods = event.modifierFlags
            if mods.contains(.command) || mods.contains(.control) || mods.contains(.option) {
                return event
            }
            self?.scene?.triggerRandom()
            return event
        }
    }

    // MultitouchSupport から直接トラックパッドの指データを受け取って
    // シーンへ反応を流す。macOS の gesture recognizer の影響を受けないので
    // 3 本指以上でも全部読める
    private func installTrackpadMonitor() {
        TrackpadMonitor.shared.onFingers = { [weak self] fingers in
            self?.handleFingers(fingers)
        }
        TrackpadMonitor.shared.start()
    }

    private func handleFingers(_ fingers: [MTFinger]) {
        guard let view = skView, let scene = scene else { return }
        let now = CACurrentMediaTime()
        let w = view.bounds.width
        let h = view.bounds.height
        for f in fingers {
            // state: 1=NotTracking, 2=StartInRange, 3=HoverInRange,
            //        4=MakeTouch, 5=Touching, 6=BreakTouch, 7=LingerInRange, 0=OutOfRange
            if f.state == 4 || f.state == 5 {
                let last = lastFingerTriggerById[f.identifier] ?? 0
                if now - last < fingerThrottle { continue }
                lastFingerTriggerById[f.identifier] = now
                // normalized は 0..1、Y は下が 0。SpriteKit シーン座標も下が 0
                let p = CGPoint(x: CGFloat(f.normalized.x) * w, y: CGFloat(f.normalized.y) * h)
                scene.trigger(at: p)
            } else if f.state == 6 || f.state == 0 {
                lastFingerTriggerById.removeValue(forKey: f.identifier)
            }
        }
    }

    private func applyKioskPresentationOptions() {
        NSApp.presentationOptions = [
            .hideDock,
            .hideMenuBar,
            .disableAppleMenu,
            .disableProcessSwitching,
            .disableSessionTermination,
            .disableHideApplication,
            .disableMenuBarTransparency,
        ]
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    private func setupWindow() {
        let screen = NSScreen.main
        let frame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let win = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isReleasedWhenClosed = false
        win.level = .normal
        win.collectionBehavior = [.fullScreenPrimary]
        win.backgroundColor = NSColor(red: 16/255, green: 16/255, blue: 24/255, alpha: 1)
        win.isMovable = false
        win.acceptsMouseMovedEvents = true

        let scn = BabyTapScene(size: frame.size)
        scn.scaleMode = .resizeFill

        let view = BabyTapView(frame: frame)
        view.presentScene(scn)

        win.contentView = view
        win.makeFirstResponder(view)
        win.makeKeyAndOrderFront(nil)
        win.toggleFullScreen(nil)

        NSCursor.hide()

        self.window = win
        self.skView = view
        self.scene = scn
    }

    private func setupMenu() {
        let menubar = NSMenu()
        let appMenuItem = NSMenuItem()
        menubar.addItem(appMenuItem)

        let appMenu = NSMenu()
        let quitItem = NSMenuItem(
            title: "終了",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        appMenu.addItem(quitItem)

        let forceQuitItem = NSMenuItem(
            title: "強制終了 (バイパス)",
            action: #selector(forceQuit),
            keyEquivalent: "q"
        )
        forceQuitItem.keyEquivalentModifierMask = [.command, .shift]
        forceQuitItem.target = self
        appMenu.addItem(forceQuitItem)

        appMenuItem.submenu = appMenu
        NSApp.mainMenu = menubar
    }

    @objc private func forceQuit() {
        exit(0)
    }
}
