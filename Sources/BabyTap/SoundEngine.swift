import AVFoundation

// プロシージャル効果音 (Web Audio で書いていたものを AVAudioEngine で再現)
final class SoundEngine {
    private let engine = AVAudioEngine()
    private let sampleRate: Double = 44100

    init() {
        // mainMixerNode に触れることで暗黙的にエンジンが初期化される
        _ = engine.mainMixerNode
        do {
            try engine.start()
        } catch {
            NSLog("[sound] AVAudioEngine start failed: \(error.localizedDescription)")
        }
    }

    enum Wave { case sine, square, triangle }

    func playPop() {
        let f = Float.random(in: 400...900)
        playTone(freq: f, sweepTo: 200, type: .square, duration: 0.08, gain: 0.18)
    }

    func playBoing() {
        let start = Float.random(in: 200...400)
        playTone(freq: start, sweepTo: start * 3, type: .triangle, duration: 0.35, gain: 0.2)
    }

    func playSparkle() {
        let base = Float.random(in: 800...1200)
        for i in 0..<4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(i * 50)) { [weak self] in
                guard let self = self else { return }
                self.playTone(freq: base * (1 + Float(i) * 0.25), type: .sine, duration: 0.12, gain: 0.12)
            }
        }
    }

    func playHappy() {
        let chords: [[Float]] = [
            [523.25, 659.25, 783.99],
            [392.00, 493.88, 587.33],
            [440.00, 554.37, 659.25],
            [349.23, 440.00, 523.25],
        ]
        let chord = chords.randomElement()!
        for (i, f) in chord.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(i * 45)) { [weak self] in
                self?.playTone(freq: f, type: .triangle, duration: 0.4, gain: 0.14)
            }
        }
    }

    // 1 トーンを生成して再生
    private func playTone(freq: Float, sweepTo: Float? = nil, type: Wave, duration: Float, gain: Float) {
        let totalSeconds = Double(duration) + 0.05
        let frameCount = AVAudioFrameCount(totalSeconds * sampleRate)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        let attack: Float = 0.01
        let attackSamples = attack * Float(sampleRate)
        let releaseStart = (duration - attack) * Float(sampleRate)
        let totalSamples = Float(frameCount)

        guard let channel = buffer.floatChannelData?[0] else { return }
        var phase: Float = 0
        let twoPi: Float = 2 * .pi

        for i in 0..<Int(frameCount) {
            let t = Float(i) / Float(sampleRate)
            // 周波数 (sweepTo があれば指数スイープ)
            let f: Float
            if let to = sweepTo, duration > 0 {
                let progress = min(1, max(0, t / duration))
                f = freq * powf(to / freq, progress)
            } else {
                f = freq
            }
            // 波形
            let s: Float
            switch type {
            case .sine:
                s = sinf(phase)
            case .square:
                s = sinf(phase) > 0 ? 1 : -1
            case .triangle:
                let norm = phase / twoPi
                s = 2 * abs(2 * (norm - floorf(norm + 0.5))) - 1
            }
            // 簡易エンベロープ (アタック・リリース)
            var env: Float = 1
            let fi = Float(i)
            if fi < attackSamples {
                env = fi / attackSamples
            } else if fi > releaseStart {
                env = max(0, 1 - (fi - releaseStart) / (totalSamples - releaseStart))
            }
            channel[i] = s * env * gain
            phase += twoPi * f / Float(sampleRate)
            if phase > twoPi { phase -= twoPi }
        }

        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        player.scheduleBuffer(buffer, completionHandler: { [weak self] in
            DispatchQueue.main.async {
                player.stop()
                self?.engine.detach(player)
            }
        })
        player.play()
    }
}
