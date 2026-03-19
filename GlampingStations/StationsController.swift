//
//  StationsController.swift
//  GlampingStations
//
//  Created by Scott Kriss on 7/23/18.
//  Copyright © 2018 Scott Kriss. All rights reserved.
//

import Foundation
import CoreLocation
import CoreData
import FirebaseFirestore

class StationsController {

    static let shared = StationsController()

    static let stationsDataParseComplete = Notification.Name("stationsDataParseComplete")
    static let stationsDataParseFailed   = Notification.Name("stationsDataParseFailed")
    static let stationAdded              = Notification.Name("stationAdded")

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    var stations: [Station]?

    var stationArray: [Station] { stations ?? [] }

    // MARK: - Live Listener

    /// Attaches a real-time snapshot listener to the "stations" collection.
    /// First call loads from cache instantly, then receives server deltas.
    /// Safe to call multiple times — only the first call creates the listener.
    func fetchStations() {
        // Don't attach a second listener
        guard listener == nil else { return }

        listener = db.collection("stations").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                print("Firestore listener error (stations): \(error)")
                // Only fall back to JSON if we have no data at all yet
                if self.stations == nil {
                    self.fetchFromLocalJSON()
                }
                return
            }

            guard let documents = snapshot?.documents, !documents.isEmpty else {
                if self.stations == nil {
                    self.fetchFromLocalJSON()
                }
                return
            }

            var fetched = [Station]()
            for doc in documents {
                let d = doc.data()
                let a = d["amenity"] as? [String: Bool] ?? [:]
                let amenity = Amenity(
                    shower:         a["shower"]         ?? false,
                    bathroom:       a["bathroom"]       ?? false,
                    trailerParking: a["trailerParking"] ?? false,
                    defAtPump:      a["defAtPump"]      ?? false,
                    repairShop:     a["repairShop"]     ?? false,
                    catScale:       a["catScale"]       ?? false
                )
                let station = Station(
                    id:           doc.documentID,
                    latitude:     d["latitude"]     as? Double ?? 0.0,
                    longitude:    d["longitude"]    as? Double ?? 0.0,
                    name:         d["name"]         as? String ?? "",
                    rating:       d["rating"]       as? String ?? "",
                    comment:      d["comment"]      as? String ?? "",
                    canopyHeight: d["canopyHeight"] as? String,
                    amenity:      amenity,
                    favorite:     d["favorite"]     as? Bool   ?? false,
                    state:        d["state"]        as? String,
                    city:         d["city"]         as? String,
                    address:      d["address"]      as? String
                )
                fetched.append(station)
            }

            self.stations = fetched
            self.saveToCoreData()
            self.writeOfflineCache(fetched)
            NotificationCenter.default.post(name: StationsController.stationsDataParseComplete, object: nil)
        }
    }

    /// Removes the listener. Call if you ever need to stop listening (e.g. sign-out).
    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Offline Cache

    static let offlineCacheFile = "cached_stations.json"

    private var cacheURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(Self.offlineCacheFile)
    }

    private func writeOfflineCache(_ stations: [Station]) {
        guard let url = cacheURL else { return }
        do {
            let data = try JSONEncoder().encode(stations)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to write stations offline cache: \(error)")
        }
    }

    // MARK: - Local JSON Fallback

    private func fetchFromLocalJSON() {
        // 1. Try Documents-directory offline cache written from last Firestore fetch
        if let url = cacheURL,
           let data = try? Data(contentsOf: url),
           let cached = try? JSONDecoder().decode([Station].self, from: data),
           !cached.isEmpty {
            stations = cached
            saveToCoreData()
            NotificationCenter.default.post(name: StationsController.stationsDataParseComplete, object: nil)
            return
        }
        // 2. Fall back to the bundle JSON
        guard let baseURL = Bundle.main.path(forResource: "stations", ofType: "json") else {
            NotificationCenter.default.post(name: StationsController.stationsDataParseFailed, object: nil)
            return
        }
        URLSession.shared.dataTask(with: URL(fileURLWithPath: baseURL)) { data, _, error in
            if let data = data {
                self.stations = try? JSONDecoder().decode([Station].self, from: data)
                self.saveToCoreData()
                NotificationCenter.default.post(name: StationsController.stationsDataParseComplete, object: nil)
            } else {
                print("Local JSON fallback also failed: \(error?.localizedDescription ?? "unknown")")
                NotificationCenter.default.post(name: StationsController.stationsDataParseFailed, object: nil)
            }
        }.resume()
    }

    // MARK: - Add (writes to Firestore — listener auto-updates the list)

    func addUserStation(_ station: Station) {
        let amenityData: [String: Any] = [
            "shower":         station.amenity?.shower         ?? false,
            "bathroom":       station.amenity?.bathroom       ?? false,
            "trailerParking": station.amenity?.trailerParking ?? false,
            "defAtPump":      station.amenity?.defAtPump      ?? false,
            "repairShop":     station.amenity?.repairShop     ?? false,
            "catScale":       station.amenity?.catScale       ?? false
        ]
        let data: [String: Any] = [
            "name":         station.name         ?? "",
            "latitude":     station.latitude,
            "longitude":    station.longitude,
            "rating":       station.rating       ?? "",
            "comment":      station.comment      ?? "",
            "canopyHeight": station.canopyHeight ?? "",
            "amenity":      amenityData,
            "favorite":     station.favorite,
            "state":        station.state        ?? "",
            "city":         station.city         ?? "",
            "address":      station.address      ?? ""
        ]

        let docId = station.id ?? UUID().uuidString
        db.collection("stations").document(docId).setData(data) { error in
            if let error = error {
                print("Error saving station to Firestore: \(error)")
            }
        }

        // The snapshot listener will automatically fire and refresh the list.
        // Post stationAdded for any UI that needs an immediate signal (e.g. dismiss the add sheet).
        NotificationCenter.default.post(name: StationsController.stationAdded, object: nil)
    }

    // MARK: - Toggle Favorite

    func toggleFavorite(stationId: String) {
        guard let station = stations?.first(where: { $0.id == stationId }) else { return }
        station.favorite.toggle()
        db.collection("stations").document(stationId).updateData(["favorite": station.favorite]) { error in
            if let error = error {
                print("Error updating favorite: \(error)")
            }
        }
        NotificationCenter.default.post(name: StationsController.stationsDataParseComplete, object: nil)
    }

    // MARK: - Core Data (local comment persistence)

    func saveToCoreData() {
        for station in stationArray {
            guard let id = station.id else { continue }
            let fetchRequest = NSFetchRequest<StationCD>(entityName: "StationCD")
            fetchRequest.predicate = NSPredicate(format: "id = %@", id)
            do {
                let results = try AppDelegate.moc.fetch(fetchRequest)
                if results.first == nil {
                    let cd = NSEntityDescription.insertNewObject(forEntityName: "StationCD", into: AppDelegate.moc) as! StationCD
                    cd.id        = station.id
                    cd.latitude  = station.latitude
                    cd.longitude = station.longitude
                    cd.name      = station.name
                    cd.rating    = station.rating
                    cd.comment   = station.comment
                    cd.canopyHeight = station.canopyHeight
                    if let amenity = station.amenity {
                        cd.amenityShower         = amenity.shower
                        cd.amenityBathroom       = amenity.bathroom
                        cd.amenityTrailerParking = amenity.trailerParking
                        cd.amenityDefAtPump      = amenity.defAtPump
                        cd.amenityRepairShop     = amenity.repairShop
                        cd.amenityCatScale       = amenity.catScale
                    }
                    AppDelegate.saveContext()
                }
            } catch {
                print("Core Data fetch error: \(error)")
            }
        }
    }

    func updateStationComment(stationId: String, newComment: String) {
        let fetchRequest = NSFetchRequest<StationCD>(entityName: "StationCD")
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
        let fetchRequest = NSFetchRequest<StationCD>(entityName: "StationCD")
        fetchRequest.predicate = NSPredicate(format: "id = %@", stationId)
        do {
            return try AppDelegate.moc.fetch(fetchRequest).first?.comment
        } catch {
            print("Core Data fetch error: \(error)")
            return nil
        }
    }
}
