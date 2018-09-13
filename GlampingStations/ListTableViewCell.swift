//
//  ListTableViewCell.swift
//  GlampingStations
//
//  Created by Scott Kriss on 7/23/18.
//  Copyright © 2018 Scott Kriss. All rights reserved.
//

import UIKit

class ListTableViewCell: UITableViewCell {
    @IBOutlet weak var stationNameLabel: UILabel!
    @IBOutlet weak var stationAddressLabel: UILabel!
    @IBOutlet weak var stationDistanceLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
