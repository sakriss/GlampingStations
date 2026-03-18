//
//  StationDetailsTableViewCell.swift
//  GlampingStations
//
//  Created by Scott Kriss on 7/26/18.
//  Copyright © 2018 Scott Kriss. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit

class StationDetailsTableViewCell: UITableViewCell {
    @IBOutlet weak var stationNameLabel: UILabel!
    @IBOutlet weak var stationsAddressLabel: UILabel!
    @IBOutlet weak var stationsDistanceLabel: UILabel!
    @IBOutlet weak var stationCommentLabel: UILabel!
    @IBOutlet weak var stationCommentTextField: UITextField!
    @IBOutlet weak var stationCommentTextView: UITextView!
    @IBOutlet weak var weatherLabel: UILabel!
    @IBOutlet weak var amenitiesContainerView: UIView!

    private var placeholderLabel: UILabel?

    var stationDetails: Station = Station()
    
    private static let primaryBg  = UIColor(red: 10/255,  green: 25/255,  blue: 47/255,  alpha: 1)
    private static let cardColor  = UIColor(red: 22/255,  green: 38/255,  blue: 62/255,  alpha: 1)
    private static let accentGold = UIColor(red: 212/255, green: 175/255, blue: 55/255,  alpha: 1)
    private static let mutedText  = UIColor(red: 150/255, green: 165/255, blue: 190/255, alpha: 1)

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = StationDetailsTableViewCell.primaryBg
        contentView.backgroundColor = StationDetailsTableViewCell.primaryBg
        selectionStyle = .none

        stationNameLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        stationNameLabel?.textColor = .white
        stationNameLabel?.numberOfLines = 2

        stationsAddressLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        stationsAddressLabel?.textColor = StationDetailsTableViewCell.mutedText
        stationsAddressLabel?.numberOfLines = 2

        stationsDistanceLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        stationsDistanceLabel?.textColor = StationDetailsTableViewCell.accentGold

        weatherLabel?.text = nil
        weatherLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        weatherLabel?.textColor = StationDetailsTableViewCell.mutedText
        weatherLabel?.textAlignment = .right
        weatherLabel?.numberOfLines = 2
        weatherLabel?.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        weatherLabel?.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Fix name/weather overlap: weather label uses fixedFrame with no real constraints.
        // Pin it to the trailing edge and cap the name label's trailing before it.
        if let nameLabel = stationNameLabel, let weather = weatherLabel {
            weather.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                weather.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
                weather.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
                weather.widthAnchor.constraint(lessThanOrEqualToConstant: 150),
                nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: weather.leadingAnchor, constant: -8)
            ])
        }

        stationCommentLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        stationCommentLabel?.textColor = .white

        stationCommentTextView?.backgroundColor = StationDetailsTableViewCell.cardColor
        stationCommentTextView?.textColor = StationDetailsTableViewCell.mutedText
        stationCommentTextView?.layer.cornerRadius = 10
        stationCommentTextView?.layer.borderWidth = 0
        stationCommentTextView?.font = UIFont.systemFont(ofSize: 14)
        stationCommentTextView?.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        stationCommentTextView?.delegate = self

        // Add placeholder label
        if let tv = stationCommentTextView {
            let ph = UILabel()
            ph.text = "Add a note about this station..."
            ph.font = UIFont.systemFont(ofSize: 14)
            ph.textColor = StationDetailsTableViewCell.mutedText.withAlphaComponent(0.5)
            ph.translatesAutoresizingMaskIntoConstraints = false
            tv.addSubview(ph)
            NSLayoutConstraint.activate([
                ph.topAnchor.constraint(equalTo: tv.topAnchor, constant: 10),
                ph.leadingAnchor.constraint(equalTo: tv.leadingAnchor, constant: 12)
            ])
            placeholderLabel = ph
        }
    }

    func updatePlaceholder() {
        let isEmpty = stationCommentTextView?.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
        placeholderLabel?.isHidden = !isEmpty
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        weatherLabel?.text = nil
        amenitiesContainerView?.subviews.forEach { $0.removeFromSuperview() }
    }
    
    enum NavigationApps: String {
        case appleMaps = "Apple Maps"
        case googleMaps = "Google Maps"
        case wazeMaps = "Waze"
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
    @IBAction func getDirectionsButton(_ sender: UIButton) {
        
        let installedNavigationApps : [[String:String]] = [[NavigationApps.appleMaps.rawValue:""], [NavigationApps.googleMaps.rawValue:"comgooglemaps://"], [NavigationApps.wazeMaps.rawValue:"waze://"]]
        
        var alertAction: UIAlertAction?
        
        let alert = UIAlertController(title: "Select Navigation App", message: "Open in", preferredStyle: .actionSheet)
        
        for app in installedNavigationApps {
            let appName = app.keys.first
            if (appName == NavigationApps.appleMaps.rawValue ||
                    appName == NavigationApps.googleMaps.rawValue || appName == NavigationApps.wazeMaps.rawValue || UIApplication.shared.canOpenURL(URL(string:app[appName!]!)!))
            {
                
                alertAction = UIAlertAction(title: appName, style: .default, handler: { (action) in
                    switch appName {
                    case NavigationApps.appleMaps.rawValue?:
                        let regionDistance:CLLocationDistance = 10000
                        let coordinates = CLLocationCoordinate2DMake((self.stationDetails.latitude), (self.stationDetails.longitude))
                        let regionSpan = MKCoordinateRegion(center: coordinates, latitudinalMeters: regionDistance, longitudinalMeters: regionDistance)
                        let options = [
                            MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: regionSpan.center),
                            MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: regionSpan.span)
                        ]
                        let placemark = MKPlacemark(coordinate: coordinates, addressDictionary: nil)
                        let mapItem = MKMapItem(placemark: placemark)
                        mapItem.name = self.stationDetails.name
                        mapItem.openInMaps(launchOptions: options)
                        break
                        
                    case NavigationApps.googleMaps.rawValue?:
                        if UIApplication.shared.canOpenURL(URL(string:app[appName!]!)!) {
                            //open in Google Maps application
                            UIApplication.shared.open(URL(string:
                                                            "comgooglemaps://?saddr=&daddr=\(self.stationDetails.latitude),\(self.stationDetails.longitude)&directionsmode=driving")! as URL, options: [:], completionHandler: nil)
                        } else {
                            //open in Browser
                            let string = "https://maps.google.com/?q=@\(self.stationDetails.latitude),\(self.stationDetails.longitude)"
                            UIApplication.shared.open(URL(string: string)!)
                        }
                        break
                        
                    case NavigationApps.wazeMaps.rawValue?:
                        UIApplication.shared.open(URL(string:
                                                        "waze://?ll=\(self.stationDetails.latitude),\(self.stationDetails.longitude)")! as URL, options: [:], completionHandler: nil)
                        break
                        
                    default:
                        break
                    }
                })
                alert.addAction(alertAction!)
            }
            else
            {
                print("Can't open URL scheme")
            }
        }
        
        alertAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alert.addAction(alertAction!)
        
        UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
        
        // OLD WAY OF OPENING MAPS FOR DIRECTIONS
        //        let regionDistance:CLLocationDistance = 10000
        //        let coordinates = CLLocationCoordinate2DMake((stationDetails?.latitude)!, (stationDetails?.longitude!)!)
        //        let regionSpan = MKCoordinateRegion.init(center: coordinates, latitudinalMeters: regionDistance, longitudinalMeters: regionDistance)
        //        let options = [
        //            MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: regionSpan.center),
        //            MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: regionSpan.span)
        //        ]
        //        let placemark = MKPlacemark(coordinate: coordinates, addressDictionary: nil)
        //        let mapItem = MKMapItem(placemark: placemark)
        //        mapItem.name = stationDetails?.name
        //        mapItem.openInMaps(launchOptions: options)
    }
    
    @IBAction func saveCommentbutton(_ sender: UIButton) {

        if let stationId = stationDetails.id, let stationComment = stationCommentTextView.text {
            StationsController.shared.updateStationComment(stationId: stationId, newComment: stationComment)
            stationCommentTextView.text = stationComment

            let alert = UIAlertController(title: "Station Comments", message: "Your comment has been saved for this station.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
        } else {
            print("nothing to update")
        }
    }
}

extension StationDetailsTableViewCell: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updatePlaceholder()
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        updatePlaceholder()
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        updatePlaceholder()
    }
}
