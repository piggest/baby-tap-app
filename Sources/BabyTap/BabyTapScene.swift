import SpriteKit
import AppKit

// タップ・キー入力に応じて演出を出すシーン
final class BabyTapScene: SKScene {
    private let colors: [SKColor] = [
        SKColor(red: 1.0,  green: 0.37, blue: 0.36, alpha: 1),
        SKColor(red: 1.0,  green: 0.70, blue: 0.0,  alpha: 1),
        SKColor(red: 1.0,  green: 0.88, blue: 0.34, alpha: 1),
        SKColor(red: 0.48, green: 0.89, blue: 0.58, alpha: 1),
        SKColor(red: 0.24, green: 0.76, blue: 0.95, alpha: 1),
        SKColor(red: 0.49, green: 0.36, blue: 1.0,  alpha: 1),
        SKColor(red: 1.0,  green: 0.48, blue: 0.84, alpha: 1),
        SKColor(red: 1.0,  green: 0.62, blue: 0.27, alpha: 1),
        SKColor(red: 0.36, green: 0.91, blue: 0.77, alpha: 1),
        SKColor(red: 1.0,  green: 0.30, blue: 0.50, alpha: 1),
    ]

    private let animals = ["🐶","🐱","🐰","🐼","🦁","🐯","🐸","🐵","🦊","🐧","🐥","🐮","🐷","🐨","🦄","🐙","🐠","🐳","🐢","🦋","🐝","🐞","🦒","🐘"]
    private let fruits  = ["🍎","🍌","🍓","🍇","🍊","🍉","🍑","🥝","🍍","🥕","🍒","🍋"]
    private let faces   = ["😀","😆","😍","🤩","😎","🤗","😺","🥳","😋","🤖","👶","✨","💖","⭐️","🌈","🎈","🎉","🎵","🌟","🌸","🌻","🍭"]
    private let hira    = ["あ","い","う","え","お","か","き","く","け","こ","さ","し","す","せ","そ","な","は","ま","や","ら","わ"]
    private let alphabet = ["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"]
    private let numbers = ["1","2","3","4","5","6","7","8","9","10"]
    private let crossPool = ["🐶","🐱","🐰","🐼","🦁","🐯","🐸","🐵","🦊","🐧","🐥","🍎","🍌","🍓","🍇","🚗","🚂","✈️","🚀","🛸","⛵️","🐳","🦋","🌈","🎈","☁️","⭐️"]
    private let sparkleChars = ["✨","⭐️","💫","🌟"]

    private let sound = SoundEngine()

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 16/255, green: 16/255, blue: 24/255, alpha: 1)
        scheduleCrossing()
    }

    // 外部から呼ぶエントリポイント
    func trigger(at point: CGPoint) {
        let combo = Double.random(in: 0..<1) < 0.2 ? 2 : 1
        for i in 0..<combo {
            let ox = CGFloat.random(in: -20...20) * CGFloat(i)
            let oy = CGFloat.random(in: -20...20) * CGFloat(i)
            performRandomReaction(at: CGPoint(x: point.x + ox, y: point.y + oy))
        }
    }

    func triggerRandom() {
        let margin: CGFloat = 80
        let x = CGFloat.random(in: margin...(size.width - margin))
        let y = CGFloat.random(in: margin...(size.height - margin))
        trigger(at: CGPoint(x: x, y: y))
    }

    private func performRandomReaction(at point: CGPoint) {
        switch Int.random(in: 0..<5) {
        case 0: reactShapes(at: point)
        case 1: reactEmoji(at: point, pool: animals + fruits + faces)
        case 2: reactText(at: point)
        case 3: reactRipple(at: point)
        default: reactEmoji(at: point, pool: faces)
        }
    }

    // ==========================================
    // 反応：図形パーティクル
    // ==========================================
    private func reactShapes(at point: CGPoint) {
        let n = 10 + Int.random(in: 0..<8)
        let color = colors.randomElement()!
        let shapeKind = Int.random(in: 0..<3) // 0:円 1:正方形 2:三角
        for i in 0..<n {
            let size = CGFloat.random(in: 16...44)
            let particle: SKNode
            switch shapeKind {
            case 1:
                let s = SKShapeNode(rectOf: CGSize(width: size, height: size))
                s.fillColor = color
                s.strokeColor = .clear
                particle = s
            case 2:
                let path = CGMutablePath()
                let h = size * 0.866
                path.move(to: CGPoint(x: 0, y: h/2))
                path.addLine(to: CGPoint(x: -size/2, y: -h/2))
                path.addLine(to: CGPoint(x: size/2, y: -h/2))
                path.closeSubpath()
                let s = SKShapeNode(path: path)
                s.fillColor = color
                s.strokeColor = .clear
                particle = s
            default:
                let s = SKShapeNode(circleOfRadius: size/2)
                s.fillColor = color
                s.strokeColor = .clear
                particle = s
            }
            particle.position = point
            addChild(particle)
            let angle = CGFloat(i) / CGFloat(n) * .pi * 2 + CGFloat.random(in: -0.2...0.2)
            let dist = CGFloat.random(in: 100...320)
            let dx = cos(angle) * dist
            let dy = sin(angle) * dist
            let move = SKAction.move(by: CGVector(dx: dx, dy: dy), duration: 0.7)
            move.timingMode = .easeOut
            let rot = SKAction.rotate(byAngle: CGFloat.random(in: -.pi*2...(.pi*2)), duration: 0.7)
            let scale = SKAction.scale(to: 0.2, duration: 0.7)
            let fade = SKAction.fadeOut(withDuration: 0.7)
            particle.run(SKAction.sequence([
                SKAction.group([move, rot, scale, fade]),
                .removeFromParent()
            ]))
        }
        sound.playPop()
    }

    // ==========================================
    // 反応：絵文字ポン
    // ==========================================
    private func reactEmoji(at point: CGPoint, pool: [String]) {
        let label = SKLabelNode(text: pool.randomElement()!)
        label.fontSize = 140
        label.position = point
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.setScale(0.1)
        addChild(label)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.18)
        scaleUp.timingMode = .easeOut
        let wait = SKAction.wait(forDuration: 0.5)
        let end = SKAction.group([
            SKAction.scale(to: 0.3, duration: 0.4),
            SKAction.fadeOut(withDuration: 0.4)
        ])
        label.run(SKAction.sequence([scaleUp, wait, end, .removeFromParent()]))
        sound.playBoing()
    }

    // ==========================================
    // 反応：文字
    // ==========================================
    private func reactText(at point: CGPoint) {
        let pools: [[String]] = [hira, alphabet, numbers]
        let pool = pools.randomElement()!
        let label = SKLabelNode(text: pool.randomElement()!)
        label.fontSize = 180
        label.fontName = "HiraginoSans-W7"
        label.fontColor = colors.randomElement()!
        label.position = point
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.setScale(0.1)
        addChild(label)
        let rotation = CGFloat.random(in: -.pi/5...(.pi/5))
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.18)
        scaleUp.timingMode = .easeOut
        let rot = SKAction.rotate(byAngle: rotation, duration: 0.7)
        let fade = SKAction.fadeOut(withDuration: 0.7)
        label.run(SKAction.sequence([
            scaleUp,
            SKAction.group([rot, fade]),
            .removeFromParent()
        ]))
        sound.playHappy()
    }

    // ==========================================
    // 反応：波紋 + キラキラ
    // ==========================================
    private func reactRipple(at point: CGPoint) {
        let color = colors.randomElement()!
        let ring = SKShapeNode(circleOfRadius: 30)
        ring.fillColor = .clear
        ring.strokeColor = color
        ring.lineWidth = 8
        ring.position = point
        addChild(ring)
        ring.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 9.0, duration: 0.9),
                SKAction.fadeOut(withDuration: 0.9)
            ]),
            .removeFromParent()
        ]))

        let count = 4 + Int.random(in: 0..<4)
        for _ in 0..<count {
            let s = SKLabelNode(text: sparkleChars.randomElement()!)
            s.fontSize = 56
            let ox = CGFloat.random(in: -120...120)
            let oy = CGFloat.random(in: -120...120)
            s.position = CGPoint(x: point.x + ox, y: point.y + oy)
            s.verticalAlignmentMode = .center
            s.horizontalAlignmentMode = .center
            s.setScale(0.1)
            addChild(s)
            s.run(SKAction.sequence([
                SKAction.scale(to: 1.2, duration: 0.2),
                SKAction.group([
                    SKAction.moveBy(x: 0, y: 80, duration: 0.6),
                    SKAction.fadeOut(withDuration: 0.6)
                ]),
                .removeFromParent()
            ]))
        }
        sound.playSparkle()
    }

    // ==========================================
    // 画面を横切る絵文字
    // ==========================================
    private func scheduleCrossing() {
        let action = SKAction.sequence([
            SKAction.wait(forDuration: TimeInterval.random(in: 3.5...8.5)),
            SKAction.run { [weak self] in self?.spawnCrossing() },
        ])
        run(SKAction.repeatForever(action))
    }

    private func spawnCrossing() {
        let label = SKLabelNode(text: crossPool.randomElement()!)
        label.fontSize = CGFloat.random(in: 70...160)
        let fromLeft = Bool.random()
        let y = CGFloat.random(in: 60...(size.height - 100))
        label.position = CGPoint(x: fromLeft ? -120 : size.width + 120, y: y)
        addChild(label)
        let dx = fromLeft ? (size.width + 240) : -(size.width + 240)
        let duration = TimeInterval.random(in: 6...11)
        label.run(SKAction.sequence([
            SKAction.moveBy(x: dx, y: 0, duration: duration),
            .removeFromParent()
        ]))
    }
}
