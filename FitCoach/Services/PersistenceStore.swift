import Foundation
import UIKit

/// Simple Codable-JSON persistence in Application Support, plus JPEG storage
/// for check-in photos. Deliberately dependency-free; can be swapped for
/// SwiftData later without touching the views.
enum PersistenceStore {

    private static var baseURL: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FitCoach", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static var photosURL: URL {
        let url = baseURL.appendingPathComponent("Photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func save<T: Encodable>(_ value: T, as name: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(value) {
            try? data.write(to: baseURL.appendingPathComponent("\(name).json"), options: .atomic)
        }
    }

    static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        let url = baseURL.appendingPathComponent("\(name).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }

    // MARK: Photos

    @discardableResult
    static func savePhoto(_ image: UIImage, id: UUID) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        let filename = "\(id.uuidString).jpg"
        do {
            try data.write(to: photosURL.appendingPathComponent(filename), options: .atomic)
            return filename
        } catch { return nil }
    }

    static func loadPhoto(filename: String) -> UIImage? {
        UIImage(contentsOfFile: photosURL.appendingPathComponent(filename).path)
    }
}
