//
//  DumpStationCD+CoreDataProperties.swift
//  GlampingStations
//
//  Created by Scott Kriss on 8/16/21.
//  Copyright © 2021 Scott Kriss. All rights reserved.
//
//

import Foundation
import CoreData


extension DumpStationCD {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DumpStationCD> {
        return NSFetchRequest<DumpStationCD>(entityName: "DumpStationCD")
    }

    @NSManaged public var id: String?
    @NSManaged public var comment: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var name: String?
    @NSManaged public var rating: String?
    @NSManaged public var cost: String?

}
