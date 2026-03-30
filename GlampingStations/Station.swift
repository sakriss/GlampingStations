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
    var trailerParking: Bool = true
    let defAtPump: Bool
    let repairShop: Bool
    let catScale: Bool
    // RV-specific
    var diesel: Bool = false        // fuel:diesel=yes or fuel:HGV_diesel=yes
    var hgvAccess: Bool = false     // hgv=yes or hgv=designated (confirmed large-vehicle access)

    // Explicit memberwise init (required because the custom Decodable init below
    // suppresses the synthesized one).
    init(shower: Bool, bathroom: Bool, trailerParking: Bool,
         defAtPump: Bool, repairShop: Bool, catScale: Bool) {
        self.shower = shower
        self.bathroom = bathroom
        self.trailerParking = trailerParking
        self.defAtPump = defAtPump
        self.repairShop = repairShop
        self.catScale = catScale
    }

    // Custom decoder so that JSON written before `diesel`/`hgvAccess` were added
    // (bundle fallback, old offline caches) still decodes successfully.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        shower         = try c.decode(Bool.self, forKey: .shower)
        bathroom       = try c.decode(Bool.self, forKey: .bathroom)
        trailerParking = try c.decode(Bool.self, forKey: .trailerParking)
        defAtPump      = try c.decode(Bool.self, forKey: .defAtPump)
        repairShop     = try c.decode(Bool.self, forKey: .repairShop)
        catScale       = try c.decode(Bool.self, forKey: .catScale)
        diesel         = try c.decodeIfPresent(Bool.self, forKey: .diesel)    ?? false
        hgvAccess      = try c.decodeIfPresent(Bool.self, forKey: .hgvAccess) ?? false
    }
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

    // Custom decoder so that JSON written before `isTruckStop` was added
    // (bundle fallback, old offline caches) still decodes successfully.
    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decodeIfPresent(String.self,  forKey: .id)
        latitude     = try c.decode(Double.self,            forKey: .latitude)
        longitude    = try c.decode(Double.self,            forKey: .longitude)
        name         = try c.decodeIfPresent(String.self,  forKey: .name)
        rating       = try c.decodeIfPresent(String.self,  forKey: .rating)
        comment      = try c.decodeIfPresent(String.self,  forKey: .comment)
        canopyHeight = try c.decodeIfPresent(String.self,  forKey: .canopyHeight)
        amenity      = try c.decodeIfPresent(Amenity.self, forKey: .amenity)
        favorite     = try c.decode(Bool.self,              forKey: .favorite)
        state        = try c.decodeIfPresent(String.self,  forKey: .state)
        city         = try c.decodeIfPresent(String.self,  forKey: .city)
        address      = try c.decodeIfPresent(String.self,  forKey: .address)
        source       = try c.decodeIfPresent(String.self,  forKey: .source)
        isTruckStop  = try c.decodeIfPresent(Bool.self,    forKey: .isTruckStop) ?? false
    }
}
