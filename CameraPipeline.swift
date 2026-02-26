

import Foundation
import AVFoundation

@MainActor
final class CameraPipeline: ObservableObject {
    
    let recognizer = VisionRecognizer()
    let soundEngine = SoundscapeEngine()
    
    private var camera: CameraModel?
    private var isRunning = false
    
    func start(camera: CameraModel) {
        self.camera = camera
        isRunning = true
    }
    
    func stop() {
        isRunning = false
        soundEngine.update(things: [], enabled: false)
    }
}
