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
import Firebase
import Foundation
//import FirebaseFirestore

class StationDetailsViewController: UIViewController {
    
    @IBOutlet weak var stationDetailMapView: MKMapView!
    @IBOutlet weak var stationsDetailsTableView: UITableView!
    
    var userLocation = CLLocation()
    var stationDetails:Station?
    var dumpStationDetails:DumpStation?
    
    var text = NSMutableAttributedString(string: "")
//    var stationName:String = ""
//    var stationAddress = ""
//    var stationDistance = ""
    var stepByStepDirections:String = ""
    var stationCoords = [CLLocationCoordinate2D()]
    
    private let primaryBg  = UIColor(red: 10/255,  green: 25/255,  blue: 47/255,  alpha: 1)
    private let accentGold = UIColor(red: 212/255, green: 175/255, blue: 55/255,  alpha: 1)

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = primaryBg

        stationsDetailsTableView.backgroundColor = primaryBg
        stationsDetailsTableView.separatorStyle = .none
        stationsDetailsTableView.tableFooterView = UIView()
        stationsDetailsTableView.rowHeight = UITableView.automaticDimension
        stationsDetailsTableView.estimatedRowHeight = 800
        stationsDetailsTableView.isScrollEnabled = true

        // Favorite star button in nav bar
        updateFavoriteButton()

        // Map rounded corners + horizontal inset (16pt each side)
        stationDetailMapView.layer.cornerRadius = 16
        stationDetailMapView.clipsToBounds = true
        if let sv = stationDetailMapView.superview {
            for c in sv.constraints {
                if c.firstItem as? MKMapView == stationDetailMapView {
                    if c.firstAttribute == .leading  { c.constant = 16 }
                    if c.firstAttribute == .trailing { c.constant = -16 }
                    if c.firstAttribute == .bottom   { c.constant = -16 }
                }
            }
        }

        placeAnnotation()
        print("NAVIGATION CONTROLLER \(navigationController!)")
    }
    
    // MARK: - Favorite Toggle

    private var isFavorite: Bool {
        stationDetails?.favorite ?? dumpStationDetails?.favorite ?? false
    }

    private func updateFavoriteButton() {
        let imageName = isFavorite ? "star.fill" : "star"
        let starBtn = UIBarButtonItem(
            image: UIImage(systemName: imageName),
            style: .plain,
            target: self,
            action: #selector(favoriteTapped)
        )
        starBtn.tintColor = accentGold
        navigationItem.rightBarButtonItem = starBtn
    }

    @objc private func favoriteTapped() {
        // If already favorited → allow un-favoriting freely
        // If not favorited → check premium / free limit
        if !isFavorite && !PremiumManager.shared.canAddFavorite {
            let paywall = PaywallViewController()
            paywall.modalPresentationStyle = .formSheet
            present(paywall, animated: true)
            return
        }

        if let id = stationDetails?.id {
            StationsController.shared.toggleFavorite(stationId: id)
        } else if let id = dumpStationDetails?.id {
            DumpStationsController.shared.toggleFavorite(stationId: id)
        }
        updateFavoriteButton()
    }

    // Convenience accessors that work for either Station or DumpStation
    private var displayName: String? { stationDetails?.name ?? dumpStationDetails?.name }
    private var displayLatitude: Double { stationDetails?.latitude ?? dumpStationDetails?.latitude ?? 0.0 }
    private var displayLongitude: Double { stationDetails?.longitude ?? dumpStationDetails?.longitude ?? 0.0 }
    private var displayId: String? { stationDetails?.id ?? dumpStationDetails?.id }
    private var displayRating: String? { stationDetails?.rating ?? dumpStationDetails?.rating }
    private var displayComment: String? { stationDetails?.comment ?? dumpStationDetails?.comment }
    private var displayCost: String? { dumpStationDetails?.cost }
    
    func placeAnnotation() {
        guard stationDetails != nil || dumpStationDetails != nil else {
            print("Station details missing; cannot place annotation.")
            return
        }
        let center = CLLocationCoordinate2D(latitude: displayLatitude, longitude: displayLongitude)
        let span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.2)
        
        stationDetailMapView.setRegion(MKCoordinateRegion(center: center, span: span), animated: false)
        let stationLocation = CLLocationCoordinate2D(latitude: displayLatitude, longitude: displayLongitude)
        stationCoords.append(stationLocation)
        let annotation = StationPointAnno()
        annotation.title = displayName
        annotation.coordinate = stationLocation
        annotation.station = stationDetails
        stationDetailMapView.addAnnotation(annotation)
        
        createRoute()
        
    }
    
    func createRoute() {
        guard stationDetails != nil || dumpStationDetails != nil else {
            print("Station details missing; cannot create route.")
            return
        }
        let request = MKDirections.Request()
        let coords = CLLocationCoordinate2D(latitude: displayLatitude, longitude: displayLongitude)

        // Create MKMapItem instances using modern initializer (iOS 26+)
        let destinationLocation = CLLocation(latitude: coords.latitude, longitude: coords.longitude)
        let sourceLocation = CLLocation(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
        let destinationItem = MKMapItem(location: destinationLocation, address: nil)
        let sourceItem = MKMapItem(location: sourceLocation, address: nil)
        request.destination = destinationItem
        request.source = sourceItem

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
            self.setVisibleMapArea(polyline: route.polyline, edgeInsets: UIEdgeInsets.init(top: 15, left: 15, bottom: 15, right: 15))
            self.stationDetailMapView.addOverlay(route.polyline, level: .aboveRoads)
        }
    }
    
    private var geocodeCache: [String: CLPlacemark] = [:]

    func getPlacemark(forLocation location: CLLocation, completionHandler: @escaping (CLPlacemark?, String?) -> ()) {
        let cacheKey = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
        
        // Return cached result if available
        if let cached = geocodeCache[cacheKey] {
            completionHandler(cached, nil)
            return
        }
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let err = error {
                completionHandler(nil, err.localizedDescription)
            } else if let placemark = placemarks?.first {
                self.geocodeCache[cacheKey] = placemark  // Store in cache
                completionHandler(placemark, nil)
            } else {
                completionHandler(nil, "Placemark was nil")
            }
        }
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
    
//    func saveStationToFirestore(_ station: Station) {
//        let db = Firestore.firestore()
//        
//        guard let stationId = station.id else {
//            print("Station ID is nil – cannot save.")
//            return
//        }
//
//        let data: [String: Any] = [
//            "name": station.name ?? "",
//            "latitude": station.latitude ?? 0.0,
//            "longitude": station.longitude ?? 0.0,
//            "rating": station.rating ?? 0.0,
//            "note": StationsController.shared.commentForStation(stationId: stationId)
//        ]
//        
//        db.collection("stations").document(stationId).setData(data) { error in
//            if let error = error {
//                print("❌ Error saving station: \(error.localizedDescription)")
//            } else {
//                print("✅ Station saved to Firestore")
//            }
//        }
//    }
    
}

extension StationDetailsViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        if annotation is MKUserLocation {
            return nil
        }
        
        if dumpStationDetails != nil {
            let viewId = "dumpStationDetailAnnotationId"
            var view = stationDetailMapView.dequeueReusableAnnotationView(withIdentifier: viewId)
            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: viewId)
            }
            if let markerView = view as? MKMarkerAnnotationView {
                markerView.markerTintColor = .brown
                markerView.glyphImage = UIImage(systemName: "drop.fill")
            }
            view?.canShowCallout = false
            return view
        }
        
        let viewId = "stationDetailAnnotationId"
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
        renderer.strokeColor = UIColor(red: 212/255, green: 175/255, blue: 55/255, alpha: 0.85)
        renderer.lineWidth = 3
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
        
        if let details = stationDetails { cell.stationDetails = details }
        
        if let stationName = displayName, let rating = displayRating {
            cell.stationNameLabel.text = stationName + " - " + ("\( rating )")
        }
        
        if let stationId = displayId {
            cell.stationCommentTextView.text = StationsController.shared.commentForStation(stationId: stationId)
        }
        cell.updatePlaceholder()
        
        
        let stationLat = displayLatitude
        let stationLong = displayLongitude
        if stationDetails != nil || dumpStationDetails != nil {
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
            // Build info section: Cost, Description, and Amenities
            if let container = cell.amenitiesContainerView {
                // Clear old content (safety)
                container.subviews.forEach { $0.removeFromSuperview() }

                // Style the container as a dark card
                container.backgroundColor = UIColor(red: 22/255, green: 38/255, blue: 62/255, alpha: 1)
                container.layer.cornerRadius = 14
                container.clipsToBounds = true

                let vStack = UIStackView()
                vStack.axis = .vertical
                vStack.alignment = .fill
                vStack.distribution = .fill
                vStack.spacing = 14
                vStack.translatesAutoresizingMaskIntoConstraints = false

                // Cost (shown when available, e.g. dump stations)
                if let cost = self.displayCost, !cost.isEmpty {
                    let costRow = UIStackView()
                    costRow.axis = .horizontal
                    costRow.alignment = .center
                    costRow.spacing = 6

                    let costIcon = UIImageView(image: UIImage(systemName: "dollarsign.circle.fill"))
                    costIcon.tintColor = .systemGreen
                    costIcon.setContentHuggingPriority(.required, for: .horizontal)
                    costIcon.setContentCompressionResistancePriority(.required, for: .horizontal)

                    let costLabel = UILabel()
                    costLabel.text = cost
                    costLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
                    costLabel.textColor = UIColor(red: 212/255, green: 175/255, blue: 55/255, alpha: 1)

                    costRow.addArrangedSubview(costIcon)
                    costRow.addArrangedSubview(costLabel)
                    vStack.addArrangedSubview(costRow)
                }

                // Description / Comment from JSON data
                if let comment = self.displayComment, !comment.isEmpty {
                    let commentLabel = UILabel()
                    commentLabel.text = comment
                    commentLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
                    commentLabel.textColor = UIColor(red: 150/255, green: 165/255, blue: 190/255, alpha: 1)
                    commentLabel.numberOfLines = 0
                    vStack.addArrangedSubview(commentLabel)
                }

                // Amenities header
                let header = UILabel()
                header.text = "Amenities"
                header.font = UIFont.systemFont(ofSize: 16, weight: .bold)
                header.textColor = UIColor(red: 212/255, green: 175/255, blue: 55/255, alpha: 1)
                vStack.addArrangedSubview(header)

                // Grid (2 columns)
                let grid = UIStackView()
                grid.axis = .horizontal
                grid.alignment = .top
                grid.distribution = .fillEqually
                grid.spacing = 16

                let col1 = UIStackView()
                col1.axis = .vertical
                col1.alignment = .leading
                col1.spacing = 6

                let col2 = UIStackView()
                col2.axis = .vertical
                col2.alignment = .leading
                col2.spacing = 6

                let mutedTextColor = UIColor(red: 150/255, green: 165/255, blue: 190/255, alpha: 1)

                func row(title: String, value: Bool) -> UIStackView {
                    let h = UIStackView()
                    h.axis = .horizontal
                    h.alignment = .center
                    h.spacing = 8

                    let icon = UIImageView()
                    let symbolName = value ? "checkmark.circle.fill" : "xmark.circle"
                    icon.image = UIImage(systemName: symbolName)
                    icon.tintColor = value
                        ? UIColor(red: 52/255, green: 199/255, blue: 89/255, alpha: 1)
                        : UIColor(red: 100/255, green: 115/255, blue: 140/255, alpha: 1)
                    icon.setContentCompressionResistancePriority(.required, for: .horizontal)
                    icon.setContentHuggingPriority(.required, for: .horizontal)
                    NSLayoutConstraint.activate([
                        icon.widthAnchor.constraint(equalToConstant: 18),
                        icon.heightAnchor.constraint(equalToConstant: 18)
                    ])

                    let label = UILabel()
                    label.text = title
                    label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
                    label.textColor = value ? UIColor.white : mutedTextColor

                    h.addArrangedSubview(icon)
                    h.addArrangedSubview(label)
                    return h
                }

                if let amenity = self.stationDetails?.amenity {
                    // RV-focused station amenities: 7 items -> split 4 and 3
                    let items: [(String, Bool)] = [
                        ("Diesel", amenity.diesel),
                        ("Large Vehicle Access", amenity.hgvAccess),
                        ("DEF at Pump", amenity.defAtPump),
                        ("Shower", amenity.shower),
                        ("Bathroom", amenity.bathroom),
                        ("Repair Shop", amenity.repairShop),
                        ("CAT Scale", amenity.catScale)
                    ]
                    for (index, item) in items.enumerated() {
                        let r = row(title: item.0, value: item.1)
                        if index < 3 {
                            col1.addArrangedSubview(r)
                        } else {
                            col2.addArrangedSubview(r)
                        }
                    }

                    // Canopy height row (shown only when data is available)
                    if let height = self.stationDetails?.canopyHeight, !height.isEmpty {
                        let heightRow = UIStackView()
                        heightRow.axis = .horizontal
                        heightRow.spacing = 8
                        heightRow.alignment = .center

                        let icon = UIImageView(image: UIImage(systemName: "arrow.up.and.down"))
                        icon.tintColor = UIColor(red: 212/255, green: 175/255, blue: 55/255, alpha: 1)
                        icon.translatesAutoresizingMaskIntoConstraints = false
                        NSLayoutConstraint.activate([
                            icon.widthAnchor.constraint(equalToConstant: 18),
                            icon.heightAnchor.constraint(equalToConstant: 18)
                        ])

                        let lbl = UILabel()
                        lbl.text = "Canopy Height: \(height)"
                        lbl.font = UIFont.systemFont(ofSize: 14, weight: .regular)
                        lbl.textColor = .white

                        heightRow.addArrangedSubview(icon)
                        heightRow.addArrangedSubview(lbl)
                        vStack.addArrangedSubview(heightRow)
                    }
                } else if let dumpAmenities = self.dumpStationDetails?.amenities {
                    // Dump station amenities: 6 items -> split 3 and 3
                    let items: [(String, Bool)] = [
                        ("Potable Water", dumpAmenities.potableWater),
                        ("Rinse Water", dumpAmenities.rinseWater),
                        ("Trailer Parking", dumpAmenities.trailerParking),
                        ("Restrooms", dumpAmenities.restrooms),
                        ("Vending", dumpAmenities.vending),
                        ("EV Charging", dumpAmenities.evCharging)
                    ]
                    for (index, item) in items.enumerated() {
                        let r = row(title: item.0, value: item.1)
                        if index < 3 {
                            col1.addArrangedSubview(r)
                        } else {
                            col2.addArrangedSubview(r)
                        }
                    }
                }

                grid.addArrangedSubview(col1)
                grid.addArrangedSubview(col2)
                vStack.addArrangedSubview(grid)

                container.addSubview(vStack)

                NSLayoutConstraint.activate([
                    vStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
                    vStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
                    vStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
                    vStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
                ])
            }
            // Fetch and display weather for this station
            Task { [weak cell] in
                do {
                    let weather = try await WeatherService.shared.fetchCurrentWeather(lat: stationLat, lon: stationLong)
                    let temp = Int(weather.main.temp.rounded())
                    let summary = weather.weather.first?.description.capitalized ?? "—"
                    await MainActor.run {
                        cell?.weatherLabel?.text = "\(temp)° - \(summary)"
                    }
                } catch {
                    await MainActor.run {
                        cell?.weatherLabel?.text = "Weather unavailable"
                    }
                }
            }
        }
        
        return cell
    }
}

extension UINavigationController {
    var previousViewController: UIViewController? {
       viewControllers.count > 1 ? viewControllers[viewControllers.count - 2] : nil
    }
}

