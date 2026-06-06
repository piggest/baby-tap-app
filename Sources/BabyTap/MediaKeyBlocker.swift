import Foundation
import AppKit
import ApplicationServices

// 音量/輝度/再生制御などのメディアキーを CGEventTap でブロックする
final class MediaKeyBlocker {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // ev_keymap.h の NX_KEYTYPE_* 定数
    private struct NXKey {
        static let SOUND_UP: Int          = 0
        static let SOUND_DOWN: Int        = 1
        static let BRIGHTNESS_UP: Int     = 2
        static let BRIGHTNESS_DOWN: Int   = 3
        static let MUTE: Int              = 7
        static let EJECT: Int             = 14
        static let PLAY: Int              = 16
        static let NEXT: Int              = 17
        static let PREVIOUS: Int          = 18
        static let FAST: Int              = 19
        static let REWIND: Int            = 20
        static let ILLUMINATION_UP: Int   = 21
        static let ILLUMINATION_DOWN: Int = 22
        static let ILLUMINATION_TOGGLE: Int = 23
    }

    private static let blockedKeys: Set<Int> = [
        NXKey.SOUND_UP, NXKey.SOUND_DOWN, NXKey.MUTE,
        NXKey.BRIGHTNESS_UP, NXKey.BRIGHTNESS_DOWN,
        NXKey.EJECT,
        NXKey.PLAY, NXKey.NEXT, NXKey.PREVIOUS, NXKey.FAST, NXKey.REWIND,
        NXKey.ILLUMINATION_UP, NXKey.ILLUMINATION_DOWN, NXKey.ILLUMINATION_TOGGLE,
    ]

    func start() {
        if eventTap != nil { return }
        guard isTrusted() else {
            _ = requestTrustAndPrompt()
            NSLog("[media-key-blocker] アクセシビリティ権限が未許可。許可後に再起動が必要")
            return
        }

        // NX_SYSDEFINED == 14 (NSEvent.EventType.systemDefined)
        let mask: CGEventMask = CGEventMask(1) << 14
        let context = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: MediaKeyBlocker.tapCallback,
            userInfo: context
        ) else {
            NSLog("[media-key-blocker] CGEvent.tapCreate に失敗")
            return
        }
        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        runLoopSource = source
        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("[media-key-blocker] メディアキーブロック開始")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func isTrusted() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts: CFDictionary = [key: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    private func requestTrustAndPrompt() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts: CFDictionary = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    private static let tapCallback: CGEventTapCallBack = { _, type, event, refcon in
        // タップが無効化された場合は再有効化して素通り
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let refcon = refcon {
                let blocker = Unmanaged<MediaKeyBlocker>.fromOpaque(refcon).takeUnretainedValue()
                if let tap = blocker.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            }
            return Unmanaged.passUnretained(event)
        }

        // NSEventTypeSystemDefined == 14
        if type.rawValue != 14 {
            return Unmanaged.passUnretained(event)
        }
        guard let ns = NSEvent(cgEvent: event) else {
            return Unmanaged.passUnretained(event)
        }
        // NX_SUBTYPE_AUX_CONTROL_BUTTONS == 8
        if ns.subtype.rawValue != 8 {
            return Unmanaged.passUnretained(event)
        }
        let data1 = ns.data1
        let keyCode = (data1 & 0xFFFF0000) >> 16
        if MediaKeyBlocker.blockedKeys.contains(keyCode) {
            // イベント破棄
            return nil
        }
        return Unmanaged.passUnretained(event)
    }
}
