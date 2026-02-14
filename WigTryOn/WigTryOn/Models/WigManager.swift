import Foundation
import SwiftUI
import Combine

class WigManager: ObservableObject {
    @Published var wigs: [Wig] = []
    @Published var currentWig: Wig?
    @Published var scale: Double = 1.0
    @Published var offsetX: Double = 0.0
    @Published var offsetY: Double = 0.0
    
    init() {
        loadWigs()
    }
    
    func loadWigs() {
        // Load wigs from bundle
        var loadedWigs: [Wig] = []
        
        // Check for .usdz and .scn files in Wigs folder
        if let wigsURL = Bundle.main.resourceURL?.appendingPathComponent("Wigs") {
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: wigsURL,
                    includingPropertiesForKeys: nil
                )
                
                for url in contents {
                    let ext = url.pathExtension.lowercased()
                    if ["usdz", "scn", "dae"].contains(ext) {
                        let name = url.deletingPathExtension().lastPathComponent
                            .replacingOccurrences(of: "_", with: " ")
                            .capitalized
                        
                        let wig = Wig(
                            id: url.lastPathComponent,
                            name: name,
                            modelURL: url
                        )
                        loadedWigs.append(wig)
                    }
                }
            } catch {
                print("Error loading wigs: \(error)")
            }
        }
        
        // If no wigs found, use samples for demo
        if loadedWigs.isEmpty {
            loadedWigs = Wig.samples
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
    
    func adjustScale(_ delta: Double) {
        scale = max(0.5, min(1.5, scale + delta))
    }
    
    func adjustPosition(dx: Double, dy: Double) {
        offsetX += dx
        offsetY += dy
    }
    
    func reset() {
        scale = 1.0
        offsetX = 0.0
        offsetY = 0.0
    }
}
