//
//  DumpStations.swift
//  GlampingStations
//
//  Created by Scott Kriss on 8/16/21.
//  Copyright © 2021 Scott Kriss. All rights reserved.
//

import Foundation

struct DumpAmenities: Codable {
    let potableWater: Bool
    let rinseWater: Bool
    let trailerParking: Bool
    let restrooms: Bool
    let vending: Bool
    let evCharging: Bool
}

class DumpStation: Codable {
    private(set) var id: String?
    private(set) var latitude: Double = 0.0
    private(set) var longitude: Double = 0.0
    private(set) var name: String? = ""
    private(set) var rating: String? = ""
    private(set) var comment: String? = ""
    private(set) var cost: String? = ""
    private(set) var canopyHeight: String? = nil
    private(set) var amenities: DumpAmenities? = nil
    var favorite: Bool = false
    private(set) var state: String? = nil
    private(set) var city: String? = nil
    private(set) var address: String? = nil

    var source: String? = nil  // nil = user-added Firestore; "overpass" = from OpenStreetMap

    private enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, name, rating, comment, cost, canopyHeight, amenities, favorite, state, city, address, source
    }

    // For the shared details view, DumpStation does not provide Station-style amenities
    var amenity: Amenity? { nil }

    init() {}

    init(id: String, latitude: Double, longitude: Double, name: String,
         rating: String, comment: String, cost: String?, canopyHeight: String?,
         amenities: DumpAmenities?, favorite: Bool = false,
         state: String? = nil, city: String? = nil, address: String? = nil,
         source: String? = nil) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.rating = rating
        self.comment = comment
        self.cost = cost
        self.canopyHeight = canopyHeight
        self.amenities = amenities
        self.favorite = favorite
        self.state = state
        self.city = city
        self.address = address
        self.source = source
    }
}

