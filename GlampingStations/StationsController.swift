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
//import FirebaseFirestore  ✅ Firestore import

class StationsController: Codable {
    
    static let shared = StationsController()
    
    static let stationsDataParseComplete = Notification.Name("stationsDataParseComplete")
    static let stationsDataParseFailed = Notification.Name("stationsDataParseFailed")
    
    var stations: [Station]?
    
    var stationArray: [Station] {
        return stations ?? []
    }
    
    func fetchStations() {
        let baseURL = Bundle.main.path(forResource: "stations", ofType: "json")
        
        URLSession.shared.dataTask(with: URL(fileURLWithPath: baseURL!)) { (data: Data?, response: URLResponse?, error: Error?) in
            if let data = data {
                self.stations = (try? JSONDecoder().decode([Station].self, from: data))
                self.saveToCoreData()
                NotificationCenter.default.post(name: StationsController.stationsDataParseComplete, object: nil)
            } else {
                print("ERROR: \(error!)")
                NotificationCenter.default.post(name: StationsController.stationsDataParseFailed, object: nil)
            }
        }.resume()
    }
    
    // ✅ NEW METHOD: Fetch stations from Firestore
//    func fetchStationsFromFirestore() {
//        let db = Firestore.firestore()
//        
//        db.collection("stations").getDocuments { (snapshot, error) in
//            if let error = error {
//                print("Error getting documents: \(error)")
//                NotificationCenter.default.post(name: StationsController.stationsDataParseFailed, object: nil)
//                return
//            }
//            
//            guard let documents = snapshot?.documents else {
//                NotificationCenter.default.post(name: StationsController.stationsDataParseFailed, object: nil)
//                return
//            }
//            
//            var fetchedStations = [Station]()
//            
//            for doc in documents {
//                let data = doc.data()
//                
//                let id = doc.documentID
//                let name = data["name"] as? String ?? "Unnamed"
//                let latitude = data["latitude"] as? CLLocationDegrees ?? 0.0
//                let longitude = data["longitude"] as? CLLocationDegrees ?? 0.0
//                let rating = data["rating"] as? Double // Optional
//                
//                let station = Station(id: id, name: name, latitude: latitude, longitude: longitude, rating: rating, comment: nil)
//                fetchedStations.append(station)
//            }
//            
//            self.stations = fetchedStations
//            self.saveToCoreData()
//            NotificationCenter.default.post(name: StationsController.stationsDataParseComplete, object: nil)
//        }
//    }
    
    func saveToCoreData() {
        for station in stationArray {
            guard let id = station.id else { continue }
            let fetchRequest = NSFetchRequest<StationCD>(entityName: "StationCD")
            fetchRequest.predicate = NSPredicate(format: "id = %@", id)
            
            var results: [StationCD] = []
            
            do {
                results = try AppDelegate.moc.fetch(fetchRequest)
                if results.first != nil {
                    // Already exists
                } else {
                    let stationCD = NSEntityDescription.insertNewObject(forEntityName: "StationCD", into: AppDelegate.moc) as! StationCD
                    stationCD.id = station.id
                    stationCD.latitude = station.latitude ?? 0.0
                    stationCD.longitude = station.longitude ?? 0.0
                    stationCD.name = station.name
                    stationCD.rating = station.rating
                    
                    // New fields from JSON structure
                    stationCD.comment = station.comment
                    stationCD.canopyHeight = station.canopyHeight
                    if let amenity = station.amenity {
                        stationCD.amenityShower = amenity.shower
                        stationCD.amenityBathroom = amenity.bathroom
                        stationCD.amenityTrailerParking = amenity.trailerParking
                        stationCD.amenityDefAtPump = amenity.defAtPump
                        stationCD.amenityRepairShop = amenity.repairShop
                        stationCD.amenityCatScale = amenity.catScale
                    }
                    
                    AppDelegate.saveContext()
                }
            } catch {
                print("error executing fetch request: \(error)")
            }
        }
    }
    
    func updateStationComment(stationId: String, newComment: String) {
        let fetchRequest = NSFetchRequest<StationCD>(entityName: "StationCD")
        fetchRequest.predicate = NSPredicate(format: "id = %@", stationId)
        
        var results: [StationCD] = []
        
        do {
            results = try AppDelegate.moc.fetch(fetchRequest)
            if let stationCD = results.first {
                stationCD.comment = newComment
                AppDelegate.saveContext()
            }
        } catch {
            print("error executing fetch request: \(error)")
        }
    }
    
    func commentForStation(stationId: String) -> String? {
        let fetchRequest = NSFetchRequest<StationCD>(entityName: "StationCD")
        fetchRequest.predicate = NSPredicate(format: "id = %@", stationId)
        
        var results: [StationCD] = []
        
        do {
            results = try AppDelegate.moc.fetch(fetchRequest)
            if let stationCD = results.first {
                return stationCD.comment
            }
        } catch {
            print("error executing fetch request: \(error)")
        }
        return nil
    }
}

