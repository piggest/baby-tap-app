import AppKit
import SpriteKit

// プレーンな NSView を host にして SKView を子に置く。
// SKView を直接継承すると NSResponder の touches* メソッドが SpriteKit 内部に
// 飲まれて反応しない場合があるため、host で touch を確実に受ける構造にする。
final class BabyTapView: NSView {
    let skView: SKView
    weak var scene: BabyTapScene?

    override init(frame frameRect: NSRect) {
        skView = SKView(frame: frameRect)
        super.init(frame: frameRect)
        // 自身でタッチを受信。新旧 API 両方セット (環境差吸収)
        self.allowedTouchTypes = .indirect
        self.wantsRestingTouches = true
        // deprecated だがまだ有効。allowedTouchTypes が効かないケースの保険
        let sel = NSSelectorFromString("setAcceptsTouchEvents:")
        if self.responds(to: sel) {
            self.perform(sel, with: NSNumber(value: true))
        }
        NSLog("[init] BabyTapView allowedTouchTypes=\(self.allowedTouchTypes.rawValue) wantsResting=\(self.wantsRestingTouches)")
        // SKView を全面の子ビューにする。タッチを横取りされないよう
        // allowedTouchTypes を 0 にしておく
        skView.allowedTouchTypes = []
        skView.autoresizingMask = [.width, .height]
        addSubview(skView)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        let r = super.becomeFirstResponder()
        NSLog("[responder] BabyTapView becameFirstResponder=\(r)")
        return r
    }

    func presentScene(_ scn: BabyTapScene) {
        self.scene = scn
        skView.presentScene(scn)
    }

    // ポインタごとのスロットル時間 (擦り動作の連続反応用)
    private var lastTrackpadTriggerById: [Int: CFTimeInterval] = [:]
    private var lastMouseDragTrigger: CFTimeInterval = 0
    private let dragThrottle: CFTimeInterval = 0.09

    // ==========================================
    // トラックパッド multi-touch (NSTouch indirect)
    // ==========================================
    override func touchesBegan(with event: NSEvent) {
        let all = event.allTouches()
        NSLog("[touch] began allTouches=\(all.count)")
        for touch in event.touches(matching: .began, in: self) {
            let id = touch.identity.hash
            lastTrackpadTriggerById[id] = CACurrentMediaTime()
            triggerForTouch(touch)
        }
    }

    override func touchesMoved(with event: NSEvent) {
        let all = event.allTouches()
        if all.count > 1 { NSLog("[touch] moved allTouches=\(all.count)") }
        let now = CACurrentMediaTime()
        for touch in event.touches(matching: .moved, in: self) {
            let id = touch.identity.hash
            let last = lastTrackpadTriggerById[id] ?? 0
            if now - last < dragThrottle { continue }
            lastTrackpadTriggerById[id] = now
            triggerForTouch(touch)
        }
    }

    override func touchesEnded(with event: NSEvent) {
        for touch in event.touches(matching: .ended, in: self) {
            lastTrackpadTriggerById.removeValue(forKey: touch.identity.hash)
        }
    }

    override func touchesCancelled(with event: NSEvent) {
        for touch in event.touches(matching: .cancelled, in: self) {
            lastTrackpadTriggerById.removeValue(forKey: touch.identity.hash)
        }
    }

    private func triggerForTouch(_ touch: NSTouch) {
        guard let scene = scene else { return }
        // normalizedPosition は 0..1 (Y は下が 0)。SpriteKit シーン座標も Y 下基準
        let n = touch.normalizedPosition
        let p = CGPoint(x: n.x * bounds.width, y: n.y * bounds.height)
        scene.trigger(at: p)
    }

    // ==========================================
    // マウス
    // ==========================================
    override func mouseDown(with event: NSEvent) {
        triggerFromEvent(event)
    }

    override func mouseDragged(with event: NSEvent) {
        let now = CACurrentMediaTime()
        if now - lastMouseDragTrigger < dragThrottle { return }
        lastMouseDragTrigger = now
        triggerFromEvent(event)
    }

    // ボタン押下無しのマウス移動でも反応
    override func mouseMoved(with event: NSEvent) {
        let now = CACurrentMediaTime()
        if now - lastMouseDragTrigger < dragThrottle { return }
        lastMouseDragTrigger = now
        triggerFromEvent(event)
    }

    override func rightMouseDown(with event: NSEvent) {
        triggerFromEvent(event)
    }

    // mouseMoved を受け取るためのトラッキングエリアを bounds 全体に張る
    private var trackingArea: NSTrackingArea?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    private func triggerFromEvent(_ event: NSEvent) {
        guard let scene = scene else { return }
        let p = convert(event.locationInWindow, from: nil)
        // SKView と scene が同サイズで resizeFill なので座標はそのまま
        scene.trigger(at: p)
    }

    // ==========================================
    // キーボード
    // ==========================================
    override func keyDown(with event: NSEvent) {
        // OS のキーリピートは無視
        if event.isARepeat { return }
        // 終了ショートカット (Cmd+Q / Cmd+Shift+Q) を保護
        if event.modifierFlags.contains(.command) { return }
        if event.modifierFlags.contains(.control) { return }
        if event.modifierFlags.contains(.option) { return }
        guard let scene = scene else { return }
        scene.triggerRandom()
    }

    // ダブルクリックでカーソル復活 (緊急脱出用)
    private var lastClickTime: CFTimeInterval = 0
    override func mouseUp(with event: NSEvent) {
        let now = CACurrentMediaTime()
        if now - lastClickTime < 0.4 {
            NSCursor.unhide()
        }
        lastClickTime = now
    }
}
