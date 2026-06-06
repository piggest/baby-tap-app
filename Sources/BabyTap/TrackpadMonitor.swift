// macOS のプライベートフレームワーク MultitouchSupport.framework を
// dlopen 経由ではなく直接リンクして、トラックパッドの生指データを取得する。
// Karabiner-Elements 等が長年使っている手法。
//
// 取れるデータ:
//   - 各指の正規化座標 (0..1)
//   - 状態 (NotTracking/StartInRange/HoverInRange/MakeTouch/Touching/BreakTouch/LingerInRange/OutOfRange)
//   - 速度、サイズ、角度等
//
// macOS の gesture recognizer (Mission Control 等) を経由しないので、
// 3本指でも 4本指でも同時に動かしてもアプリ側で全部読める。
import Foundation

// MTPoint: 2D float 座標
struct MTPoint {
    var x: Float = 0
    var y: Float = 0
}

// 1 フレームに含まれる 1 本の指の情報
// MultitouchSupport の内部 struct と memory layout が一致する必要がある
struct MTFinger {
    var frame: Int32 = 0
    var timestamp: Double = 0
    var identifier: Int32 = 0
    var state: Int32 = 0      // 0..7 (NotTracking..LingerInRange)
    var unknown1: Int32 = 0
    var unknown2: Int32 = 0
    var normalized: MTPoint = MTPoint()
    var velocity: MTPoint = MTPoint()
    var size: Float = 0
    var unknown3: Int32 = 0
    var angle: Float = 0
    var majorAxis: Float = 0
    var minorAxis: Float = 0
    var absolute: MTPoint = MTPoint()
    var unknown4a: Int32 = 0
    var unknown4b: Int32 = 0
    var density: Float = 0
}

typealias MTDeviceRef = OpaquePointer

// MTFinger は Swift struct なので @convention(c) で直接渡せない。
// Raw ポインタで受け取って中で MTFinger* にキャストする
typealias MTContactCallback = @convention(c) (
    Int32,                          // device
    UnsafeMutableRawPointer?,       // fingers (MTFinger array)
    Int32,                          // number of fingers
    Double,                         // timestamp
    Int32                           // frame
) -> Int32

@_silgen_name("MTDeviceCreateDefault")
func MTDeviceCreateDefault() -> MTDeviceRef?

@_silgen_name("MTDeviceStart")
func MTDeviceStart(_ device: MTDeviceRef, _ runMode: Int32)

@_silgen_name("MTDeviceStop")
func MTDeviceStop(_ device: MTDeviceRef)

@_silgen_name("MTDeviceRelease")
func MTDeviceRelease(_ device: MTDeviceRef)

@_silgen_name("MTRegisterContactFrameCallback")
func MTRegisterContactFrameCallback(_ device: MTDeviceRef, _ callback: MTContactCallback)

@_silgen_name("MTUnregisterContactFrameCallback")
func MTUnregisterContactFrameCallback(_ device: MTDeviceRef, _ callback: MTContactCallback)

final class TrackpadMonitor {
    static let shared = TrackpadMonitor()

    private var device: MTDeviceRef?
    // 指の動きを通知するクロージャ
    var onFingers: (([MTFinger]) -> Void)?

    private init() {}

    func start() {
        if device != nil { return }
        guard let dev = MTDeviceCreateDefault() else {
            NSLog("[trackpad] MTDeviceCreateDefault failed")
            return
        }
        device = dev
        MTRegisterContactFrameCallback(dev, Self.contactCallback)
        MTDeviceStart(dev, 0)
        NSLog("[trackpad] MultitouchSupport デバイス起動")
    }

    func stop() {
        if let dev = device {
            MTUnregisterContactFrameCallback(dev, Self.contactCallback)
            MTDeviceStop(dev)
            MTDeviceRelease(dev)
            device = nil
        }
    }

    private static let contactCallback: MTContactCallback = { _, fingersRaw, nFingers, _, _ in
        let count = Int(nFingers)
        var snapshot: [MTFinger] = []
        if count > 0, let raw = fingersRaw {
            let ptr = raw.assumingMemoryBound(to: MTFinger.self)
            snapshot.reserveCapacity(count)
            for i in 0..<count {
                snapshot.append(ptr[i])
            }
        }
        // 呼び出しは main thread 以外で来るので、main へ渡す
        DispatchQueue.main.async {
            TrackpadMonitor.shared.onFingers?(snapshot)
        }
        return 0
    }
}
