//
//  MapViewController.swift
//  GlampingStations
//
//  Created by Scott Kriss on 7/23/18.
//  Copyright © 2018 Scott Kriss. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class StationPointAnno: MKPointAnnotation {
    var station: Station?
    
}

class MapViewController: UIViewController {
    var currentlySelectedStation:Station?
    let mapView = MKMapView()
    let locationManager = CLLocationManager()
    var stationCoords = [CLLocationCoordinate2D()]
    var userLocation = CLLocation()
    var stepByStepDirections = [String]()
    var imageOfRoute = UIImage()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.startUpdatingLocation()
        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.delegate = self
        
        let center = CLLocationCoordinate2D(latitude: 47.625030, longitude: -122.337419)
        let span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.2)
        
        mapView.setRegion(MKCoordinateRegion(center: center, span: span), animated: false)
        
        view.addSubview(mapView)
        
        let safeArea = view.safeAreaLayoutGuide
        
        mapView.topAnchor.constraint(equalTo: safeArea.topAnchor).isActive = true
        mapView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor).isActive = true
        mapView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor).isActive = true
        mapView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor).isActive = true
        
        for station in StationsController.shared.stations! {
            let lat = station.latitude
            let long = station.longitude
            let stationLocation = CLLocationCoordinate2D(latitude: lat!, longitude: long!)
            
            stationCoords.append(stationLocation)
            
            let annotation = StationPointAnno()
            annotation.title = station.name
            annotation.coordinate = stationLocation
            annotation.station = station
            mapView.addAnnotation(annotation)
            
        }

    }
    
    func pinSizedImage(from image:UIImage?) -> UIImage? {
        guard let image = image else { return nil }
        let newSize = CGSize(width: 35, height: 35)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "stationDetailsSegue", let vc = segue.destination as? StationDetailsViewController {
            if let station = currentlySelectedStation {
                vc.stationDetails = station
                vc.userLocation = userLocation
            }
        }
    }
    
    func createMapRendering() {
        UIGraphicsBeginImageContextWithOptions(self.view.bounds.size, true, 1.0)
        view.layer.render(in: UIGraphicsGetCurrentContext()!)
        self.view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        imageOfRoute = image!
        UIGraphicsEndImageContext()
    }

}

extension MapViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    
        if type(of: annotation) == MKUserLocation.self {
            return nil
        }
        let viewId = "myAnnotationViewId"
        var view = mapView.dequeueReusableAnnotationView(withIdentifier: viewId)
        if view == nil {
            view = MKAnnotationView(annotation: annotation, reuseIdentifier: viewId)
        }
        view?.image = pinSizedImage(from: UIImage(named: "stationpinOrange"))
        view?.canShowCallout = true
        
        let rightButton = UIButton(type: .detailDisclosure)
        view?.rightCalloutAccessoryView = rightButton
        return view
    }
    
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            print("call out was tapped, gotta go to the details page")
            
            if let annotation = mapView.selectedAnnotations[0] as? StationPointAnno {
                self.currentlySelectedStation = annotation.station
            }
            
            
            createMapRendering()
            
            self.performSegue(withIdentifier: "stationDetailsSegue", sender: self)
    }
    
    func setVisibleMapArea(polyline: MKPolyline, edgeInsets: UIEdgeInsets, animated: Bool = true) {
        self.mapView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: edgeInsets, animated: animated)
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = UIColor(red: 0, green: 1.0, blue: 0, alpha: 0.7)
        return renderer
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        
        let request = MKDirections.Request()

        let coords = CLLocationCoordinate2D(latitude: mapView.selectedAnnotations[0].coordinate.latitude, longitude: mapView.selectedAnnotations[0].coordinate.longitude )

        let destination = MKPlacemark(coordinate: coords)
        let source = MKPlacemark(coordinate: mapView.userLocation.coordinate)
        request.destination = MKMapItem(placemark: destination)
        request.source = MKMapItem(placemark: source)
        
        let directions = MKDirections(request: request)
        directions.calculate { (response: MKDirections.Response?, error: Error?) in
            guard let response = response else {
                print(error ?? "No Response and no error!")
                return
            }
            
            guard let route = response.routes.first else { return }
            
            for step in route.steps {
                self.stepByStepDirections.append(step.instructions)
                print(step.instructions)
            }
            self.setVisibleMapArea(polyline: route.polyline, edgeInsets: UIEdgeInsets.init(top: 90, left: 40, bottom: 40, right: 40))
            self.mapView.addOverlay(route.polyline, level: .aboveRoads)
            
            
        }

        
        print("Pin has been tapped")
    }
    
    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        self.mapView.overlays.forEach {
            if !($0 is MKUserLocation) {
                self.mapView.removeOverlay($0)
            }
        }
        stepByStepDirections = []
    }

}

extension MapViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        mapView.showsUserLocation = true
        
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

