import SwiftUI
import AVFoundation

struct InfoView: View {
    @Binding var showingInfo: Bool
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var isSpeaking = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // SPEAK BUTTON
                    Button(action: speakAboutInfo) {
                        HStack {
                            Image(systemName: isSpeaking ? "stop.circle.fill" : "speaker.wave.3.fill")
                                .font(.system(size: 24))
                            
                            Text(isSpeaking ? "Stop Reading" : "Read About VisionVoice Aloud")
                                .font(.headline)
                            
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.cyan]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .accessibilityLabel(isSpeaking ? "Stop reading about VisionVoice" : "Read about VisionVoice aloud")
                    .accessibilityHint("Double tap to hear information about VisionVoice")
                    
                    Divider()
                    
                    Text("Experience your world differently.")
                        .font(.title2)
                        .bold()
                    
                    Text("VisionVoice uses computer vision and spatial audio to help you understand your surroundings through sound and voice descriptions.")
                        .font(.body)
                    
                    Divider()
                    
                    // PRIVACY & OFFLINE SECTION
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.6)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Offline & Always Private")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            PrivacyPoint(text: "Works entirely on your device")
                            PrivacyPoint(text: "Never collects, stores, or shares your data")
                            PrivacyPoint(text: "No internet connection required")
                            PrivacyPoint(text: "All processing happens locally on your device")
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.purple.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1.5)
                            )
                    )
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Three Modes")
                            .font(.headline)
                        
                        ModeInfoRow(
                            icon: "eye.fill",
                            color: .cyan,
                            title: "Scene Description",
                            description: "Get a natural language description of your surroundings with objects positioned in spatial audio"
                        )
                        
                        ModeInfoRow(
                            icon: "doc.text.fill",
                            color: .green,
                            title: "Read Text",
                            description: "Hear text from medicine labels, signs, documents, and more read aloud clearly"
                        )
                        
                        ModeInfoRow(
                            icon: "cube.fill",
                            color: .purple,
                            title: "Object Guide",
                            description: "Identify specific objects and hear where they're located around you"
                        )
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How it works")
                            .font(.headline)
                        
                        BulletPoint(text: "Vision Framework recognizes objects, people, and text in real-time")
                        BulletPoint(text: "Spatial audio helps you understand where things are located")
                        BulletPoint(text: "Natural language descriptions make the information intuitive")
                        BulletPoint(text: "Everything runs privately on your device")
                    }
                    .font(.body)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Try this")
                            .font(.headline)
                        
                        NumberedStep(number: 1, text: "Enable Demo Mode to test with sample images")
                        NumberedStep(number: 2, text: "Tap 'Describe Scene' to hear what VisionVoice sees")
                        NumberedStep(number: 3, text: "Listen for spatial audio beeps showing object positions")
                        NumberedStep(number: 4, text: "Switch modes to try text reading and object detection")
                    }
                    .font(.body)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Built for accessibility")
                            .font(.headline)
                        
                        Text("VisionVoice was designed to help blind and low-vision users gain independence by describing the visual world through audio. It combines Apple's Vision framework, speech synthesis, and spatial audio to create an intuitive accessibility tool.")
                            .font(.body)
                    }
                }
                .padding()
            }
            .navigationTitle("About VisionVoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        stopSpeaking()
                        showingInfo = false
                    }
                }
            }
        }
        .onDisappear {
            stopSpeaking()
        }
    }
    
   //- SPEAK ABOUT INFO
    private func speakAboutInfo() {
        if isSpeaking {
            stopSpeaking()
        } else {
            startSpeaking()
        }
    }
    
    private func startSpeaking() {
        isSpeaking = true
        
        let fullText = """
        About VisionVoice.
        
        VisionVoice uses computer vision and spatial audio to help you understand your surroundings through sound and voice descriptions.
        
        Privacy and Offline.
        This app works entirely on your device. We never collect, store, or share your data. No internet connection is required. All processing happens locally on your device.
        
        Three Modes.
        
        Mode 1: Scene Description. Get a natural language description of your surroundings with objects positioned in spatial audio.
        
        Mode 2: Read Text. Hear text from medicine labels, signs, documents, and more read aloud clearly.
        
        Mode 3: Object Guide. Identify specific objects and hear where they're located around you.
        
        How it works.
        Vision Framework recognizes objects, people, and text in real-time. Spatial audio helps you understand where things are located. Natural language descriptions make the information intuitive. Everything runs privately on your device.
        
        Try this.
        Step 1: Enable Demo Mode to test with sample images.
        Step 2: Tap Describe Scene to hear what VisionVoice sees.
        Step 3: Listen for spatial audio beeps showing object positions.
        Step 4: Switch modes to try text reading and object detection.
        
        Built for accessibility.
        VisionVoice was designed to help blind and low-vision users gain independence by describing the visual world through audio. It combines Apple's Vision framework, speech synthesis, and spatial audio to create an intuitive accessibility tool.
        
        End of about information.
        """
        
        // Configure audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ Audio session error: \(error)")
        }
        
        let utterance = AVSpeechUtterance(string: fullText)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.volume = 1.0
        
        speechSynthesizer.speak(utterance)
        
        // Reset state when done
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(fullText.count) / 10) {
            isSpeaking = false
        }
    }
    
    private func stopSpeaking() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
        }
    }
}

//  MODE INFO ROW
struct ModeInfoRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [color, color.opacity(0.7)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// PRIVACY POINT 
struct PrivacyPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.purple)
            
            Text(text)
                .font(.subheadline)
        }
    }
}

// BULLET POINT
struct BulletPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.body)
                .fontWeight(.bold)
            
            Text(text)
                .font(.body)
        }
    }
}

// NUMBERED STEP
struct NumberedStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.body)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            Text(text)
                .font(.body)
        }
    }
}
