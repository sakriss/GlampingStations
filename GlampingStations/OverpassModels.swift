//
//  OverpassModels.swift
//  GlampingStations
//

import Foundation

struct OverpassResponse: Codable {
    let elements: [OverpassElement]
}

struct OverpassElement: Codable {
    let type: String
    let id: Int64
    let lat: Double?
    let lon: Double?
    let center: OverpassCenter?
    let tags: [String: String]?

    /// Latitude that works for both nodes (lat) and ways (center.lat)
    var effectiveLat: Double? { lat ?? center?.lat }
    /// Longitude that works for both nodes (lon) and ways (center.lon)
    var effectiveLon: Double? { lon ?? center?.lon }
}

struct OverpassCenter: Codable {
    let lat: Double
    let lon: Double
}
