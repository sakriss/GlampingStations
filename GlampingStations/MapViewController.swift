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
    private var mapFilterState = MapFilterState()
    private var filterBarButton: UIBarButtonItem!

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

        // Register cluster annotation view
        mapView.register(MKMarkerAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)

        view.addSubview(mapView)

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // Add filter button alongside the storyboard's settings button
        let filterImage = UIImage(systemName: "line.3.horizontal.decrease.circle")
        filterBarButton = UIBarButtonItem(image: filterImage,
                                         style: .plain,
                                         target: self,
                                         action: #selector(filterTapped))
        filterBarButton.tintColor = .white
        if let existingButton = navigationItem.rightBarButtonItem {
            navigationItem.rightBarButtonItems = [existingButton, filterBarButton]
        } else {
            navigationItem.rightBarButtonItem = filterBarButton
        }

        addGasStationAnnotations()
        addDumpStationAnnotations()

        NotificationCenter.default.addObserver(self, selector: #selector(dumpStationsLoaded), name: DumpStationsController.dumpStationsDataParseComplete, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(gasStationsLoaded), name: StationsController.stationsDataParseComplete, object: nil)
    }

    @objc func dumpStationsLoaded() {
        DispatchQueue.main.async {
            self.addDumpStationAnnotations()
        }
    }

    @objc func gasStationsLoaded() {
        DispatchQueue.main.async {
            self.addGasStationAnnotations()
        }
    }

    func addGasStationAnnotations() {
        let existing = mapView.annotations.filter { $0 is StationPointAnno }
        mapView.removeAnnotations(existing)
        stationCoords.removeAll()

        guard mapFilterState.showFuelStations,
              let stations = StationsController.shared.stations else { return }

        for station in stations {
            if !stationPassesFuelFilter(station) { continue }
            let coordinate = CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude)
            stationCoords.append(coordinate)
            let annotation = StationPointAnno()
            annotation.title = station.name
            annotation.coordinate = coordinate
            annotation.station = station
            mapView.addAnnotation(annotation)
        }
    }

    func addDumpStationAnnotations() {
        let existing = mapView.annotations.filter { $0 is DumpStationPointAnno }
        mapView.removeAnnotations(existing)

        guard mapFilterState.showDumpStations,
              let dumpStations = DumpStationsController.shared.dumpStation else { return }

        for ds in dumpStations {
            if !dumpStationPassesFilter(ds) { continue }
            let coordinate = CLLocationCoordinate2D(latitude: ds.latitude, longitude: ds.longitude)
            let annotation = DumpStationPointAnno()
            annotation.title = ds.name
            annotation.coordinate = coordinate
            annotation.dumpStation = ds
            mapView.addAnnotation(annotation)
        }
    }

    // MARK: - Filter Helpers

    private func stationPassesFuelFilter(_ station: Station) -> Bool {
        // Radius check
        if let radius = mapFilterState.radius {
            let stationLocation = CLLocation(latitude: station.latitude, longitude: station.longitude)
            let distanceMiles = userLocation.distance(from: stationLocation) / 1609.344
            if distanceMiles > radius { return false }
        }

        // State check
        if let stateFilter = mapFilterState.stateFilter {
            guard station.state == stateFilter else { return false }
        }

        // Amenity check
        let amenityFilters = mapFilterState.fuelAmenities.subtracting(["Customer Added"])
        let showPersonal = mapFilterState.fuelAmenities.contains("Customer Added")

        if !amenityFilters.isEmpty || showPersonal {
            let isPersonal = station.source == nil
            if isPersonal {
                if !showPersonal { return false }
            } else {
                if amenityFilters.isEmpty { return false }
                guard let a = station.amenity else { return false }
                let ts = station.isTruckStop
                let passes = amenityFilters.allSatisfy { filter in
                    switch filter {
                    case "Diesel":               return a.diesel    || ts
                    case "Large Vehicle Access": return a.hgvAccess || ts
                    case "DEF at Pump":          return a.defAtPump
                    case "Shower":               return a.shower
                    case "Bathroom":             return a.bathroom
                    case "Repair Shop":          return a.repairShop
                    case "CAT Scale":            return a.catScale
                    default:                     return false
                    }
                }
                if !passes { return false }
            }
        }

        return true
    }

    private func dumpStationPassesFilter(_ ds: DumpStation) -> Bool {
        // Radius check
        if let radius = mapFilterState.radius {
            let dsLocation = CLLocation(latitude: ds.latitude, longitude: ds.longitude)
            let distanceMiles = userLocation.distance(from: dsLocation) / 1609.344
            if distanceMiles > radius { return false }
        }

        // State check
        if let stateFilter = mapFilterState.stateFilter {
            guard ds.state == stateFilter else { return false }
        }

        // Amenity check
        let amenityFilters = mapFilterState.dumpAmenities.subtracting(["Customer Added"])
        let showPersonal = mapFilterState.dumpAmenities.contains("Customer Added")

        if !amenityFilters.isEmpty || showPersonal {
            let isPersonal = ds.source == nil
            if isPersonal {
                if !showPersonal { return false }
            } else {
                if amenityFilters.isEmpty { return false }
                guard let a = ds.amenities else { return false }
                let passes = amenityFilters.allSatisfy { filter in
                    switch filter {
                    case "Potable Water":   return a.potableWater
                    case "Rinse Water":     return a.rinseWater
                    case "Trailer Parking": return a.trailerParking
                    case "Restrooms":       return a.restrooms
                    case "Vending":         return a.vending
                    case "EV Charging":     return a.evCharging
                    default:               return false
                    }
                }
                if !passes { return false }
            }
        }

        return true
    }

    private func availableStatesForFilter() -> [String] {
        var states = Set<String>()
        StationsController.shared.stations?.compactMap { $0.state }.forEach { states.insert($0) }
        DumpStationsController.shared.dumpStation?.compactMap { $0.state }.forEach { states.insert($0) }
        return states.sorted()
    }

    private func updateFilterButtonIcon() {
        let iconName = mapFilterState.isActive
            ? "line.3.horizontal.decrease.circle.fill"
            : "line.3.horizontal.decrease.circle"
        filterBarButton.image = UIImage(systemName: iconName)
        filterBarButton.tintColor = mapFilterState.isActive ? UIColor(red: 212/255, green: 175/255, blue: 55/255, alpha: 1) : .white
    }

    // MARK: - Filter Button

    @objc private func filterTapped() {
        let vc = MapFilterViewController()
        vc.currentState = mapFilterState
        vc.availableStates = availableStatesForFilter()
        vc.delegate = self
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        // Hide the default nav bar in the sheet — the VC has its own title label
        nav.setNavigationBarHidden(true, animated: false)
        present(nav, animated: true)
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

// MARK: - MapFilterDelegate

extension MapViewController: MapFilterDelegate {
    func mapFilterDidApply(_ state: MapFilterState) {
        mapFilterState = state
        addGasStationAnnotations()
        addDumpStationAnnotations()
        updateFilterButtonIcon()
    }

    func mapFilterDidReset() {
        mapFilterState = MapFilterState()
        addGasStationAnnotations()
        addDumpStationAnnotations()
        updateFilterButtonIcon()
    }
}

// MARK: - MKMapViewDelegate

extension MapViewController: MKMapViewDelegate {

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {

        if annotation is MKUserLocation {
            return nil
        }

        // Cluster annotation
        if let cluster = annotation as? MKClusterAnnotation {
            let viewId = MKMapViewDefaultClusterAnnotationViewReuseIdentifier
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: viewId, for: cluster) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: cluster, reuseIdentifier: viewId)
            view.annotation = cluster
            let members = cluster.memberAnnotations
            let hasFuel = members.contains { $0 is StationPointAnno }
            let hasDump = members.contains { $0 is DumpStationPointAnno }
            if hasFuel && hasDump {
                view.markerTintColor = UIColor(red: 128/255, green: 0/255, blue: 128/255, alpha: 1) // purple
            } else if hasDump {
                view.markerTintColor = .brown
            } else {
                view.markerTintColor = UIColor(red: 200/255, green: 80/255, blue: 20/255, alpha: 1) // orange
            }
            view.glyphText = "\(members.count)"
            return view
        }

        if annotation is DumpStationPointAnno {
            let viewId = "dumpStationAnnotationId"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: viewId)
            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: viewId)
            }
            view?.annotation = annotation
            if let markerView = view as? MKMarkerAnnotationView {
                markerView.markerTintColor = UIColor.brown
                markerView.glyphImage = UIImage(systemName: "drop.fill")
                markerView.clusteringIdentifier = "stationCluster"
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
        view?.annotation = annotation
        view?.image = pinSizedImage(from: UIImage(named: "stationpinOrange"))
        view?.canShowCallout = true
        view?.clusteringIdentifier = "stationCluster"

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

        // Trigger Overpass fetch so nearby stations load even when the user
        // navigates directly to the Map tab without visiting the List tab first.
        // The 5 km throttle in StationsController prevents redundant fetches.
        StationsController.shared.fetchOverpassStations(near: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
    }
}
