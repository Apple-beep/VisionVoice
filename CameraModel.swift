

@preconcurrency import AVFoundation
import Combine
import Foundation
import CoreVideo

final class CameraModel: NSObject, ObservableObject, @unchecked Sendable {
    
    @Published private(set) var authorization: AVAuthorizationStatus = .notDetermined
    @Published private(set) var isRunning: Bool = false
    
    let session = AVCaptureSession()
    
    private var isConfigured = false
    private let videoOutput = AVCaptureVideoDataOutput()
    private let outputQueue = DispatchQueue(label: "prismlens.camera.output", qos: .userInitiated)
    private let sessionQueue = DispatchQueue(label: "prismlens.camera.session", qos: .userInitiated)
    
    private let lock = NSLock()
    private var latestBuffer: CVPixelBuffer?
    
    override init() {
        super.init()
        refreshAuthorization()
    }
    
    func refreshAuthorization() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.authorization = status
            if status == .authorized {
                self.startIfNeeded()
            }
        }
    }
    
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.authorization = granted ? .authorized : .denied
                if granted {
                    self.startIfNeeded()
                }
            }
        }
    }
    
    func startIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            
            if !self.isConfigured {
                self.configureSession()
            }
            
            guard !self.session.isRunning else { return }
            
            self.session.startRunning()
            
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = true
            }
        }
    }
    
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning else { return }
            
            self.session.stopRunning()
            
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
            }
        }
    }
    
    func latestPixelBuffer() -> CVPixelBuffer? {
        lock.lock()
        defer { lock.unlock() }
        return latestBuffer
    }
    
    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high
        
        guard
            let device = AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)
        
        session.commitConfiguration()
        isConfigured = true
    }
}

extension CameraModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        lock.lock()
        latestBuffer = pb
        lock.unlock()
    }
}
