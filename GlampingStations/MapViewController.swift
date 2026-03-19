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

class DumpStationPointAnno: MKPointAnnotation {
    var dumpStation: DumpStation?
}

class MapViewController: UIViewController {
    var currentlySelectedStation:Station?
    var currentlySelectedDumpStation:DumpStation?
    let mapView = MKMapView()
    let locationManager = CLLocationManager()
    var stationCoords = [CLLocationCoordinate2D()]
    var userLocation = CLLocation()
    var stepByStepDirections = [String]()
    var imageOfRoute = UIImage()
    
    private var hasSetInitialRegion = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.standardAppearance = AppDelegate.tabBarAppearance
        tabBarController?.tabBar.scrollEdgeAppearance = AppDelegate.tabBarAppearance
        navigationController?.navigationBar.standardAppearance = AppDelegate.navBarAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = AppDelegate.navBarAppearance
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Map"

        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()

        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.delegate = self

        // Explicitly enable all interactions
        mapView.isZoomEnabled     = true
        mapView.isScrollEnabled   = true
        mapView.isRotateEnabled   = true
        mapView.isPitchEnabled    = true
        mapView.showsUserLocation = true
        mapView.showsCompass      = true
        mapView.showsScale        = true

        view.addSubview(mapView)

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        if let stations = StationsController.shared.stations {
            for station in stations {
                let lat = station.latitude
                let long = station.longitude
                let stationLocation = CLLocationCoordinate2D(latitude: lat, longitude: long)
                
                stationCoords.append(stationLocation)
                
                let annotation = StationPointAnno()
                annotation.title = station.name
                annotation.coordinate = stationLocation
                annotation.station = station
                mapView.addAnnotation(annotation)
            }
        }
        
        addDumpStationAnnotations()
        
        NotificationCenter.default.addObserver(self, selector: #selector(dumpStationsLoaded), name: DumpStationsController.dumpStationsDataParseComplete, object: nil)
    }
    
    @objc func dumpStationsLoaded() {
        DispatchQueue.main.async {
            self.addDumpStationAnnotations()
        }
    }
    
    func addDumpStationAnnotations() {
        guard let dumpStations = DumpStationsController.shared.dumpStation else { return }
        for ds in dumpStations {
            let coordinate = CLLocationCoordinate2D(latitude: ds.latitude, longitude: ds.longitude)
            let annotation = DumpStationPointAnno()
            annotation.title = ds.name
            annotation.coordinate = coordinate
            annotation.dumpStation = ds
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
            } else if let dumpStation = currentlySelectedDumpStation {
                vc.dumpStationDetails = dumpStation
            }
            vc.userLocation = userLocation
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
    
        if annotation is MKUserLocation {
            return nil
        }
        
        if annotation is DumpStationPointAnno {
            let viewId = "dumpStationAnnotationId"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: viewId)
            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: viewId)
            }
            if let markerView = view as? MKMarkerAnnotationView {
                markerView.markerTintColor = UIColor.brown
                markerView.glyphImage = UIImage(systemName: "drop.fill")
            }
            view?.canShowCallout = true
            let rightButton = UIButton(type: .detailDisclosure)
            view?.rightCalloutAccessoryView = rightButton
            return view
        }
        
        // Station pins
        let viewId = "stationAnnotationId"
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
        
        currentlySelectedStation = nil
        currentlySelectedDumpStation = nil
        
        if let annotation = view.annotation as? StationPointAnno {
            self.currentlySelectedStation = annotation.station
        } else if let annotation = view.annotation as? DumpStationPointAnno {
            self.currentlySelectedDumpStation = annotation.dumpStation
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
            guard let response = response, let route = response.routes.first else {
                print(error ?? "No Response and no error!")
                return
            }
            for step in route.steps {
                self.stepByStepDirections.append(step.instructions)
            }
            // Add the route overlay without changing the user's zoom level
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
        guard let location = locations.last else { return }
        userLocation = location

        // Center the map on the user's real location the first time we get it
        if !hasSetInitialRegion {
            hasSetInitialRegion = true
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 50_000,
                longitudinalMeters: 50_000
            )
            mapView.setRegion(region, animated: false)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
    }
}

