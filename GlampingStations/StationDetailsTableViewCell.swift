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
    
    var stationDetails:Station?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    
    }
    
    

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    @IBAction func getDirectionsButton(_ sender: UIButton) {
        let regionDistance:CLLocationDistance = 10000
        let coordinates = CLLocationCoordinate2DMake((stationDetails?.latitude)!, (stationDetails?.longitude!)!)
        let regionSpan = MKCoordinateRegionMakeWithDistance(coordinates, regionDistance, regionDistance)
        let options = [
            MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: regionSpan.center),
            MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: regionSpan.span)
        ]
        let placemark = MKPlacemark(coordinate: coordinates, addressDictionary: nil)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = stationDetails?.name
        mapItem.openInMaps(launchOptions: options)
    }
    
    @IBAction func saveCommentbutton(_ sender: UIButton) {
        
        if let stationId = stationDetails?.id, let stationComment = stationCommentTextView.text {
            StationsController.shared.updateStationComment(stationId: stationId, newComment: stationComment)
            stationCommentTextView.text = stationComment
            
            // create the alert
            let alert = UIAlertController(title: "Station Comments", message: "Your comment has been saved for this station.", preferredStyle: UIAlertControllerStyle.alert)
            
            // add an action (button)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            
            // show the alert
            UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
            
        }
        else {
            print("nothing to update")
        }
        
    }

}
