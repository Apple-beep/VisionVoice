# VisionVoice 👁️🔊

> **An iOS accessibility app that helps visually impaired users understand their surroundings through real-time on-device image analysis and spatial audio feedback.**

![Swift](https://img.shields.io/badge/Swift-6.0-orange?logo=swift)
![iOS](https://img.shields.io/badge/iOS-16.0%2B-blue?logo=apple)
![Platform](https://img.shields.io/badge/Platform-iPhone%20%7C%20iPad-lightgrey)
![License](https://img.shields.io/badge/License-MIT-green)
![WCAG](https://img.shields.io/badge/Accessibility-WCAG%202.1%20AA-brightgreen)

## 📖 Overview

**VisionVoice** is an iOS accessibility application built in Swift 6 for visually impaired and low-vision users. It uses Apple's **Vision framework**, **AVFoundation**, and a custom **SoundscapeEngine** to analyze the live camera feed and return spoken and spatial audio feedback — with **no internet connection required**, ensuring complete privacy.

The app offers three analysis modes, spatial audio positioning for detected objects, live text-to-speech narration, and a safe **Demo Mode** that works without a physical camera — all built with WCAG 2.1 AA accessibility standards in mind.

## ✨ Features

| Feature | Description |
|---|---|
| 🎙️ **Scene Description** | Narrates a natural-language description of your surroundings using on-device Vision analysis |
| 📄 **Read Text** | OCR text recognition from signs, labels, books, and documents |
| 📦 **Object Guide** | Identifies and names up to 10 objects or people in frame |
| 🔊 **Spatial Audio** | 3D positional tones map detected objects to left/right/up/down in your audio space |
| 🗣️ **Text-to-Speech** | All results spoken aloud via `AVSpeechSynthesizer` at a comfortable pace |
| 🧪 **Demo Mode** | Fully functional without a camera — analyzes a built-in sample image |
| 🔒 **100% On-Device** | All processing runs locally — no data sent to any server |
| ♿ **WCAG 2.1 AA** | VoiceOver-compatible, accessibility labels and hints on every control |

## 🖼️ Demo

> Toggle **Demo Mode** in the app to analyze a built-in sample image without needing camera access.

<p align="center">
  <img src="demo.jpeg" alt="VisionVoice App Screenshot" width="300"/>
</p>

## 🏗️ Architecture

VisionVoice follows a modular pipeline architecture with clear separation of concerns:

```text
┌─────────────────────────────────────────────────────────┐
│                     ContentView (UI)                    │
│   Mode Selector │ Camera Display │ Status Card │ TTS    │
└────────────────────────┬────────────────────────────────┘
                         │
              ┌──────────▼──────────┐
              │   CameraPipeline    │  ← Orchestrates all subsystems
              └──┬──────────────┬───┘
                 │              │
    ┌────────────▼──┐     ┌─────▼───────────┐
    │  CameraModel  │     │ VisionRecognizer │
    │  AVCapture    │     │  Vision + OCR    │
    │  Session Mgmt │     │  On-Device       │
    └───────────────┘     └────────┬─────────┘
                                   │
                        ┌──────────▼──────────┐
                        │  SoundscapeEngine   │
                        │  AVAudioEngine +    │
                        │  3D Spatial Audio   │
                        └─────────────────────┘
```

## 📂 File Structure

```text
VisionVoice/
├── MyApp.swift              # App entry point (@main)
├── ContentView.swift        # Root SwiftUI view, mode switching, TTS orchestration
├── CameraModel.swift        # AVCaptureSession management, pixel buffer streaming
├── CameraPipeline.swift     # Connects CameraModel → VisionRecognizer → SoundscapeEngine
├── CameraPreview.swift      # UIViewRepresentable for live camera preview layer
├── Visionrecognizer.swift   # Vision inference: scene description, OCR, object detection
├── SoundscapeEngine.swift   # AVAudioEngine + 3D spatial tones per detected entity
├── Models.swift             # Shared data models: AppMode, DetectedThing, VisionResult
├── infoview.swift           # In-app help/about sheet
├── MoreInfo.plist           # App metadata / info plist
├── Package.swift            # Swift Package Manager manifest (iOS 16+, Swift 6)
├── Contents.json            # Asset catalog metadata
├── AppIcon.png              # Application icon
└── demo.jpeg                # Sample image used in Demo Mode
```


## 🧠 How It Works

### 1. Camera Pipeline
`CameraModel` sets up a high-quality `AVCaptureSession`, streams frames as `CVPixelBuffer` on a dedicated `DispatchQueue`, and exposes the latest frame thread-safely via an `NSLock`. `CameraPreview` renders the live feed using a `CALayer`-backed `UIViewRepresentable`.

### 2. Vision Recognition
On each analysis tap, a `CVPixelBuffer` is passed to `VisionRecognizer`, which runs:
- **Object & Person Detection** — Apple's Vision framework classifiers
- **OCR** — `VNRecognizeTextRequest` for reading text from images at accurate recognition level
- **Scene Description** — Constructs a natural-language sentence from detection results, including position descriptors (e.g., *"left", "center", "upper right"*)

All processing runs **on-device** via the Vision framework with no network calls.

### 3. Three App Modes

| Mode | Behavior |
|---|---|
| **Scene Description** | Speaks a full natural-language scene summary + activates spatial audio tones |
| **Read Text** | Reads out all detected lines of text joined with pauses |
| **Object Guide** | Lists detected objects/people by name (up to 10) + activates spatial audio |

### 4. Spatial Audio
Each detected entity type is assigned a distinct sine-wave tone frequency:

| Entity | Frequency | Character |
|---|---|---|
| Person | 440 Hz (A4) | Warm, human |
| Object | 330 Hz (E4) | Neutral |
| Text | 550 Hz (C#5) | High, attention |
| Surface | 220 Hz (A3) | Low, grounding |

`AVAudioEnvironmentNode` positions each tone in 3D space based on the object's **bounding box center** in the camera frame — objects on the left sound from the left, objects above sound from above. Volume scales with confidence score and bounding box size.

### 5. Text-to-Speech
All results are spoken via `AVSpeechSynthesizer` with:
- Rate: `0.5` (comfortable listening pace)
- Voice: `en-US`
- Audio session category: `.playback` with `.duckOthers` — VisionVoice automatically ducks background audio
  
## ⚙️ Requirements

| Requirement | Value |
|---|---|
| iOS | 16.0+ |
| Swift | 6.0 |
| Xcode | 15.0+ (Swift Playgrounds 4.5+ compatible) |
| Device | iPhone or iPad with rear camera |
| Permissions | Camera |
| Network | ❌ Not required — fully offline |

## 🚀 Getting Started

### Option A: Swift Playgrounds (Recommended)
1. Clone or download this repository.
2. Open **Swift Playgrounds** on iPad or Mac.
3. Tap **"Open"** and select the `VisionVoice` folder.
4. Tap ▶️ **Run** — the app launches instantly.
5. Grant camera permission when prompted.

### Option B: Xcode
```bash
git clone https://github.com/Apple-beep/VisionVoice.git
cd VisionVoice
Open Package.swift in Xcode 15+.

Select your target device or simulator.

Build & Run (⌘R).

Grant camera permission on first launch.

Note: Demo Mode works on the simulator — live camera requires a physical device.
```

🎮 Usage
Launch the app — A welcome message is spoken automatically.

Select a mode at the bottom: Scene, Read, or Objects.

Point your camera at your surroundings.

Tap the camera display to analyze the current frame.

Listen to the spoken result and the spatial audio tones.

Toggle Demo Mode at the bottom to test without camera access.

♿ Accessibility
VisionVoice is designed first for accessibility:

Every interactive control has .accessibilityLabel and .accessibilityHint

Mode buttons announce "Double tap to switch to [mode] mode"

Welcome message is spoken automatically on first launch

Audio session uses .duckOthers to not conflict with other assistive audio

The entire UI is navigable via VoiceOver

Compliant with WCAG 2.1 AA standards

🛠️ Tech Stack
SwiftUI — Declarative UI with @StateObject, @Published, @MainActor

AVFoundation — Camera session, speech synthesis, 3D audio engine

Vision Framework — On-device object detection and text recognition (OCR)

AVAudioEngine + AVAudioEnvironmentNode — Spatial 3D soundscape

Swift 6 Concurrency — async/await, Task.detached, @MainActor for thread safety

Swift Package Manager — Dependency and build management

🔐 Privacy
VisionVoice processes all data entirely on-device:

❌ No analytics

❌ No external APIs

❌ No data collection

✅ Camera frames are analyzed in memory and immediately discarded

✅ Works fully offline

🤝 Contributing
Contributions are welcome! Here's how to get started:

bash
# Fork the repo, then:
git checkout -b feature/your-feature-name
git commit -m "Add: your feature description"
git push origin feature/your-feature-name
# Open a Pull Request
Please ensure your code:

Follows Swift 6 concurrency rules (@MainActor, Sendable)

Maintains or improves accessibility coverage

Runs cleanly on iOS 16+

📄 License
This project is licensed under the MIT License — see the LICENSE file for details.

👤 Author
Musharaf Khan Pathan
Illinois Institute of Technology, Chicago
GitHub: @Apple-beep

<p align="center"> <em>Built with ❤️ for the visually impaired community — because everyone deserves to experience the world.</em> </p> 
