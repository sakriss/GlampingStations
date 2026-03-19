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

    private static let cardColor   = UIColor(red: 22/255,  green: 38/255,  blue: 62/255,  alpha: 1)
    private static let accentGold  = UIColor(red: 212/255, green: 175/255, blue: 55/255,  alpha: 1)
    private static let mutedText   = UIColor(red: 150/255, green: 165/255, blue: 190/255, alpha: 1)

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = .clear
        contentView.backgroundColor = ListTableViewCell.cardColor
        contentView.layer.cornerRadius = 14
        contentView.layer.masksToBounds = true
        selectionStyle = .none

        stationNameLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        stationNameLabel?.textColor = .white
        stationNameLabel?.numberOfLines = 1

        stationAddressLabel?.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        stationAddressLabel?.textColor = ListTableViewCell.mutedText
        stationAddressLabel?.numberOfLines = 1

        stationDistanceLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        stationDistanceLabel?.textColor = ListTableViewCell.accentGold
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stationNameLabel?.text = nil
        stationAddressLabel?.text = nil
        stationDistanceLabel?.text = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.frame = contentView.frame.inset(by: UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16))
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        UIView.animate(withDuration: 0.15) {
            self.contentView.alpha = selected ? 0.7 : 1.0
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        UIView.animate(withDuration: 0.15) {
            self.contentView.alpha = highlighted ? 0.7 : 1.0
        }
    }
}
