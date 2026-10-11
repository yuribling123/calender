import AVFoundation

enum SaveFeedback {
    private static var activePlayer: AVAudioPlayer?

    static func play() {
        guard let url = Bundle.main.url(forResource: "save-chime", withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else {
            return
        }

        player.volume = 0.32
        player.prepareToPlay()
        player.play()
        activePlayer = player
    }
}

/// A brief paper rustle synthesized from filtered noise, with a soft settling tail.
enum PageTurnFeedback {
    private static var activePlayer: AVAudioPlayer?
    private static var lastPlayedAt = Date.distantPast
    private static let soundData: Data = {
        let sampleRate = 44_100
        let count = Int(Double(sampleRate) * 0.22)
        var samples = Data()
        var seed: UInt32 = 0x50415045
        var previousNoise = 0.0
        var softened = 0.0
        for index in 0..<count {
            let time = Double(index) / Double(sampleRate)
            seed = 1_664_525 &* seed &+ 1_013_904_223
            let noise = Double(seed) / Double(UInt32.max) * 2 - 1
            let friction = noise - previousNoise
            previousNoise = noise
            softened += 0.35 * (friction - softened)
            let attack = min(time / 0.012, 1)
            let release = min((0.22 - time) / 0.035, 1)
            let sweep = exp(-pow((time - 0.075) / 0.045, 2))
            let settling = 0.18 * exp(-pow((time - 0.16) / 0.025, 2))
            let value = softened * (sweep + settling) * attack * release * 0.55
            var pcm = Int16(max(-1, min(1, value)) * Double(Int16.max)).littleEndian
            withUnsafeBytes(of: &pcm) { samples.append(contentsOf: $0) }
        }
        var wav = Data()
        func appendNumber<T: FixedWidthInteger>(_ value: T) {
            var number = value.littleEndian
            withUnsafeBytes(of: &number) { wav.append(contentsOf: $0) }
        }
        wav.append(contentsOf: "RIFF".utf8)
        appendNumber(UInt32(36 + samples.count))
        wav.append(contentsOf: "WAVEfmt ".utf8)
        appendNumber(UInt32(16))
        appendNumber(UInt16(1))
        appendNumber(UInt16(1))
        appendNumber(UInt32(sampleRate))
        appendNumber(UInt32(sampleRate * 2))
        appendNumber(UInt16(2))
        appendNumber(UInt16(16))
        wav.append(contentsOf: "data".utf8)
        appendNumber(UInt32(samples.count))
        wav.append(samples)
        return wav
    }()

    static func play() {
        guard Date().timeIntervalSince(lastPlayedAt) >= 0.12,
              let player = try? AVAudioPlayer(data: soundData) else { return }
        lastPlayedAt = Date()
        activePlayer?.stop()
        player.volume = 0.24
        player.prepareToPlay()
        player.play()
        activePlayer = player
    }
}
