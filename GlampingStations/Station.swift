//
//  Station.swift
//  GlampingStations
//
//  Created by Scott Kriss on 7/23/18.
//  Copyright © 2018 Scott Kriss. All rights reserved.
//

import Foundation

struct Amenity: Codable {
    let shower: Bool
    let bathroom: Bool
    let trailerParking: Bool
    let defAtPump: Bool
    let repairShop: Bool
    let catScale: Bool
    // RV-specific
    var diesel: Bool = false        // fuel:diesel=yes or fuel:HGV_diesel=yes
    var hgvAccess: Bool = false     // hgv=yes or hgv=designated (confirmed large-vehicle access)
}

class Station: Codable {
    private(set) var id: String?
    private(set) var latitude: Double = 0.0
    private(set) var longitude: Double = 0.0
    private(set) var name: String? = ""
    private(set) var rating: String? = ""
    private(set) var comment: String? = ""
    private(set) var canopyHeight: String? = nil
    private(set) var amenity: Amenity? = nil
    var favorite: Bool = false
    private(set) var state: String? = nil
    private(set) var city: String? = nil
    private(set) var address: String? = nil
    var source: String? = nil       // nil = user-added Firestore; "overpass" = from OpenStreetMap
    var isTruckStop: Bool = false   // true when brand matches known truck-stop chains

    init() {}

    init(id: String, latitude: Double, longitude: Double, name: String,
         rating: String, comment: String, canopyHeight: String?, amenity: Amenity?,
         favorite: Bool = false, state: String? = nil, city: String? = nil, address: String? = nil,
         source: String? = nil) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.rating = rating
        self.comment = comment
        self.canopyHeight = canopyHeight
        self.amenity = amenity
        self.favorite = favorite
        self.state = state
        self.city = city
        self.address = address
        self.source = source
    }
}
