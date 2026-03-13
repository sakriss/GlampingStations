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

    private enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, name, rating, comment, cost, canopyHeight, amenities
    }

    // For the shared details view, DumpStation does not provide Station-style amenities
    var amenity: Amenity? { nil }
}

