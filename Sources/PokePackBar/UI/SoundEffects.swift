import AVFoundation

/// 짧은 효과음. 설정에서 켰을 때만 난다(기본은 꺼짐).
///
/// 소리 파일을 번들에 넣지 않고 그때그때 합성한다. 시스템 알림음은 「무엇이 잘못됐다」 는
/// 소리로 익숙해서 보상 순간에 어울리지 않는다. 소리가 끝나면 오디오 장치를 놓아 준다 —
/// 메뉴바 앱이 장치를 계속 붙잡고 있으면 배터리를 쓴다.
@MainActor
enum SoundEffects {
    static let defaultsKey = "soundEffects"

    enum Effect: Hashable {
        /// 포장지가 찢기는 소리.
        case rip
        /// 무언가가 담기는 짧은 소리(구매).
        case pop
        /// 판매 대금.
        case coin
        /// 좋은 것이 나왔을 때의 종소리. 음 수가 많을수록 귀하다(1~4).
        case chime(Int)
        /// 정말 드문 카드. 종소리보다 길게, 두 옥타브를 올라가 맨 위에서 화음으로 울린다.
        case fanfare
    }

    static var enabled: Bool { UserDefaults.standard.bool(forKey: defaultsKey) }

    /// `force` 는 설정에서 켜는 순간 미리 들려줄 때만 쓴다.
    static func play(_ effect: Effect, force: Bool = false) {
        guard force || enabled, let buffer = buffer(for: effect) else { return }
        configure()
        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }
        // 겹쳐 나는 소리(차례로 내려앉는 팩)가 줄 서지 않게 재생기를 돌려 쓴다.
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying { player.play() }
        idleStop?.cancel()
        idleStop = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            players.forEach { $0.stop() }
            engine.stop()
        }
    }

    // MARK: 재생

    private static let sampleRate = 44_100.0
    private static let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    private static let engine = AVAudioEngine()
    private static let players = (0..<3).map { _ in AVAudioPlayerNode() }
    private static var nextPlayer = 0
    private static var configured = false
    private static var idleStop: Task<Void, Never>?
    private static var cache: [Effect: AVAudioPCMBuffer] = [:]

    private static func configure() {
        guard !configured else { return }
        configured = true
        for player in players {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
    }

    private static func buffer(for effect: Effect) -> AVAudioPCMBuffer? {
        if let cached = cache[effect] { return cached }
        let samples: [Float] = switch effect {
        case .rip: rip()
        case .pop: pop()
        case .coin: coin()
        case .chime(let notes): chime(notes: max(1, min(4, notes)))
        case .fanfare: fanfare()
        }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        for (index, sample) in samples.enumerated() { channel[index] = sample }
        cache[effect] = buffer
        return buffer
    }

    // MARK: 합성

    /// 맑은 종. 기본음에 배음 두 개를 얹고 빠르게 울렸다가 길게 사라진다.
    /// 음은 장3화음을 차례로 올린다 — 귀할수록 더 높이 올라간다.
    private static func chime(notes: Int) -> [Float] {
        let scale: [Double] = [1046.5, 1318.5, 1568.0, 2093.0]
        let chosen = notes == 1 ? [1318.5] : Array(scale.prefix(notes))
        let spacing = 0.07, ring = 0.9
        var samples = [Float](repeating: 0, count: Int((spacing * Double(chosen.count) + ring) * sampleRate))
        for (index, frequency) in chosen.enumerated() {
            let start = Int(Double(index) * spacing * sampleRate)
            for frame in 0..<Int(ring * sampleRate) where start + frame < samples.count {
                let t = Double(frame) / sampleRate
                let envelope = min(1, t / 0.004) * exp(-t * 5.5)
                let tone = sin(2 * .pi * frequency * t)
                    + 0.22 * sin(2 * .pi * frequency * 2 * t)
                    + 0.07 * sin(2 * .pi * frequency * 3.01 * t)
                samples[start + frame] += Float(0.16 * envelope * tone)
            }
        }
        return samples
    }

    /// 팡파르. 장3화음을 두 옥타브에 걸쳐 빠르게 오른 뒤, 맨 위에서 화음 셋이 함께 길게 울린다.
    private static func fanfare() -> [Float] {
        let run: [Double] = [523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0, 2093.0]
        let final: [Double] = [1046.5, 1318.5, 1568.0, 2093.0]
        let spacing = 0.055, ring = 0.55, hold = 1.4
        let holdStart = spacing * Double(run.count)
        var samples = [Float](repeating: 0, count: Int((holdStart + hold) * sampleRate))
        func strike(_ frequency: Double, at start: Double, length: Double, decay: Double, gain: Double) {
            let first = Int(start * sampleRate)
            for frame in 0..<Int(length * sampleRate) where first + frame < samples.count {
                let t = Double(frame) / sampleRate
                let envelope = min(1, t / 0.004) * exp(-t * decay)
                let tone = sin(2 * .pi * frequency * t) + 0.22 * sin(2 * .pi * frequency * 2 * t)
                samples[first + frame] += Float(gain * envelope * tone)
            }
        }
        for (index, frequency) in run.enumerated() {
            strike(frequency, at: Double(index) * spacing, length: ring, decay: 7, gain: 0.11)
        }
        for frequency in final {
            strike(frequency, at: holdStart, length: hold, decay: 2.6, gain: 0.07)
        }
        return samples
    }

    /// 담기는 소리. 높은 음이 짧게 아래로 미끄러진다.
    private static func pop() -> [Float] {
        let duration = 0.12
        var phase = 0.0
        return (0..<Int(duration * sampleRate)).map { frame in
            let t = Double(frame) / sampleRate
            let frequency = 220 + 380 * exp(-t * 45)
            phase += 2 * .pi * frequency / sampleRate
            return Float(0.32 * min(1, t / 0.002) * exp(-t * 34) * sin(phase))
        }
    }

    /// 동전. 쇳소리가 나도록 정수배가 아닌 배음을 섞어 두 번 울린다.
    private static func coin() -> [Float] {
        let notes = [1975.5, 2637.0], spacing = 0.075, ring = 0.45
        var samples = [Float](repeating: 0, count: Int((spacing + ring) * sampleRate))
        for (index, frequency) in notes.enumerated() {
            let start = Int(Double(index) * spacing * sampleRate)
            for frame in 0..<Int(ring * sampleRate) where start + frame < samples.count {
                let t = Double(frame) / sampleRate
                let envelope = min(1, t / 0.002) * exp(-t * 12)
                let tone = sin(2 * .pi * frequency * t) + 0.35 * sin(2 * .pi * frequency * 2.76 * t)
                samples[start + frame] += Float(0.14 * envelope * tone)
            }
        }
        return samples
    }

    /// 포장지가 찢기는 소리. 걸러 낸 잡음에 작은 알갱이(뜯기는 섬유)를 섞는다.
    private static func rip() -> [Float] {
        let duration = 0.32
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func random() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 11) / Double(UInt64.max >> 11)
        }
        var low = 0.0, lower = 0.0, grain = 1.0, grainLeft = 0
        return (0..<Int(duration * sampleRate)).map { frame in
            let t = Double(frame) / sampleRate
            let noise = random() * 2 - 1
            // 두 저역 통과의 차이 — 바스락거리는 중간 대역만 남긴다.
            low += (noise - low) * 0.45
            lower += (noise - lower) * 0.08
            if grainLeft <= 0 {
                grain = 0.25 + random() * 0.75
                grainLeft = Int((0.003 + random() * 0.006) * sampleRate)
            }
            grainLeft -= 1
            let envelope = min(1, t / 0.012) * (t > duration - 0.09 ? (duration - t) / 0.09 : 1)
            return Float(0.5 * envelope * grain * (low - lower))
        }
    }
}
