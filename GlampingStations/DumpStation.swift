//
//  DumpStations.swift
//  GlampingStations
//
//  Created by Scott Kriss on 8/16/21.
//  Copyright © 2021 Scott Kriss. All rights reserved.
//

import Foundation

class DumpStation: Codable {
    private(set) var id: String?
    private(set) var latitude: Double = 0.0
    private(set) var longitude: Double = 0.0
    private(set) var name: String? = ""
    private(set) var rating: String? = ""
    private(set) var comment: String? = ""
    private(set) var cost: String? = ""
}
