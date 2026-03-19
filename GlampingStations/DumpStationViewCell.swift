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

    private static let cardColor  = UIColor(red: 22/255,  green: 38/255,  blue: 62/255,  alpha: 1)
    private static let accentGold = UIColor(red: 212/255, green: 175/255, blue: 55/255,  alpha: 1)
    private static let mutedText  = UIColor(red: 150/255, green: 165/255, blue: 190/255, alpha: 1)

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = .clear
        contentView.backgroundColor = DumpStationViewCell.cardColor
        contentView.layer.cornerRadius = 14
        contentView.layer.masksToBounds = true
        selectionStyle = .none

        dumpStationName?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        dumpStationName?.textColor = .white
        dumpStationName?.numberOfLines = 1

        dumpStationAddressLbl?.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        dumpStationAddressLbl?.textColor = DumpStationViewCell.mutedText
        dumpStationAddressLbl?.numberOfLines = 1

        dumpStationDistanceLbl?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        dumpStationDistanceLbl?.textColor = DumpStationViewCell.accentGold
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        dumpStationName?.text = nil
        dumpStationAddressLbl?.text = nil
        dumpStationDistanceLbl?.text = nil
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
