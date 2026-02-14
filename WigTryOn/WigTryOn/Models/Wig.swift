import Foundation
import UIKit

struct Wig: Identifiable, Equatable {
    let id: String
    let name: String
    let modelURL: URL?
    let thumbnail: UIImage?
    
    init(id: String, name: String, modelURL: URL?, thumbnail: UIImage? = nil) {
        self.id = id
        self.name = name
        self.modelURL = modelURL
        self.thumbnail = thumbnail
    }
    
    static func == (lhs: Wig, rhs: Wig) -> Bool {
        lhs.id == rhs.id
    }
}

// Sample wigs for testing
extension Wig {
    static let samples: [Wig] = [
        Wig(id: "short_black", name: "Short Black", modelURL: nil),
        Wig(id: "long_brown", name: "Long Brown", modelURL: nil),
        Wig(id: "curly_blonde", name: "Curly Blonde", modelURL: nil),
        Wig(id: "bob_red", name: "Bob Red", modelURL: nil),
        Wig(id: "afro", name: "Afro", modelURL: nil),
    ]
}
