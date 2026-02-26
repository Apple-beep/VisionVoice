
@preconcurrency import Vision
import Foundation
import CoreVideo
import CoreImage
import UIKit

final class VisionRecognizer: @unchecked Sendable {
    
    private let ciContext = CIContext()
    
    func analyze(pixelBuffer: CVPixelBuffer) -> VisionResult {
        var out = VisionResult()
        
        // Text detection 
        let textReq = VNRecognizeTextRequest()
        textReq.recognitionLevel = .accurate
        textReq.usesLanguageCorrection = true
        textReq.minimumTextHeight = 0.02
        textReq.recognitionLanguages = ["en-US"]
        
        // Scene classification
        let sceneReq = VNClassifyImageRequest()
        
        // Face detection
        let faceReq = VNDetectFaceRectanglesRequest()
        
        // Animal detection
        let animalReq = VNRecognizeAnimalsRequest()
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .up,
                                            options: [:])
        
        do {
            try handler.perform([textReq, sceneReq, faceReq, animalReq])
        } catch {
            print("❌ Vision failed: \(error)")
            return out
        }
        
        // Process faces as people
        if let faces = faceReq.results as? [VNFaceObservation] {
            for f in faces.prefix(5) {
                out.things.append(
                    DetectedThing(kind: .person,
                                  boundingBox: f.boundingBox,
                                  label: "Person",
                                  confidence: f.confidence)
                )
            }
        }
        
        // Process animals - FIXED CAST
        if let animals = animalReq.results as? [VNRecognizedObjectObservation] {
            for animal in animals.prefix(3) where animal.confidence > 0.5 {
                if let label = animal.labels.first?.identifier.capitalized {
                    out.things.append(
                        DetectedThing(kind: .object,
                                      boundingBox: animal.boundingBox,
                                      label: label,
                                      confidence: animal.confidence)
                    )
                }
            }
        }
        
        // Process scene classifications - IMPROVED FILTERING
        if let scenes = sceneReq.results as? [VNClassificationObservation] {
            let meaningfulScenes = scenes
                .prefix(20)
                .filter { scene in
                    scene.confidence > 0.12 && !self.isVagueLabel(scene.identifier)
                }
            
            for scene in meaningfulScenes.prefix(10) {
                let cleanLabel = self.cleanObjectLabel(scene.identifier)
                let centerBox = CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)
                
                out.things.append(
                    DetectedThing(kind: .object,
                                  boundingBox: centerBox,
                                  label: cleanLabel,
                                  confidence: scene.confidence)
                )
            }
        }
        
        // Process text 
        if let texts = textReq.results as? [VNRecognizedTextObservation] {
            var lines: [String] = []
            
            for t in texts {
                guard let top = t.topCandidates(1).first else { continue }
                let s = top.string.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if s.count > 1 && !self.isNoiseText(s) {
                    lines.append(s)
                }
            }
            
            out.lines = Array(lines.prefix(20))
            
            for t in texts.prefix(6) {
                guard let top = t.topCandidates(1).first else { continue }
                let s = top.string.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if s.count > 1 && !self.isNoiseText(s) {
                    out.things.append(
                        DetectedThing(kind: .text,
                                      boundingBox: t.boundingBox,
                                      label: s,
                                      confidence: top.confidence)
                    )
                }
            }
        }
        
        out.sceneDescription = generateSceneDescription(from: out.things)
        
        return out
    }
    
    func analyzeDemoImage(assetName: String) -> VisionResult {
        guard let img = UIImage(named: assetName) else {
            print("❌ Could not load image named: '\(assetName)'")
            return VisionResult(
                things: [],
                lines: [],
                sceneDescription: "Demo image '\(assetName)' not found in assets."
            )
        }
        
        print("✅ Loaded demo image: \(assetName)")
        
        guard let cg = img.cgImage else {
            print("❌ Could not get CGImage from UIImage")
            return VisionResult(
                things: [],
                lines: [],
                sceneDescription: "Unable to process demo image format."
            )
        }
        
        var out = VisionResult()
        
        let textReq = VNRecognizeTextRequest()
        textReq.recognitionLevel = .accurate
        textReq.usesLanguageCorrection = true
        textReq.minimumTextHeight = 0.02
        textReq.recognitionLanguages = ["en-US"]
        
        let sceneReq = VNClassifyImageRequest()
        let faceReq = VNDetectFaceRectanglesRequest()
        let animalReq = VNRecognizeAnimalsRequest()
        
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
        
        do {
            try handler.perform([textReq, sceneReq, faceReq, animalReq])
            print("✅ Vision analysis completed successfully")
        } catch {
            print("❌ Vision analysis failed: \(error)")
            return VisionResult(
                things: [],
                lines: [],
                sceneDescription: "Vision analysis failed."
            )
        }
        
        // Process faces 
        if let faces = faceReq.results as? [VNFaceObservation] {
            print("👤 Found \(faces.count) faces")
            for f in faces.prefix(5) {
                out.things.append(
                    DetectedThing(kind: .person,
                                  boundingBox: f.boundingBox,
                                  label: "Person",
                                  confidence: f.confidence)
                )
            }
        }
        
        // Process animals 
        if let animals = animalReq.results as? [VNRecognizedObjectObservation] {
            print("🐾 Found \(animals.count) animals")
            for animal in animals.prefix(3) where animal.confidence > 0.5 {
                if let label = animal.labels.first?.identifier.capitalized {
                    print("   - \(label): \(animal.confidence)")
                    out.things.append(
                        DetectedThing(kind: .object,
                                      boundingBox: animal.boundingBox,
                                      label: label,
                                      confidence: animal.confidence)
                    )
                }
            }
        }
        
        // Process scene classifications
        if let scenes = sceneReq.results as? [VNClassificationObservation] {
            print("🔍 Found \(scenes.count) scene classifications")
            
            let meaningfulScenes = scenes
                .prefix(25)
                .filter { scene in
                    scene.confidence > 0.10 && !self.isVagueLabel(scene.identifier)
                }
            
            for scene in meaningfulScenes.prefix(12) {
                let cleanLabel = self.cleanObjectLabel(scene.identifier)
                print("   - \(cleanLabel): \(scene.confidence)")
                
                let centerBox = CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)
                
                out.things.append(
                    DetectedThing(kind: .object,
                                  boundingBox: centerBox,
                                  label: cleanLabel,
                                  confidence: scene.confidence)
                )
            }
        }
        
        // Process text 
        if let texts = textReq.results as? [VNRecognizedTextObservation] {
            print("📝 Found \(texts.count) text observations")
            var lines: [String] = []
            
            for t in texts {
                guard let top = t.topCandidates(1).first else { continue }
                let s = top.string.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if s.count > 1 && !self.isNoiseText(s) {
                    lines.append(s)
                    print("   - Text: \(s)")
                }
            }
            
            out.lines = Array(lines.prefix(20))
            
            for t in texts.prefix(6) {
                guard let top = t.topCandidates(1).first else { continue }
                let s = top.string.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if s.count > 1 && !self.isNoiseText(s) {
                    out.things.append(
                        DetectedThing(kind: .text,
                                      boundingBox: t.boundingBox,
                                      label: s,
                                      confidence: top.confidence)
                    )
                }
            }
        }
        
        out.sceneDescription = generateSceneDescription(from: out.things)
        print("🗣️ Generated description: \(out.sceneDescription)")
        
        return out
    }
    
    private func isNoiseText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.count <= 1 {
            return true
        }
        
        let numbersAndPunctuation = CharacterSet.decimalDigits.union(.punctuationCharacters).union(.whitespaces)
        if trimmed.unicodeScalars.allSatisfy({ numbersAndPunctuation.contains($0) }) {
            return true
        }
        
        return false
    }
    
    private func isVagueLabel(_ label: String) -> Bool {
        let lowercased = label.lowercased()
        
        if lowercased.contains("scene") { return true }
        if lowercased.contains("view") { return true }
        if lowercased.contains("image") { return true }
        if lowercased.contains("photo") { return true }
        if lowercased.contains("picture") { return true }
        if lowercased.contains("background") { return true }
        if lowercased.contains("foreground") { return true }
        if lowercased.contains("lighting") { return true }
        if lowercased.contains("color") { return true }
        if lowercased.contains("pattern") { return true }
        if lowercased.contains("texture") { return true }
        if lowercased.contains("indoors") { return true }
        if lowercased.contains("outdoors") { return true }
        if lowercased.contains("daytime") { return true }
        if lowercased.contains("nighttime") { return true }
        
        return false
    }

    private func cleanObjectLabel(_ label: String) -> String {
        var cleaned = label
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
        
        let mappings: [String: String] = [
            // Kitchen
            "Tabletop": "Table",
            "Kitchen": "Kitchen items",
            "Countertop": "Counter",
            "Cabinetry": "Cabinets",
            "Kitchen Utensil": "Utensils",
            "Cookware And Bakeware": "Cookware",
            "Home Appliance": "Kitchen appliance",
            "Major Appliance": "Appliance",
            "Stove": "Stove",
            "Oven": "Oven",
            
            // Food
            "Produce": "Fresh produce",
            "Fruit": "Fruit",
            "Vegetable": "Vegetables",
            "Food": "Food items",
            "Ingredient": "Ingredients",
            "Citrus": "Citrus fruit",
            "Natural Foods": "Natural food",
            "Banana": "Bananas",
            "Apple": "Apples",
            "Orange": "Oranges",
            
            // Drinks
            "Beverage": "Drink",
            "Drinkware": "Cup",
            "Bottle": "Bottle",
            "Water": "Water bottle",
            "Cup": "Cup",
            "Mug": "Mug",
            
            // Objects
            "Hand Tool": "Tools",
            "Office Supplies": "Office items",
            "Electronic Device": "Device",
            "Food Container": "Container",
            "Container": "Container",
            "Bowl": "Bowl",
            "Plate": "Plates",
            "Dishware": "Dishes",
            
            // Other
            "Eyewear": "Glasses",
            "Clock": "Clock",
            "Calendar": "Calendar",
            "Shelf": "Shelving",
            "Plant": "Plant",
            "Flowerpot": "Potted plant",
            "Houseplant": "House plant",
            "Furniture": "Furniture",
            "Person": "Person",
            "Adult": "Person",
            "Book": "Book",
            "Publication": "Book or magazine",
            "Text": "Printed text",
            "Medicine": "Medicine",
            "Pharmaceutical Drug": "Medication",
            "Pill Bottle": "Medicine bottle",
            "Keys": "Keys",
            "Phone": "Phone",
            "Smartphone": "Phone"
        ]
        
        return mappings[cleaned] ?? cleaned
    }
    
    private func generateSceneDescription(from things: [DetectedThing]) -> String {
        if things.isEmpty {
            return "I don't see any recognizable objects. Try pointing the camera at something with good lighting."
        }
        
        let people = things.filter { $0.kind == .person }
        let objects = things.filter { $0.kind == .object }
        let texts = things.filter { $0.kind == .text }
        
        var parts: [String] = []
        
        // Describe people
        if people.count == 1 {
            parts.append("There is one person in the scene")
        } else if people.count == 2 {
            parts.append("I see two people")
        } else if people.count > 2 {
            parts.append("I see \(people.count) people")
        }
        
        // Describe objects 
        if !objects.isEmpty {
            let topObjects = Array(objects.prefix(10))
            
            if topObjects.count == 1 {
                parts.append("I can see \(topObjects[0].label.lowercased())")
            } else if topObjects.count == 2 {
                parts.append("I can see \(topObjects[0].label.lowercased()) and \(topObjects[1].label.lowercased())")
            } else if topObjects.count <= 5 {
                let objectList = topObjects.map { $0.label.lowercased() }.joined(separator: ", ")
                parts.append("I can see: \(objectList)")
            } else {
                // List first 5, then say "and X more"
                let first5 = topObjects.prefix(5).map { $0.label.lowercased() }.joined(separator: ", ")
                let remaining = topObjects.count - 5
                parts.append("I can see: \(first5), and \(remaining) other \(remaining == 1 ? "item" : "items")")
            }
        }
        
        
        if texts.count > 0 {
            parts.append("with some text visible")
        }
        
        return parts.joined(separator: ". ") + "."
    }
    
    private func describePosition(_ bbox: CGRect) -> String {
        let centerX = bbox.midX
        let centerY = bbox.midY
        
        var horizontal = ""
        if centerX < 0.3 {
            horizontal = "on your left"
        } else if centerX > 0.7 {
            horizontal = "on your right"
        } else {
            horizontal = "directly in front of you"
        }
        
        var vertical = ""
        if centerY < 0.3 {
            vertical = ", positioned low"
        } else if centerY > 0.7 {
            vertical = ", positioned high"
        }
        
        return horizontal + vertical
    }
}

