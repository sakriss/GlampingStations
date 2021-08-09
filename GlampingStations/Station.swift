//
//  Station.swift
//  GlampingStations
//
//  Created by Scott Kriss on 7/23/18.
//  Copyright © 2018 Scott Kriss. All rights reserved.
//

import Foundation

class Station: Codable {
    private(set) var id: String?
    private(set) var latitude: Double = 0.0
    private(set) var longitude: Double = 0.0
    private(set) var name: String? = ""
    private(set) var rating: String? = ""
    private(set) var comment: String? = ""
}
