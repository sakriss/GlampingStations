//
//  DumpStationsController.swift
//  GlampingStations
//
//  Created by Scott Kriss on 8/16/21.
//  Copyright © 2021 Scott Kriss. All rights reserved.
//

import Foundation

//
//  DumpStationsController.swift
//  GlampingStations
//
//  Created by Scott Kriss on 7/23/18.
//  Copyright © 2018 Scott Kriss. All rights reserved.
//

import Foundation
import CoreLocation
import CoreData

class DumpStationsController: Codable {
    
    static let shared = DumpStationsController()
    
    static let dumpStationsDataParseComplete = Notification.Name("stationsDataParseComplete")
    static let dumpStationsDataParseFailed = Notification.Name("stationsDataParseFailed")
    
    var dumpStation: [DumpStation]?
    
    var stationArray:[DumpStation] {
        if let theArray = self.dumpStation {
            return theArray
        }
        return []
    }
    
    func fetchStations() {
        
        let baseURL = Bundle.main.path(forResource: "dumpstations", ofType: "json")
        
        URLSession.shared.dataTask(with: URL(fileURLWithPath: baseURL!)) { (data:Data?, response:URLResponse?, error:Error?) in
            if let data = data {
                self.dumpStation = ( try? JSONDecoder().decode([DumpStation].self, from: data))
                self.saveToCoreData()
                NotificationCenter.default.post(name: StationsController.stationsDataParseComplete, object: nil)
            } else {
                print("ERROR: \(error!)")
                NotificationCenter.default.post(name: StationsController.stationsDataParseFailed, object: nil)
            }
            
        }.resume()
    }
    
    func saveToCoreData() {
        
        for station in stationArray {
            guard let id = station.id else { continue }
            let fetchRequest = NSFetchRequest<DumpStationCD>(entityName: "DumpStationCD")
            fetchRequest.predicate = NSPredicate(format: "id = %@", id)
            
            var results: [DumpStationCD] = []
            
            do {
                results = try AppDelegate.moc.fetch(fetchRequest)
                if results.first != nil {
                    //Do nothing for now...
                }
                else {
                    let stationCD = NSEntityDescription.insertNewObject(forEntityName: "DumpStationCD", into: AppDelegate.moc) as! DumpStationCD
                    
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
        
        let fetchRequest = NSFetchRequest<DumpStationCD>(entityName: "DumpStationCD")
        fetchRequest.predicate = NSPredicate(format: "id = %@", stationId)
        
        var results: [DumpStationCD] = []
        
        do {
            results = try AppDelegate.moc.fetch(fetchRequest)
            if let dumpStationCD = results.first {
                dumpStationCD.comment = newComment
                AppDelegate.saveContext()
            }
        }
        catch {
            print("error executing fetch request: \(error)")
        }
    }
    
    func commentForStation(stationId: String) -> String? {
        
        let fetchRequest = NSFetchRequest<DumpStationCD>(entityName: "DumpStationCD")
        fetchRequest.predicate = NSPredicate(format: "id = %@", stationId)
        
        var results: [DumpStationCD] = []
        
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
