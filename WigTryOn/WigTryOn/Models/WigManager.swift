import Foundation
import SwiftUI
import Combine

class WigManager: ObservableObject {
    @Published var wigs: [Wig] = []
    @Published var currentWig: Wig?
    @Published var scale: Double = 1.0
    @Published var offsetX: Double = 0.0
    @Published var offsetY: Double = 0.0
    @Published var offsetZ: Double = 0.0
    
    init() {
        loadWigs()
    }
    
    func loadWigs() {
        var loadedWigs: [Wig] = []

        // Search the bundle for supported 3D model files
        let extensions = ["glb", "usdz", "scn", "dae"]
        for ext in extensions {
            if let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
                for url in urls {
                    let name = url.deletingPathExtension().lastPathComponent
                        .replacingOccurrences(of: "_", with: " ")
                        .capitalized
                    let wig = Wig(id: url.lastPathComponent, name: name, modelURL: url)
                    loadedWigs.append(wig)
                }
            }
        }

        if loadedWigs.isEmpty {
            loadedWigs = Wig.samples
        }

        // Put Brown Layered Wig first as the default
        let preferred = "Brown_Layered_Wig"
        if let idx = loadedWigs.firstIndex(where: { $0.id.contains(preferred) }) {
            let wig = loadedWigs.remove(at: idx)
            loadedWigs.insert(wig, at: 0)
        }

        wigs = loadedWigs
        currentWig = wigs.first
    }
    
    func selectWig(_ wig: Wig) {
        currentWig = wig
    }
    
    func nextWig() {
        guard let current = currentWig,
              let index = wigs.firstIndex(of: current) else {
            currentWig = wigs.first
            return
        }
        
        let nextIndex = (index + 1) % wigs.count
        currentWig = wigs[nextIndex]
    }
    
    func previousWig() {
        guard let current = currentWig,
              let index = wigs.firstIndex(of: current) else {
            currentWig = wigs.first
            return
        }
        
        let prevIndex = (index - 1 + wigs.count) % wigs.count
        currentWig = wigs[prevIndex]
    }
    
    func reset() {
        scale = 1.0
        offsetX = 0.0
        offsetY = 0.0
        offsetZ = 0.0
    }
}
