import Foundation
import CoreGraphics
import SwiftUI  

enum AppMode: String, CaseIterable, Identifiable {
    case sceneDescription = "Scene"
    case readText = "Read"
    case objectGuide = "Objects"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .sceneDescription: return "eye.fill"
        case .readText: return "doc.text.fill"  
        case .objectGuide: return "cube.fill"    
        }
    }
    
    var description: String {
        switch self {
        case .sceneDescription: return "Hear your surroundings described with spatial audio"
        case .readText: return "Read text from labels, signs, and documents"
        case .objectGuide: return "Identify and locate specific objects"
        }
    }
    
   
    var gradientColors: [Color] {
        switch self {
        case .sceneDescription: return [.cyan, .blue]
        case .readText: return [.green, .mint]
        case .objectGuide: return [.purple, .pink]
        }
    }
    
    var shortName: String {
        switch self {
        case .sceneDescription: return "Scene"
        case .readText: return "Read"
        case .objectGuide: return "Objects"
        }
    }
}

enum DetectedKind: String, CaseIterable {
    case person
    case object
    case text
    case surface
}

struct DetectedThing: Identifiable {
    let id = UUID()
    let kind: DetectedKind
    let boundingBox: CGRect
    let label: String
    let confidence: Float
}

struct VisionResult {
    var things: [DetectedThing] = []
    var lines: [String] = []
    var sceneDescription: String = ""
}
