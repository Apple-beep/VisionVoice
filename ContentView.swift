import SwiftUI
import AVFoundation

@MainActor
struct ContentView: View {
    @StateObject private var camera = CameraModel()
    @State private var pipeline = CameraPipeline()
    
    @State private var selectedMode: AppMode = .sceneDescription
    @State private var isDemoMode = false
    @State private var showingInfo = false
    @State private var isAnalyzing = false
    @State private var lastDescription = "Welcome to VisionVoice. Tap the button below to start."
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var hasSpokenWelcome = false
    
    var body: some View {
        ZStack {
            // BACKGROUND
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.05, blue: 0.2),
                    Color(red: 0.05, green: 0.1, blue: 0.25)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // HEADER
                ModernHeader(showingInfo: $showingInfo)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                Spacer().frame(height: 20)
                
                // CAMERA / DEMO DISPLAY
                CameraDisplayCard(
                    camera: camera,
                    isDemoMode: isDemoMode,
                    isAnalyzing: isAnalyzing,
                    selectedMode: selectedMode,
                    onTap: analyzeScene
                )
                .frame(height: UIScreen.main.bounds.height * 0.65)
                .padding(.horizontal, 20)
                
                Spacer().frame(height: 20)
                
                // STATUS
                StatusDisplayCard(
                    lastDescription: lastDescription,
                    isAnalyzing: isAnalyzing,
                    selectedMode: selectedMode
                )
                .padding(.horizontal, 20)
                
                Spacer().frame(height: 20)
                
                // MODE SELECTOR
                ModernModeSelector(
                    selectedMode: $selectedMode,
                    onModeChange: { mode in
                        selectedMode = mode
                        lastDescription = mode.description
                        speakText("Switched to \(mode.rawValue) mode")
                    }
                )
                .padding(.horizontal, 20)
                
                Spacer().frame(height: 16)
                
                // DEMO TOGGLE
                ModernDemoToggle(isDemoMode: $isDemoMode)
                    .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .onAppear {
            camera.refreshAuthorization()
            if camera.authorization == .authorized {
                camera.startIfNeeded()
            }
            pipeline.start(camera: camera)
            
            if !hasSpokenWelcome {
                hasSpokenWelcome = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if self.speechSynthesizer.isSpeaking {
                        self.speechSynthesizer.stopSpeaking(at: .immediate)
                    }
                    self.speakWelcomeMessage()
                }
            }
        }
        .onDisappear {
            camera.stop()
            pipeline.stop()
        }
        .sheet(isPresented: $showingInfo) {
            InfoView(showingInfo: $showingInfo)
        }
    }
    
    // MARK: - Welcome Message
    
    private func speakWelcomeMessage() {
        let message = """
        Welcome to VisionVoice. This app helps you see the world through A I.
        To use camera mode, please allow camera access when prompted.
        Tap the large button to analyze what's in front of you.
        Swipe through the three modes: Scene Description, Read Text, or Object Guide.
        """
        speakText(message)
    }
    
    //  Analysis Entry
    
    private func analyzeScene() {
        guard !isAnalyzing else { return }
        
        // Permission check
        if !isDemoMode && camera.authorization != .authorized {
            lastDescription = "Camera permission required. Enable in Settings or use Demo Mode."
            speakText(lastDescription)
            return
        }
        
        isAnalyzing = true
        lastDescription = "Analyzing..."
        speakText("Analyzing")
        
        pipeline.soundEngine.playDescriptionSound()
        
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            if isDemoMode {
                analyzeDemoImage()
            } else {
                analyzeCamera()
            }
        }
    }
    
    private func analyzeDemoImage() {
        let result = pipeline.recognizer.analyzeDemoImage(assetName: "DEMO")
        processResult(result)
    }
    
    private func analyzeCamera() {
        guard let buffer = camera.latestPixelBuffer() else {
            lastDescription = "No camera frame available"
            speakText(lastDescription)
            isAnalyzing = false
            return
        }
        
        let recognizer = pipeline.recognizer
        
        Task.detached {
            let result = recognizer.analyze(pixelBuffer: buffer)
            
            await MainActor.run {
                self.processResult(result)
            }
        }
    }
    
    // Process Result (ALL MODES)
    
    private func processResult(_ result: VisionResult) {
        switch selectedMode {
        case .sceneDescription:
            lastDescription = result.sceneDescription
            speakText(result.sceneDescription)
            pipeline.soundEngine.update(things: result.things, enabled: true)
            
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                pipeline.soundEngine.update(things: [], enabled: false)
            }
            
        case .readText:
            if result.lines.isEmpty {
                lastDescription = "No text detected. Try pointing at text closer."
                speakText(lastDescription)
            } else {
                let fullText = result.lines.joined(separator: ". ")
                lastDescription = fullText
                speakText(fullText)
            }
            
        case .objectGuide:
            handleObjectGuide(result)
        }
        
        isAnalyzing = false
    }
    
    // Object Guide Logic (FIXED)
    
    private func handleObjectGuide(_ result: VisionResult) {
        // Separate objects and people
        let objects = result.things.filter { $0.kind == .object }
        let people = result.things.filter { $0.kind == .person }
        
        // Combine for listing and also keep order stable
        var allItems = people + objects
        
        // Sort by label to keep output stable / predictable (optional)
        allItems.sort { $0.label.lowercased() < $1.label.lowercased() }
        
        guard !allItems.isEmpty else {
            lastDescription = "No objects detected. Try pointing at something with good lighting."
            speakText(lastDescription)
            pipeline.soundEngine.update(things: [], enabled: false)
            return
        }
        
        let topItems = Array(allItems.prefix(10))
        let itemNames = topItems.map { $0.label.lowercased() }
        
        var description: String
        
        if itemNames.count == 1 {
            description = "I found one item: \(itemNames[0])"
        } else if itemNames.count == 2 {
            description = "I found two items: \(itemNames[0]) and \(itemNames[1])"
        } else if itemNames.count <= 5 {
            let list = itemNames.joined(separator: ", ")
            description = "I found \(itemNames.count) items: \(list)"
        } else {
            let firstFive = itemNames.prefix(5).joined(separator: ", ")
            let remaining = itemNames.count - 5
            description = "I found \(itemNames.count) items: \(firstFive), and \(remaining) more"
        }
        
        lastDescription = description
        speakText(description)
        
        // Feed only the top items to sound engine so it doesn't overwhelm
        pipeline.soundEngine.update(things: topItems, enabled: true)
        
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            pipeline.soundEngine.update(things: [], enabled: false)
        }
    }
    
    // Speech
    
    private func speakText(_ text: String) {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback,
                                                            mode: .spokenAudio,
                                                            options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true,
                                                          options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ Audio session error: \(error)")
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.volume = 1.0
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.1
        
        speechSynthesizer.speak(utterance)
    }
}

// MODERN HEADER

struct ModernHeader: View {
    @Binding var showingInfo: Bool
    
    var body: some View {
        HStack {
            Text("VisionVoice")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: {
                showingInfo = true
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(0.4),
                                    Color.purple.opacity(0.3)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
            }
            .accessibilityLabel("Information")
            .accessibilityHint("Double tap to learn about VisionVoice")
        }
    }
}

// CAMERA DISPLAY CARD

struct CameraDisplayCard: View {
    @ObservedObject var camera: CameraModel
    let isDemoMode: Bool
    let isAnalyzing: Bool
    let selectedMode: AppMode
    let onTap: () -> Void
    
    var body: some View {
        ZStack {
            if isDemoMode {
                ModernDemoView()
            } else if camera.authorization == .authorized && camera.isRunning {
                CameraPreview(session: camera.session)
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        selectedMode.gradientColors[0],
                                        selectedMode.gradientColors[1]
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
                    .shadow(color: selectedMode.gradientColors[0].opacity(0.5),
                            radius: 20,
                            x: 0,
                            y: 10)
            } else {
                ModernPermissionView(camera: camera)
            }
            
            // Mode badge
            VStack {
                HStack {
                    Spacer()
                    ModernModeBadge(mode: selectedMode)
                        .padding(15)
                }
                Spacer()
            }
            
            // Analyzing overlay
            if isAnalyzing {
                ZStack {
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.black.opacity(0.6))
                    
                    VStack(spacing: 15) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("Analyzing...")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .onTapGesture {
            onTap()
        }
    }
}

//  MODERN DEMO VIEW

struct ModernDemoView: View {
    var body: some View {
        ZStack {
            if let image = UIImage(named: "DEMO") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 25))
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.purple.opacity(0.4),
                        Color.blue.opacity(0.4)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 25))
                
                VStack(spacing: 15) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("Demo Mode")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Tap to analyze sample image")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [.purple, .blue]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
        )
        .shadow(color: Color.purple.opacity(0.5), radius: 20, x: 0, y: 10)
    }
}

//  MODERN PERMISSION VIEW

struct ModernPermissionView: View {
    @ObservedObject var camera: CameraModel
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.3),
                    Color.cyan.opacity(0.3)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 25))
            
            VStack(spacing: 20) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.white.opacity(0.9))
                
                Text("Camera Access Needed")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("VisionVoice needs camera access to see your surroundings")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                Button(action: {
                    camera.requestPermission()
                }) {
                    Text("Grant Permission")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: 250)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .cyan]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                        .shadow(color: .blue.opacity(0.5), radius: 10, x: 0, y: 5)
                }
                .padding(.top, 5)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .cyan]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
        )
        .shadow(color: Color.blue.opacity(0.5), radius: 20, x: 0, y: 10)
    }
}

// MODE BADGE

struct ModernModeBadge: View {
    let mode: AppMode
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: mode.icon)
                .font(.system(size: 15, weight: .semibold))
            
            Text(mode.rawValue)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: mode.gradientColors),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: mode.gradientColors[0].opacity(0.6),
                        radius: 8,
                        x: 0,
                        y: 4)
        )
    }
}

// STATUS DISPLAY CARD

struct StatusDisplayCard: View {
    let lastDescription: String
    let isAnalyzing: Bool
    let selectedMode: AppMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: isAnalyzing ? "waveform" : "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(selectedMode.gradientColors[0])
                
                Text(isAnalyzing ? "Analyzing..." : "Ready")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            Text(lastDescription)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .accessibilityElement(children: .combine)
    }
}

//MODERN MODE SELECTOR

struct ModernModeSelector: View {
    @Binding var selectedMode: AppMode
    let onModeChange: (AppMode) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(AppMode.allCases) { mode in
                ModernModeButton(
                    mode: mode,
                    isSelected: selectedMode == mode,
                    action: {
                        selectedMode = mode
                        onModeChange(mode)
                    }
                )
            }
        }
    }
}

//MODERN MODE BUTTON

struct ModernModeButton: View {
    let mode: AppMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                            ? LinearGradient(
                                gradient: Gradient(colors: mode.gradientColors),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(
                            color: isSelected ? mode.gradientColors[0].opacity(0.6) : .clear,
                            radius: 12,
                            x: 0,
                            y: 6
                        )
                    
                    Image(systemName: mode.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                }
                
                Text(mode.shortName)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(mode.rawValue)
        .accessibilityHint("Double tap to switch to \(mode.rawValue) mode")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MODERN DEMO TOGGLE

struct ModernDemoToggle: View {
    @Binding var isDemoMode: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isDemoMode ? "photo.fill" : "camera.fill")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
            
            Text("Demo Mode")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
            
            Toggle("", isOn: $isDemoMode)
                .labelsHidden()
                .tint(Color.blue)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
}
