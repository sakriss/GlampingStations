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

    let favoriteIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "star.fill")
        iv.tintColor = UIColor(red: 212/255, green: 175/255, blue: 55/255, alpha: 1)
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.isHidden = true
        return iv
    }()

    // Badge row for RV-relevant quick-glance info
    private let badgeStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 6
        s.alignment = .center
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

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

        // Favorite star — top-right of content view
        contentView.addSubview(favoriteIcon)
        NSLayoutConstraint.activate([
            favoriteIcon.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            favoriteIcon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            favoriteIcon.widthAnchor.constraint(equalToConstant: 14),
            favoriteIcon.heightAnchor.constraint(equalToConstant: 14)
        ])

        // Badge row — pinned to the bottom of the card; row height is tall enough to avoid overlap
        contentView.addSubview(badgeStack)
        NSLayoutConstraint.activate([
            badgeStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            badgeStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stationNameLabel?.text = nil
        stationAddressLabel?.text = nil
        stationDistanceLabel?.text = nil
        favoriteIcon.isHidden = true
        badgeStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }

    /// Populate the badge row with RV-relevant quick-glance chips.
    func configureBadges(diesel: Bool, isTruckStop: Bool, canopyHeight: String?) {
        badgeStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if isTruckStop  { badgeStack.addArrangedSubview(makeBadge("🚛 Truck Stop", color: UIColor(red: 50/255, green: 80/255, blue: 130/255, alpha: 1))) }
        if diesel       { badgeStack.addArrangedSubview(makeBadge("⛽ Diesel",     color: UIColor(red: 60/255, green: 110/255, blue: 60/255,  alpha: 1))) }
        if let h = canopyHeight, !h.isEmpty {
            badgeStack.addArrangedSubview(makeBadge("↕ \(h)", color: UIColor(red: 90/255, green: 60/255, blue: 120/255, alpha: 1)))
        }
    }

    private func makeBadge(_ text: String, color: UIColor) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = UIFont.systemFont(ofSize: 10, weight: .semibold)
        l.textColor = .white
        l.backgroundColor = color
        l.layer.cornerRadius = 6
        l.clipsToBounds = true
        l.textAlignment = .center
        l.setContentHuggingPriority(.required, for: .horizontal)
        // Padding via edge insets via a container would be complex; use character padding
        l.text = "  \(text)  "
        return l
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
