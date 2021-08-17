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
    
    var stationDetails:Station = Station()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
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
            
            // create the alert
            let alert = UIAlertController(title: "Station Comments", message: "Your comment has been saved for this station.", preferredStyle: UIAlertController.Style.alert)
            
            // add an action (button)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
            
            // show the alert
            UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
            
        }
        else {
            print("nothing to update")
        }
        
    }
    
}
