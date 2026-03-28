//
//  OverpassParser.swift
//  GlampingStations
//

import Foundation

enum OverpassParser {

    // Known truck-stop / RV-friendly chain brands (lowercased for comparison)
    private static let truckStopBrands: [String] = [
        "pilot", "flying j", "love", "ta travel", "petro", "buc-ee", "sheetz", "kwik trip"
    ]

    // Full-service truck stops that have showers, bathrooms, and DEF at the pump
    private static let fullServiceBrands: [String] = [
        "pilot", "flying j", "love", "ta travel", "petro"
    ]

    private static func detectTruckStop(tags: [String: String]) -> Bool {
        let brand = (tags["brand"] ?? tags["operator"] ?? tags["name"] ?? "").lowercased()
        return truckStopBrands.contains(where: { brand.contains($0) })
    }

    private static func detectFullServiceTruckStop(tags: [String: String]) -> Bool {
        let brand = (tags["brand"] ?? tags["operator"] ?? tags["name"] ?? "").lowercased()
        return fullServiceBrands.contains(where: { brand.contains($0) })
    }

    /// Public helper so controllers can apply the same brand inference to Firestore stations.
    static func isTruckStopName(_ name: String) -> Bool {
        let lower = name.lowercased()
        return truckStopBrands.contains(where: { lower.contains($0) })
    }

    // MARK: - Gas Station

    static func toStation(_ element: OverpassElement) -> Station? {
        guard let lat = element.effectiveLat, let lon = element.effectiveLon else { return nil }
        let tags = element.tags ?? [:]

        // Detect truck-stop brand first — used to infer amenities even when OSM tags are incomplete
        let isTruckStop    = detectTruckStop(tags: tags)
        let isFullService  = detectFullServiceTruckStop(tags: tags)

        // Full-service truck stops (Pilot, Flying J, Love's, TA, Petro) have showers,
        // bathrooms, and DEF at every location. All truck stops have bathrooms and DEF.
        var amenity = Amenity(
            shower:         tags["shower"] == "yes"              || isFullService,
            bathroom:       tags["toilets"] == "yes"             || isTruckStop,
            trailerParking: tags["hgv"] == "yes" || tags["truck"] == "yes" || isTruckStop,
            defAtPump:      tags["fuel:adblue"] == "yes"         || isTruckStop,
            repairShop:     tags["service:vehicle:car_repair"] == "yes" || isFullService,
            catScale:       false   // no OSM tag — user-added only
        )
        amenity.diesel    = tags["fuel:diesel"] == "yes" || tags["fuel:HGV_diesel"] == "yes" || isTruckStop
        amenity.hgvAccess = tags["hgv"] == "yes" || tags["hgv"] == "designated" || isTruckStop

        let station = Station(
            id:           "osm_\(element.id)",
            latitude:     lat,
            longitude:    lon,
            name:         stationName(from: tags, fallback: "Gas Station"),
            rating:       "",
            comment:      tags["description"] ?? "",
            canopyHeight: tags["canopy:height"] ?? tags["height"],
            amenity:      amenity,
            favorite:     false,
            state:        tags["addr:state"],
            city:         tags["addr:city"],
            address:      fullAddress(from: tags),
            source:       "overpass"
        )
        station.isTruckStop = isTruckStop
        return station
    }

    // MARK: - Dump Station

    static func toDumpStation(_ element: OverpassElement) -> DumpStation? {
        guard let lat = element.effectiveLat, let lon = element.effectiveLon else { return nil }
        let tags = element.tags ?? [:]

        let amenities = DumpAmenities(
            potableWater:   tags["drinking_water"] == "yes",
            rinseWater:     false,
            trailerParking: tags["hgv"] == "yes",
            restrooms:      tags["toilets"] == "yes",
            vending:        tags["vending"] != nil,
            evCharging:     tags["charging_station"] == "yes"
        )

        let station = DumpStation(
            id:           "osm_\(element.id)",
            latitude:     lat,
            longitude:    lon,
            name:         stationName(from: tags, fallback: "Dump Station"),
            rating:       "",
            comment:      tags["description"] ?? "",
            cost:         tags["fee"] == "yes" ? "Fee required" : (tags["fee"] == "no" ? "Free" : nil),
            canopyHeight: nil,
            amenities:    amenities,
            favorite:     false,
            state:        tags["addr:state"],
            city:         tags["addr:city"],
            address:      fullAddress(from: tags),
            source:       "overpass"
        )
        return station
    }

    // MARK: - Helpers

    private static func stationName(from tags: [String: String], fallback: String) -> String {
        tags["name"] ?? tags["brand"] ?? tags["operator"] ?? fallback
    }

    private static func fullAddress(from tags: [String: String]) -> String? {
        // Build each segment independently so missing parts don't leave dangling commas
        var segments: [String] = []

        let number = tags["addr:housenumber"] ?? ""
        let street = tags["addr:street"] ?? ""
        let streetLine = [number, street].filter { !$0.isEmpty }.joined(separator: " ")
        if !streetLine.isEmpty { segments.append(streetLine) }

        if let city  = tags["addr:city"],  !city.isEmpty  { segments.append(city) }
        if let state = tags["addr:state"], !state.isEmpty { segments.append(state) }

        let result = segments.joined(separator: ", ")
        return result.isEmpty ? nil : result
    }
}
