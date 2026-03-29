//
//  OverpassService.swift
//  GlampingStations
//

import Foundation
import CoreLocation

class OverpassService {

    static let shared = OverpassService()
    private init() {}

    private let endpoint = URL(string: "https://overpass-api.de/api/interpreter")!
    private let userAgent = "GlampingStationsApp/1.0 (scottkriss@gmail.com)"
    private let cacheTTL: TimeInterval = 60 * 60 * 24  // 24 hours

    // MARK: - Public API

    func fetchGasStations(near location: CLLocation) async throws -> [OverpassElement] {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let radius = 80_000  // ~50 miles

        // Fetch ALL fuel stations in a single pass. Complex multi-clause queries
        // with regex brand matching cause Overpass to timeout (verified: 24-clause
        // query returns 0 results after 69s for Kellogg, ID; this simple query
        // returns 142 stations in ~3s for the same location).
        // Brand detection, diesel inference, and truck-stop classification are
        // handled client-side in OverpassParser.toStation().
        let query = """
        [out:json][timeout:30];
        (
          node["amenity"="fuel"](around:\(radius),\(lat),\(lon));
          way["amenity"="fuel"](around:\(radius),\(lat),\(lon));
        );
        out body center;
        """
        return try await fetchElements(query: query, cacheKey: "gas", gridKey: gridKey(for: location))
    }

    func fetchDumpStations(near location: CLLocation, radiusMeters: Double = 100_000) async throws -> [OverpassElement] {
        let query = """
        [out:json][timeout:30][maxsize:536870912];
        (
          node["amenity"="sanitary_dump_station"](around:\(Int(radiusMeters)),\(location.coordinate.latitude),\(location.coordinate.longitude));
          way["amenity"="sanitary_dump_station"](around:\(Int(radiusMeters)),\(location.coordinate.latitude),\(location.coordinate.longitude));
        );
        out body center;
        """
        return try await fetchElements(query: query, cacheKey: "dump", gridKey: gridKey(for: location))
    }

    // MARK: - Private

    private func gridKey(for location: CLLocation) -> String {
        // 0.5-degree buckets (~55km cells) to reuse cache for nearby queries
        let latBucket = Int(location.coordinate.latitude * 2)
        let lonBucket = Int(location.coordinate.longitude * 2)
        return "\(latBucket)_\(lonBucket)"
    }

    private func cacheURL(cacheKey: String, gridKey: String) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("cached_overpass_\(cacheKey)_\(gridKey).json")
    }

    private func fetchElements(query: String, cacheKey: String, gridKey: String) async throws -> [OverpassElement] {
        // Check cache first
        if let url = cacheURL(cacheKey: cacheKey, gridKey: gridKey),
           let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let modDate = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(modDate) < cacheTTL,
           let data = try? Data(contentsOf: url),
           let cached = try? JSONDecoder().decode(OverpassResponse.self, from: data) {
            return cached.elements
        }

        // Fetch from network
        var request = URLRequest(url: endpoint, timeoutInterval: 35)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        // Use a strict character set for form-value encoding — must encode &, =, +, and "
        var formAllowed = CharacterSet.urlQueryAllowed
        formAllowed.remove(charactersIn: "&=+\"[]")
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: formAllowed) ?? query
        request.httpBody = "data=\(encodedQuery)".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8)?.prefix(300) ?? ""
            print("Overpass HTTP \(http.statusCode) for \(cacheKey): \(body)")
            // Retry once on 429/503
            if http.statusCode == 429 || http.statusCode == 503 {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                let (retryData, _) = try await URLSession.shared.data(for: request)
                return try parseAndCache(data: retryData, cacheKey: cacheKey, gridKey: gridKey)
            }
            throw URLError(.badServerResponse)
        }

        return try parseAndCache(data: data, cacheKey: cacheKey, gridKey: gridKey)
    }

    private func parseAndCache(data: Data, cacheKey: String, gridKey: String) throws -> [OverpassElement] {
        let result = try JSONDecoder().decode(OverpassResponse.self, from: data)
        // Avoid caching empty results so we don't mask transient failures or overly strict filters
        if result.elements.isEmpty {
            print("Overpass returned 0 elements for cacheKey=\(cacheKey) gridKey=\(gridKey). Skipping cache write.")
            cleanOldCaches()
            return result.elements
        }
        if let url = cacheURL(cacheKey: cacheKey, gridKey: gridKey) {
            try? data.write(to: url, options: .atomic)
            print("Cached Overpass response (\(result.elements.count) elements) to \(url.lastPathComponent)")
        }
        cleanOldCaches()
        return result.elements
    }

    /// Delete cached Overpass files older than 72 hours to prevent unbounded growth.
    private func cleanOldCaches() {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let cutoff: TimeInterval = 72 * 60 * 60
        for file in files where file.lastPathComponent.hasPrefix("cached_overpass_") {
            if let attrs = try? fm.attributesOfItem(atPath: file.path),
               let mod = attrs[.modificationDate] as? Date,
               Date().timeIntervalSince(mod) > cutoff {
                try? fm.removeItem(at: file)
            }
        }
    }
}

