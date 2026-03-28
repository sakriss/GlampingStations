//
//  DumpStationsController.swift
//  GlampingStations
//
//  Created by Scott Kriss on 8/16/21.
//  Copyright © 2021 Scott Kriss. All rights reserved.
//

import Foundation
import CoreLocation
import CoreData
import FirebaseFirestore

class DumpStationsController {

    static let shared = DumpStationsController()

    static let dumpStationsDataParseComplete = Notification.Name("dumpStationsDataParseComplete")
    static let dumpStationsDataParseFailed   = Notification.Name("dumpStationsDataParseFailed")
    static let dumpStationAdded              = Notification.Name("dumpStationAdded")

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    // Merged output — what the UI reads
    var dumpStation: [DumpStation]?
    var dumpStationArray: [DumpStation] { dumpStation ?? [] }

    // Dual-source private arrays
    private var firestoreStations: [DumpStation] = []
    private var overpassStations: [DumpStation] = []
    private var lastOverpassLocation: CLLocation?
    private let overpassMinMove: CLLocationDistance = 5_000  // 5 km

    // MARK: - Live Listener

    /// Attaches a real-time snapshot listener to the "dumpStations" collection.
    /// Safe to call multiple times — only the first call creates the listener.
    func fetchStations() {
        guard listener == nil else { return }

        listener = db.collection("dumpStations").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                print("Firestore listener error (dumpStations): \(error)")
                if self.dumpStation == nil {
                    self.fetchFromLocalJSON()
                }
                return
            }

            guard let documents = snapshot?.documents, !documents.isEmpty else {
                if self.dumpStation == nil {
                    self.fetchFromLocalJSON()
                }
                return
            }

            var fetched = [DumpStation]()
            for doc in documents {
                let d = doc.data()
                let a = d["amenities"] as? [String: Bool] ?? [:]
                let amenities = DumpAmenities(
                    potableWater:   a["potableWater"]   ?? false,
                    rinseWater:     a["rinseWater"]     ?? false,
                    trailerParking: a["trailerParking"] ?? false,
                    restrooms:      a["restrooms"]      ?? false,
                    vending:        a["vending"]        ?? false,
                    evCharging:     a["evCharging"]     ?? false
                )
                let station = DumpStation(
                    id:           doc.documentID,
                    latitude:     d["latitude"]     as? Double ?? 0.0,
                    longitude:    d["longitude"]    as? Double ?? 0.0,
                    name:         d["name"]         as? String ?? "",
                    rating:       d["rating"]       as? String ?? "",
                    comment:      d["comment"]      as? String ?? "",
                    cost:         d["cost"]         as? String,
                    canopyHeight: d["canopyHeight"] as? String,
                    amenities:    amenities,
                    favorite:     d["favorite"]     as? Bool   ?? false,
                    state:        d["state"]        as? String,
                    city:         d["city"]         as? String,
                    address:      d["address"]      as? String,
                    source:       d["source"]       as? String
                )
                fetched.append(station)
            }

            self.firestoreStations = fetched
            self.mergeAndPublish()
        }
    }

    /// Removes the listener.
    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Overpass Integration

    func fetchOverpassStations(near location: CLLocation, forceRefresh: Bool = false) {
        if !forceRefresh, let last = lastOverpassLocation,
           location.distance(from: last) < overpassMinMove { return }
        lastOverpassLocation = location

        Task {
            do {
                let elements = try await OverpassService.shared.fetchDumpStations(near: location)
                let parsed = elements.compactMap { OverpassParser.toDumpStation($0) }
                print("Overpass dump: \(elements.count) elements → \(parsed.count) stations")
                await MainActor.run {
                    self.overpassStations = parsed
                    self.mergeAndPublish()
                }
            } catch {
                print("Overpass dump fetch error: \(error)")
            }
        }
    }

    // MARK: - Merge

    private func mergeAndPublish() {
        var merged = firestoreStations
        for op in overpassStations {
            let opLoc = CLLocation(latitude: op.latitude, longitude: op.longitude)
            let isDupe = merged.contains {
                CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: opLoc) < 100
            }
            if !isDupe { merged.append(op) }
        }
        dumpStation = merged
        writeOfflineCache(merged)
        NotificationCenter.default.post(name: DumpStationsController.dumpStationsDataParseComplete, object: nil)
    }

    // MARK: - Offline Cache

    static let offlineCacheFile = "cached_dumpstations.json"

    private var cacheURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(Self.offlineCacheFile)
    }

    private func writeOfflineCache(_ stations: [DumpStation]) {
        guard let url = cacheURL else { return }
        do {
            let data = try JSONEncoder().encode(stations)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to write dump stations offline cache: \(error)")
        }
    }

    // MARK: - Local JSON Fallback

    private func fetchFromLocalJSON() {
        // 1. Try Documents-directory offline cache written from last Firestore fetch
        if let url = cacheURL,
           let data = try? Data(contentsOf: url),
           let cached = try? JSONDecoder().decode([DumpStation].self, from: data),
           !cached.isEmpty {
            dumpStation = cached
            NotificationCenter.default.post(name: DumpStationsController.dumpStationsDataParseComplete, object: nil)
            return
        }
        // 2. Fall back to the bundle JSON
        guard let baseURL = Bundle.main.path(forResource: "dumpstations", ofType: "json") else {
            NotificationCenter.default.post(name: DumpStationsController.dumpStationsDataParseFailed, object: nil)
            return
        }
        URLSession.shared.dataTask(with: URL(fileURLWithPath: baseURL)) { data, _, error in
            if let data = data {
                self.dumpStation = try? JSONDecoder().decode([DumpStation].self, from: data)
                NotificationCenter.default.post(name: DumpStationsController.dumpStationsDataParseComplete, object: nil)
            } else {
                print("Local JSON fallback also failed: \(error?.localizedDescription ?? "unknown")")
                NotificationCenter.default.post(name: DumpStationsController.dumpStationsDataParseFailed, object: nil)
            }
        }.resume()
    }

    // MARK: - Add (writes to Firestore — listener auto-updates the list)

    func addUserDumpStation(_ station: DumpStation) {
        let amenitiesData: [String: Any] = [
            "potableWater":   station.amenities?.potableWater   ?? false,
            "rinseWater":     station.amenities?.rinseWater     ?? false,
            "trailerParking": station.amenities?.trailerParking ?? false,
            "restrooms":      station.amenities?.restrooms      ?? false,
            "vending":        station.amenities?.vending        ?? false,
            "evCharging":     station.amenities?.evCharging     ?? false
        ]
        let data: [String: Any] = [
            "name":         station.name         ?? "",
            "latitude":     station.latitude,
            "longitude":    station.longitude,
            "rating":       station.rating       ?? "",
            "comment":      station.comment      ?? "",
            "cost":         station.cost         ?? "",
            "canopyHeight": station.canopyHeight ?? "",
            "amenities":    amenitiesData,
            "favorite":     station.favorite,
            "state":        station.state        ?? "",
            "city":         station.city         ?? "",
            "address":      station.address      ?? ""
        ]

        let docId = station.id ?? UUID().uuidString
        db.collection("dumpStations").document(docId).setData(data) { error in
            if let error = error {
                print("Error saving dump station to Firestore: \(error)")
            }
        }

        NotificationCenter.default.post(name: DumpStationsController.dumpStationAdded, object: nil)
    }

    // MARK: - Toggle Favorite

    func toggleFavorite(stationId: String) {
        guard let station = dumpStation?.first(where: { $0.id == stationId }) else { return }
        station.favorite.toggle()

        if station.source == "overpass" && station.favorite {
            // First time favoriting an Overpass station — persist it to Firestore
            saveOverpassStationToFirestore(station)
        } else {
            db.collection("dumpStations").document(stationId).updateData(["favorite": station.favorite]) { error in
                if let error = error {
                    print("Error updating favorite: \(error)")
                }
            }
        }
        NotificationCenter.default.post(name: DumpStationsController.dumpStationsDataParseComplete, object: nil)
    }

    private func saveOverpassStationToFirestore(_ station: DumpStation) {
        guard let docId = station.id else { return }
        let amenitiesData: [String: Any] = [
            "potableWater":   station.amenities?.potableWater   ?? false,
            "rinseWater":     station.amenities?.rinseWater     ?? false,
            "trailerParking": station.amenities?.trailerParking ?? false,
            "restrooms":      station.amenities?.restrooms      ?? false,
            "vending":        station.amenities?.vending        ?? false,
            "evCharging":     station.amenities?.evCharging     ?? false
        ]
        let data: [String: Any] = [
            "name":         station.name         ?? "",
            "latitude":     station.latitude,
            "longitude":    station.longitude,
            "rating":       station.rating       ?? "",
            "comment":      station.comment      ?? "",
            "cost":         station.cost         ?? "",
            "canopyHeight": station.canopyHeight ?? "",
            "amenities":    amenitiesData,
            "favorite":     true,
            "state":        station.state        ?? "",
            "city":         station.city         ?? "",
            "address":      station.address      ?? "",
            "source":       "overpass"
        ]
        db.collection("dumpStations").document(docId).setData(data) { error in
            if let error = error {
                print("Error saving Overpass dump station to Firestore: \(error)")
            }
        }
    }

    // MARK: - Core Data (local comment persistence)
    // Only called with Firestore stations to avoid bloating Core Data with Overpass results.

    func saveToCoreData(_ stationsToSave: [DumpStation]) {
        for station in stationsToSave {
            guard let id = station.id else { continue }
            let fetchRequest = NSFetchRequest<DumpStationCD>(entityName: "DumpStationCD")
            fetchRequest.predicate = NSPredicate(format: "id = %@", id)
            do {
                let results = try AppDelegate.moc.fetch(fetchRequest)
                if results.first == nil {
                    let cd = NSEntityDescription.insertNewObject(forEntityName: "DumpStationCD", into: AppDelegate.moc) as! DumpStationCD
                    cd.id        = station.id
                    cd.latitude  = station.latitude
                    cd.longitude = station.longitude
                    cd.name      = station.name
                    cd.rating    = station.rating
                    AppDelegate.saveContext()
                }
            } catch {
                print("Core Data fetch error: \(error)")
            }
        }
    }

    // Keep old no-argument signature for any call sites that use it
    func saveToCoreData() { saveToCoreData(firestoreStations) }

    func updateStationComment(stationId: String, newComment: String) {
        let fetchRequest = NSFetchRequest<DumpStationCD>(entityName: "DumpStationCD")
        fetchRequest.predicate = NSPredicate(format: "id = %@", stationId)
        do {
            if let cd = try AppDelegate.moc.fetch(fetchRequest).first {
                cd.comment = newComment
                AppDelegate.saveContext()
            }
        } catch {
            print("Core Data update error: \(error)")
        }
    }

    func commentForStation(stationId: String) -> String? {
        let fetchRequest = NSFetchRequest<DumpStationCD>(entityName: "DumpStationCD")
        fetchRequest.predicate = NSPredicate(format: "id = %@", stationId)
        do {
            return try AppDelegate.moc.fetch(fetchRequest).first?.comment
        } catch {
            print("Core Data fetch error: \(error)")
            return nil
        }
    }
}
