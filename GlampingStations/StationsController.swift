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

class StationsController: Codable {
    
    static let shared = StationsController()
    
    static let stationsDataParseComplete = Notification.Name("stationsDataParseComplete")
    
    var stations: [Station]?
    
    var stationArray:[Station] {
        if let theArray = self.stations {
            return theArray
        }
        return []
    }
    
    func fetchStations() {
        
        let baseURL = Bundle.main.path(forResource: "stations", ofType: "json")
        
        URLSession.shared.dataTask(with: URL(fileURLWithPath: baseURL!)) { (data:Data?, response:URLResponse?, error:Error?) in
            if let data = data {
                self.stations = ( try? JSONDecoder().decode([Station].self, from: data))
                self.saveToCoreData()
                NotificationCenter.default.post(name: StationsController.stationsDataParseComplete, object: nil)
            }

            }.resume()
    
    }
    
    func saveToCoreData() {
        
        for station in stationArray {
            guard let id = station.id else { continue }
            let fetchRequest = NSFetchRequest<StationCD>(entityName: "StationCD")
            fetchRequest.predicate = NSPredicate(format: "id = %@", id)
            
            var results: [StationCD] = []
            
            do {
                results = try AppDelegate.moc.fetch(fetchRequest)
                if results.first != nil {
                    //Do nothing for now...
                }
                else {
                    let stationCD = NSEntityDescription.insertNewObject(forEntityName: "StationCD", into: AppDelegate.moc) as! StationCD
                    
                    stationCD.id = station.id
                    stationCD.latitude = station.latitude ?? 0.0
                    stationCD.longitude = station.longitude ?? 0.0
                    stationCD.name = station.name
                    stationCD.rating = station.rating
                    
                    AppDelegate.saveContext()
                }
                
            }
            catch {
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
            }
            catch {
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
            
        }
        catch {
            print("error executing fetch request: \(error)")
        }
        return nil
    }
    
}
