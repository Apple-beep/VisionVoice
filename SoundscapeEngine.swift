
import Foundation
@preconcurrency import AVFoundation

final class SoundscapeEngine: @unchecked Sendable {
    
    private let engine = AVAudioEngine()
    private let environment = AVAudioEnvironmentNode()
    
    private let lock = NSLock()
    private var players: [String: AVAudioPlayerNode] = [:]
    private var started = false
    
    func update(things: [DetectedThing], enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        
        if !enabled {
            stopAll()
            return
        }
        
        startIfNeeded()
        
        // Group by kind and position
        let grouped = Dictionary(grouping: things, by: { $0.kind })
        
        for kind in DetectedKind.allCases {
            if let items = grouped[kind], !items.isEmpty {
                // Play the most confident detection of each kind
                let best = items.max(by: { $0.confidence < $1.confidence })!
                ensurePlaying(kind: kind, thing: best)
            } else {
                stop(key: kind.rawValue)
            }
        }
    }
    
    func playDescriptionSound() {
        lock.lock()
        defer { lock.unlock() }
        
        startIfNeeded()
        
        let key = "description_chime"
        let player = players[key] ?? makeChimePlayer()
        players[key] = player
        
        player.position = AVAudio3DPoint(x: 0, y: 0, z: -1.0)
        player.volume = 0.4
        
        if !player.isPlaying {
            player.play()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.lock.lock()
            self?.stop(key: key)
            self?.lock.unlock()
        }
    }
    
    private func startIfNeeded() {
        guard !started else { return }
        
        engine.attach(environment)
        engine.connect(environment, to: engine.mainMixerNode, format: nil)
        
        do {
            try engine.start()
            started = true
        } catch {
            started = false
        }
    }
    
    private func ensurePlaying(kind: DetectedKind, thing: DetectedThing) {
        let key = kind.rawValue
        let player = players[key] ?? makePlayer(kind: kind)
        players[key] = player
        
        // Convert bounding box to 3D position
        let c = center(of: thing.boundingBox)
        let x = Float((c.x - 0.5) * 2.0)  // -1 to 1
        let y = Float((c.y - 0.5) * 2.0)  // -1 to 1
        let z: Float = -1.5
        player.position = AVAudio3DPoint(x: x, y: y, z: z)
        
        // Volume based on confidence and size
        let area = Float(thing.boundingBox.width * thing.boundingBox.height)
        player.volume = min(0.3, 0.1 + area * 2.0 + thing.confidence * 0.15)
        
        if !player.isPlaying {
            player.play()
        }
    }
    
    private func stopAll() {
        for key in Array(players.keys) {
            stop(key: key)
        }
    }
    
    private func stop(key: String) {
        guard let p = players[key] else { return }
        p.stop()
        engine.disconnectNodeInput(p)
        engine.detach(p)
        players.removeValue(forKey: key)
    }
    
    private func makePlayer(kind: DetectedKind) -> AVAudioPlayerNode {
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: environment, format: toneFormat())
        
        let buffer = makeToneBuffer(kind: kind)
        player.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
        return player
    }
    
    private func makeChimePlayer() -> AVAudioPlayerNode {
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: environment, format: toneFormat())
        
        let buffer = makeChimeBuffer()
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        return player
    }
    
    private func toneFormat() -> AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    }
    
    private func makeToneBuffer(kind: DetectedKind) -> AVAudioPCMBuffer {
        let format = toneFormat()
        let sampleRate = Float(format.sampleRate)
        let duration: Float = 1.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        let freq: Float
        switch kind {
        case .person: freq = 440  // A4 - warm, human
        case .object: freq = 330  // E4 - neutral
        case .text: freq = 550    // C#5 - higher, attention
        case .surface: freq = 220 // A3 - low, grounding
        }
        
        let amp: Float = 0.15
        let twoPi = Float.pi * 2.0
        
        let samples = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            let t = Float(i) / sampleRate
            let v = sin(twoPi * freq * t)
            samples[i] = v * amp
        }
        
        return buffer
    }
    
    private func makeChimeBuffer() -> AVAudioPCMBuffer {
        let format = toneFormat()
        let sampleRate = Float(format.sampleRate)
        let duration: Float = 0.4
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        let freq: Float = 880  // A5 - bright chime
        let amp: Float = 0.25
        let twoPi = Float.pi * 2.0
        
        let samples = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            let t = Float(i) / sampleRate
            let envelope = max(0, 1.0 - t / duration)  // Fade out
            let v = sin(twoPi * freq * t)
            samples[i] = v * amp * envelope
        }
        
        return buffer
    }
    
    private func center(of bbox: CGRect) -> CGPoint {
        CGPoint(x: bbox.midX, y: bbox.midY)
    }
}
