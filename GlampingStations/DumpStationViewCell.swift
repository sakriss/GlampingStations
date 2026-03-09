//
//  DumpStationViewCell.swift
//  GlampingStations
//
//  Created by Scott Kriss on 8/18/21.
//  Copyright © 2021 Scott Kriss. All rights reserved.
//

import UIKit

class DumpStationViewCell: UITableViewCell {
    
    @IBOutlet weak var dumpStationName: UILabel!
    @IBOutlet weak var dumpStationAddressLbl: UILabel!
    
    @IBOutlet weak var dumpStationDistanceLbl: UILabel!
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
