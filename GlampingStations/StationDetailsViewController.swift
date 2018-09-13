//
//  StationDetailsViewController.swift
//  GlampingStations
//
//  Created by Scott Kriss on 7/24/18.
//  Copyright © 2018 Scott Kriss. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit

class StationDetailsViewController: UIViewController {
    
    @IBOutlet weak var stationDetailMapView: MKMapView!
    @IBOutlet weak var stationsDetailsTableView: UITableView!
    
    var userLocation = CLLocation()
    var stationDetails:Station?
    
    var text = NSMutableAttributedString(string: "")
//    var stationName:String = ""
//    var stationAddress = ""
//    var stationDistance = ""
    var stepByStepDirections:String = ""
    var stationCoords = [CLLocationCoordinate2D()]
    
    override func viewDidLoad() {
        super.viewDidLoad()
  
        stationsDetailsTableView.tableFooterView = UIView()
        
        placeAnnotation()
        
        self.stationsDetailsTableView.rowHeight = UITableViewAutomaticDimension
        self.stationsDetailsTableView.estimatedRowHeight = 800
        self.stationsDetailsTableView.isScrollEnabled = true
        
    }
    
    func placeAnnotation() {
        //TODO: Pass these in
        let center = CLLocationCoordinate2D(latitude: (stationDetails?.latitude)!, longitude: (stationDetails?.longitude)!)
        let span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.2)
        
        stationDetailMapView.setRegion(MKCoordinateRegion(center: center, span: span), animated: false)
        let stationLocation = CLLocationCoordinate2D(latitude: (stationDetails?.latitude)!, longitude: (stationDetails?.longitude)!)
        stationCoords.append(stationLocation)
        let annotation = StationPointAnno()
        annotation.title = stationDetails?.name
        annotation.coordinate = stationLocation
        annotation.station = stationDetails
        stationDetailMapView.addAnnotation(annotation)
        
        createRoute()
        
    }
    
    func createRoute() {
        let request = MKDirectionsRequest()
        
        let coords = CLLocationCoordinate2D(latitude: (stationDetails?.latitude)!, longitude: (stationDetails?.longitude)!)
        
        let destination = MKPlacemark(coordinate: coords)
        let source = MKPlacemark(coordinate: userLocation.coordinate)
        request.destination = MKMapItem(placemark: destination)
        request.source = MKMapItem(placemark: source)
        
        let directions = MKDirections(request: request)
        directions.calculate { (response: MKDirectionsResponse?, error: Error?) in
            guard let response = response else {
                print(error ?? "No Response and no error!")
                return
            }
            
            guard let route = response.routes.first else { return }
            
            for step in route.steps {
                self.stepByStepDirections.append(step.instructions)
                print(step.instructions)
            }
            self.setVisibleMapArea(polyline: route.polyline, edgeInsets: UIEdgeInsetsMake(15, 15, 15, 15))
            self.stationDetailMapView.add(route.polyline, level: .aboveRoads)
        }
    }
    
    func getPlacemark(forLocation location: CLLocation, completionHandler: @escaping (CLPlacemark?, String?) -> ()) {
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location, completionHandler: {
            placemarks, error in
            
            if let err = error {
                completionHandler(nil, err.localizedDescription)
            } else if let placemarkArray = placemarks {
                if let placemark = placemarkArray.first {
                    completionHandler(placemark, nil)
                } else {
                    completionHandler(nil, "Placemark was nil")
                }
            } else {
                completionHandler(nil, "Unknown error")
            }
        })
        
    }
    
//    func openMapForPlace() {
//        
//        let regionDistance:CLLocationDistance = 10000
//        let coordinates = CLLocationCoordinate2DMake((stationDetails?.latitude)!, (stationDetails?.longitude!)!)
//        let regionSpan = MKCoordinateRegionMakeWithDistance(coordinates, regionDistance, regionDistance)
//        let options = [
//            MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: regionSpan.center),
//            MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: regionSpan.span)
//        ]
//        let placemark = MKPlacemark(coordinate: coordinates, addressDictionary: nil)
//        let mapItem = MKMapItem(placemark: placemark)
//        mapItem.name = stationDetails?.name
//        mapItem.openInMaps(launchOptions: options)
//    }
    
    func pinSizedImage(from image:UIImage?) -> UIImage? {
        guard let image = image else { return nil }
        let newSize = CGSize(width: 35, height: 35)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
}

extension StationDetailsViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        if type(of: annotation) == MKUserLocation.self {
            return nil
        }
        let viewId = "myAnnotationViewId"
        var view = stationDetailMapView.dequeueReusableAnnotationView(withIdentifier: viewId)
        if view == nil {
            view = MKAnnotationView(annotation: annotation, reuseIdentifier: viewId)
        }
        view?.image = pinSizedImage(from: UIImage(named: "stationpinOrange"))
        view?.canShowCallout = false
        
        return view
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        print("call out was tapped, gotta go to the details page")

    }
    
    func setVisibleMapArea(polyline: MKPolyline, edgeInsets: UIEdgeInsets, animated: Bool = true) {
        self.stationDetailMapView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: edgeInsets, animated: animated)
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = UIColor(red: 0, green: 1.0, blue: 0, alpha: 0.7)
        return renderer
    }
    
}

extension StationDetailsViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        stationDetailMapView.showsUserLocation = true
        
        for location in locations {
            print("\(location.coordinate.latitude), \(location.coordinate.longitude)")
            userLocation = location
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            //self.fetchDirectionsToFirstPin()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
    }
}

extension StationDetailsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return stationsDetailsTableView.bounds.size.height - stationDetailMapView.bounds.size.height
        
    }
}

extension StationDetailsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = stationsDetailsTableView.dequeueReusableCell(withIdentifier: "StationDetailsTableViewCell", for: indexPath) as? StationDetailsTableViewCell else {
            return UITableViewCell()
        }
//        cell.backgroundColor = UIColor(red: 120/255, green: 135/255, blue: 171/255, alpha: 1)
        
        cell.stationCommentTextView.layer.borderWidth = 1
        
        cell.stationDetails = stationDetails
        
        if let stationName = stationDetails?.name, let rating = stationDetails?.rating {
            cell.stationNameLabel.text = stationName + " - " + ("\( rating )")
        }
        
        if let stationId = stationDetails?.id {
            cell.stationCommentTextView.text = StationsController.shared.commentForStation(stationId: stationId)
        }
        
        
        if let stationLat = stationDetails?.latitude, let stationLong = stationDetails?.longitude {
            let originLocation = CLLocation(latitude: stationLat, longitude: stationLong)
            
            getPlacemark(forLocation: originLocation) {
                (originPlacemark, error) in
                if let err = error {
                    print(err)
                } else if let placemark = originPlacemark {
                    var addressString = placemark.subThoroughfare ?? ""
                    addressString.append(" ")
                    addressString.append(placemark.thoroughfare ?? "")
                    addressString.append(", ")
                    addressString.append(placemark.locality ?? "")
                    addressString.append(", ")
                    addressString.append(placemark.administrativeArea ?? "")
                    cell.stationsAddressLabel.text = addressString
                    let distanceFrom = (originLocation.distance(from: self.userLocation) * 0.000621371)
                    cell.stationsDistanceLabel.text = String(format: "%.0f", distanceFrom) + " miles from you"
                    
                }
            }
            //cell.stationsAddressLabel.text = String(stationLat)
        }
        
        return cell
    }
    
    
}
