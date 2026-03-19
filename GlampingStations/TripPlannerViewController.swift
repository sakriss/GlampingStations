//
//  TripPlannerViewController.swift
//  GlampingStations
//
//  Created by Scott Kriss on 3/19/26.
//  Copyright © 2026 Scott Kriss. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

// MARK: - Supporting Types

enum TripStationType {
    case gas(Station)
    case dump(DumpStation)

    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .gas(let s):  return CLLocationCoordinate2D(latitude: s.latitude, longitude: s.longitude)
        case .dump(let s): return CLLocationCoordinate2D(latitude: s.latitude, longitude: s.longitude)
        }
    }
    var name: String {
        switch self {
        case .gas(let s):  return s.name ?? "Gas Station"
        case .dump(let s): return s.name ?? "Dump Station"
        }
    }
    var locationLabel: String {
        switch self {
        case .gas(let s):
            if let city = s.city, let state = s.state { return "\(city), \(state)" }
            return s.address ?? ""
        case .dump(let s):
            if let city = s.city, let state = s.state { return "\(city), \(state)" }
            return s.address ?? ""
        }
    }
    var systemIcon: String {
        switch self {
        case .gas:  return "fuelpump.fill"
        case .dump: return "drop.fill"
        }
    }
    var station: Any {
        switch self {
        case .gas(let s):  return s
        case .dump(let s): return s
        }
    }
}

struct TripStation {
    let type: TripStationType
    let milesFromStart: Double
    let milesFromRoute: Double
}

// Custom annotation for trip stations
class TripStationAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    var stationType: TripStationType?

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}

// MARK: - TripPlannerViewController

class TripPlannerViewController: UIViewController {

    // MARK: - Colors
    private let primaryBg  = UIColor(red: 10/255,  green: 25/255,  blue: 47/255,  alpha: 1)
    private let cardColor  = UIColor(red: 22/255,  green: 38/255,  blue: 62/255,  alpha: 1)
    private let accentGold = UIColor(red: 212/255, green: 175/255, blue: 55/255,  alpha: 1)
    private let mutedText  = UIColor(red: 150/255, green: 165/255, blue: 190/255, alpha: 1)

    // MARK: - Public
    var userLocation: CLLocation = CLLocation(latitude: 0, longitude: 0)

    // MARK: - UI
    private let searchField   = UITextField()
    private let clearButton   = UIButton(type: .system)
    private let searchButton  = UIButton(type: .system)
    private let mapView       = MKMapView()
    private let corridorLabel = UILabel()
    private let corridorSegment = UISegmentedControl(items: ["10 mi", "25 mi", "50 mi"])
    private let tableView     = UITableView()
    private let statusLabel   = UILabel()
    private let loadingView   = UIActivityIndicatorView(style: .medium)

    // Completions dropdown
    private var completionsTable: UITableView?
    private var completionsTableHeightConstraint: NSLayoutConstraint?

    // MARK: - State
    private var corridorMiles: Double = 25.0
    private var routePolyline: MKPolyline?
    private var tripStations: [TripStation] = []
    private var searchCompleter = MKLocalSearchCompleter()
    private var completions: [MKLocalSearchCompletion] = []
    private var isSearching = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Trip Planner"
        view.backgroundColor = primaryBg

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
        navigationItem.leftBarButtonItem?.tintColor = accentGold

        setupSearchField()
        setupMap()
        setupCorridorControl()
        setupTableView()
        setupStatusLabel()
        setupLoadingIndicator()
        setupCompletionsTable()
        layoutViews()

        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .pointOfInterest, .query]
    }

    // MARK: - Setup

    private func setupSearchField() {
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholder = "Where are you headed?"
        searchField.textColor = .white
        searchField.backgroundColor = cardColor
        searchField.layer.cornerRadius = 10
        searchField.layer.masksToBounds = true
        searchField.font = UIFont.systemFont(ofSize: 16)
        searchField.returnKeyType = .search
        searchField.delegate = self
        searchField.addTarget(self, action: #selector(searchFieldChanged), for: .editingChanged)

        // Left icon
        let iconContainer = UIView(frame: CGRect(x: 0, y: 0, width: 36, height: 20))
        let iconView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        iconView.tintColor = mutedText
        iconView.frame = CGRect(x: 8, y: 0, width: 20, height: 20)
        iconContainer.addSubview(iconView)
        searchField.leftView = iconContainer
        searchField.leftViewMode = .always

        // Right clear button
        clearButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clearButton.tintColor = mutedText
        clearButton.frame = CGRect(x: 0, y: 0, width: 36, height: 20)
        clearButton.addTarget(self, action: #selector(clearSearch), for: .touchUpInside)
        clearButton.isHidden = true
        searchField.rightView = clearButton
        searchField.rightViewMode = .always

        // Placeholder color
        searchField.attributedPlaceholder = NSAttributedString(
            string: "Where are you headed?",
            attributes: [.foregroundColor: mutedText]
        )
    }

    private func setupMap() {
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.delegate = self
        mapView.layer.cornerRadius = 16
        mapView.clipsToBounds = true
        mapView.showsUserLocation = true

        if userLocation.coordinate.latitude != 0 {
            let region = MKCoordinateRegion(
                center: userLocation.coordinate,
                latitudinalMeters: 800_000,
                longitudinalMeters: 800_000
            )
            mapView.setRegion(region, animated: false)
        }
    }

    private func setupCorridorControl() {
        corridorLabel.text = "Corridor:"
        corridorLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        corridorLabel.textColor = mutedText
        corridorLabel.translatesAutoresizingMaskIntoConstraints = false

        corridorSegment.translatesAutoresizingMaskIntoConstraints = false
        corridorSegment.selectedSegmentIndex = 1
        corridorSegment.backgroundColor = cardColor
        corridorSegment.setTitleTextAttributes([.foregroundColor: mutedText], for: .normal)
        corridorSegment.setTitleTextAttributes(
            [.foregroundColor: UIColor(red: 10/255, green: 25/255, blue: 47/255, alpha: 1)],
            for: .selected
        )
        corridorSegment.selectedSegmentTintColor = accentGold
        corridorSegment.addTarget(self, action: #selector(corridorChanged), for: .valueChanged)
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = primaryBg
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.register(TripStationCell.self,   forCellReuseIdentifier: TripStationCell.reuseId)
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 32, right: 0)
    }

    private func setupStatusLabel() {
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Search for a destination to find gas and dump stations along your route."
        statusLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        statusLabel.textColor = mutedText
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
    }

    private func setupLoadingIndicator() {
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.color = accentGold
        loadingView.hidesWhenStopped = true
    }

    private func setupCompletionsTable() {
        let ct = UITableView()
        ct.translatesAutoresizingMaskIntoConstraints = false
        ct.backgroundColor = UIColor(red: 18/255, green: 32/255, blue: 54/255, alpha: 1)
        ct.layer.cornerRadius = 10
        ct.layer.borderWidth = 1
        ct.layer.borderColor = accentGold.withAlphaComponent(0.2).cgColor
        ct.separatorColor = UIColor(red: 40/255, green: 60/255, blue: 90/255, alpha: 1)
        ct.rowHeight = 50
        ct.dataSource = self
        ct.delegate   = self
        ct.isHidden   = true
        ct.register(UITableViewCell.self, forCellReuseIdentifier: "completion")
        completionsTable = ct
    }

    private func layoutViews() {
        let corridorRow = UIStackView(arrangedSubviews: [corridorLabel, corridorSegment])
        corridorRow.axis = .horizontal
        corridorRow.spacing = 10
        corridorRow.alignment = .center
        corridorRow.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(searchField)
        view.addSubview(mapView)
        view.addSubview(corridorRow)
        view.addSubview(tableView)
        view.addSubview(statusLabel)
        view.addSubview(loadingView)

        if let ct = completionsTable {
            view.addSubview(ct)
        }

        let safe = view.safeAreaLayoutGuide

        let ctHeightConstraint = completionsTable?.heightAnchor.constraint(equalToConstant: 0)
        ctHeightConstraint?.isActive = true
        completionsTableHeightConstraint = ctHeightConstraint

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: safe.topAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchField.heightAnchor.constraint(equalToConstant: 44),

            mapView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            mapView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.33),

            corridorRow.topAnchor.constraint(equalTo: mapView.bottomAnchor, constant: 12),
            corridorRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            corridorRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: corridorRow.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            statusLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: tableView.topAnchor, constant: 32),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            loadingView.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            loadingView.topAnchor.constraint(equalTo: tableView.topAnchor, constant: 40),
        ])

        if let ct = completionsTable {
            NSLayoutConstraint.activate([
                ct.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 4),
                ct.leadingAnchor.constraint(equalTo: searchField.leadingAnchor),
                ct.trailingAnchor.constraint(equalTo: searchField.trailingAnchor),
            ])
            view.bringSubviewToFront(ct)
        }
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func clearSearch() {
        searchField.text = ""
        clearButton.isHidden = true
        hideCompletions()
        searchCompleter.queryFragment = ""
    }

    @objc private func searchFieldChanged() {
        let text = searchField.text ?? ""
        clearButton.isHidden = text.isEmpty
        searchCompleter.queryFragment = text
    }

    @objc private func corridorChanged() {
        let options: [Double] = [10, 25, 50]
        corridorMiles = options[corridorSegment.selectedSegmentIndex]
        if routePolyline != nil {
            findStationsAlongRoute()
        }
    }

    // MARK: - Completions

    private func showCompletions() {
        guard let ct = completionsTable else { return }
        let rowHeight: CGFloat = 50
        let maxRows: CGFloat = 4
        let height = min(CGFloat(completions.count) * rowHeight, maxRows * rowHeight)
        completionsTableHeightConstraint?.constant = height
        ct.isHidden = completions.isEmpty
        ct.reloadData()
        view.bringSubviewToFront(ct)
    }

    private func hideCompletions() {
        completionsTableHeightConstraint?.constant = 0
        completionsTable?.isHidden = true
    }

    private func selectCompletion(_ completion: MKLocalSearchCompletion) {
        searchField.text = completion.title + (completion.subtitle.isEmpty ? "" : ", \(completion.subtitle)")
        clearButton.isHidden = false
        hideCompletions()
        searchField.resignFirstResponder()

        let searchRequest = MKLocalSearch.Request(completion: completion)
        MKLocalSearch(request: searchRequest).start { [weak self] response, error in
            guard let self, let item = response?.mapItems.first else { return }
            DispatchQueue.main.async {
                self.calculateRoute(to: item.placemark.coordinate, name: item.name)
            }
        }
    }

    // MARK: - Route Calculation

    private func calculateRoute(to destination: CLLocationCoordinate2D, name: String?) {
        loadingView.startAnimating()
        statusLabel.isHidden = true
        tripStations = []
        tableView.reloadData()

        // Clear previous overlays + annotations (keep user location)
        mapView.removeOverlays(mapView.overlays)
        let oldAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(oldAnnotations)

        // Destination pin
        let destPin = MKPointAnnotation()
        destPin.coordinate = destination
        destPin.title = name ?? "Destination"
        mapView.addAnnotation(destPin)

        let request = MKDirections.Request()
        let srcCoord = userLocation.coordinate.latitude != 0
            ? userLocation.coordinate
            : mapView.userLocation.coordinate
        request.source      = MKMapItem(location: CLLocation(latitude: srcCoord.latitude, longitude: srcCoord.longitude), address: nil)
        request.destination = MKMapItem(location: CLLocation(latitude: destination.latitude, longitude: destination.longitude), address: nil)
        request.transportType = .automobile

        MKDirections(request: request).calculate { [weak self] response, error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.loadingView.stopAnimating()

                if let error = error {
                    self.statusLabel.text = "Couldn't calculate route: \(error.localizedDescription)"
                    self.statusLabel.isHidden = false
                    return
                }
                guard let route = response?.routes.first else {
                    self.statusLabel.text = "No driving route found."
                    self.statusLabel.isHidden = false
                    return
                }

                self.routePolyline = route.polyline
                self.mapView.addOverlay(route.polyline, level: .aboveRoads)
                self.mapView.setVisibleMapRect(
                    route.polyline.boundingMapRect,
                    edgePadding: UIEdgeInsets(top: 60, left: 40, bottom: 20, right: 40),
                    animated: true
                )
                self.findStationsAlongRoute()
            }
        }
    }

    // MARK: - Corridor Filtering

    private func findStationsAlongRoute() {
        guard let polyline = routePolyline else { return }
        let corridorMeters = corridorMiles * 1609.34
        let points = polyline.coordinates
        guard !points.isEmpty else { return }
        let totalLen = totalPolylineLength(points: points)
        guard totalLen > 0 else { return }

        var result: [TripStation] = []

        for station in StationsController.shared.stationArray {
            let coord = CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude)
            let (dist, progress) = minDistanceAndProgress(coord: coord, points: points, totalLen: totalLen)
            if dist <= corridorMeters {
                result.append(TripStation(
                    type: .gas(station),
                    milesFromStart: progress * totalLen / 1609.34,
                    milesFromRoute: dist / 1609.34
                ))
            }
        }

        for station in DumpStationsController.shared.dumpStationArray {
            let coord = CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude)
            let (dist, progress) = minDistanceAndProgress(coord: coord, points: points, totalLen: totalLen)
            if dist <= corridorMeters {
                result.append(TripStation(
                    type: .dump(station),
                    milesFromStart: progress * totalLen / 1609.34,
                    milesFromRoute: dist / 1609.34
                ))
            }
        }

        tripStations = result.sorted { $0.milesFromStart < $1.milesFromStart }

        // Add annotations for found stations
        let oldStationAnnotations = mapView.annotations.filter { $0 is TripStationAnnotation }
        mapView.removeAnnotations(oldStationAnnotations)
        for ts in tripStations {
            let ann = TripStationAnnotation(coordinate: ts.type.coordinate)
            ann.title    = ts.type.name
            ann.subtitle = String(format: "%.0f mi from route", ts.milesFromRoute)
            ann.stationType = ts.type
            mapView.addAnnotation(ann)
        }

        if tripStations.isEmpty {
            statusLabel.text = "No stations found within \(Int(corridorMiles)) miles of your route. Try a wider corridor."
            statusLabel.isHidden = false
        } else {
            statusLabel.isHidden = true
        }

        tableView.reloadData()
    }

    // MARK: - Geometry Helpers

    /// Returns (minDistanceMeters, progress 0…1 along polyline at closest point)
    private func minDistanceAndProgress(coord: CLLocationCoordinate2D,
                                        points: [CLLocationCoordinate2D],
                                        totalLen: Double) -> (Double, Double) {
        var minDist = Double.greatestFiniteMagnitude
        var bestProgress = 0.0
        var cumLen = 0.0

        for i in 0..<(points.count - 1) {
            let segLen = haversineDist(points[i], points[i + 1])
            let (d, t) = pointToSegmentDist(p: coord, a: points[i], b: points[i + 1])
            if d < minDist {
                minDist = d
                bestProgress = totalLen > 0 ? (cumLen + t * segLen) / totalLen : 0
            }
            cumLen += segLen
        }
        // Also check last point
        let lastDist = haversineDist(coord, points[points.count - 1])
        if lastDist < minDist {
            minDist = lastDist
            bestProgress = 1.0
        }
        return (minDist, bestProgress)
    }

    /// Minimum distance from point P to segment A→B; returns (distanceMeters, t∈[0,1])
    private func pointToSegmentDist(p: CLLocationCoordinate2D,
                                    a: CLLocationCoordinate2D,
                                    b: CLLocationCoordinate2D) -> (Double, Double) {
        let dx = b.longitude - a.longitude
        let dy = b.latitude  - a.latitude
        let lenSq = dx * dx + dy * dy

        if lenSq == 0 { return (haversineDist(p, a), 0) }

        let t = max(0, min(1, ((p.longitude - a.longitude) * dx + (p.latitude - a.latitude) * dy) / lenSq))
        let closest = CLLocationCoordinate2D(latitude: a.latitude + t * dy, longitude: a.longitude + t * dx)
        return (haversineDist(p, closest), t)
    }

    private func haversineDist(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    private func totalPolylineLength(points: [CLLocationCoordinate2D]) -> Double {
        (0..<(points.count - 1)).reduce(0.0) { $0 + haversineDist(points[$1], points[$1 + 1]) }
    }
}

// MARK: - MKPolyline coordinates helper

extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

// MARK: - UITextFieldDelegate

extension TripPlannerViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let text = textField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !text.isEmpty else { return true }
        textField.resignFirstResponder()
        hideCompletions()

        // If there's a top completion, use it; otherwise geocode the raw text
        if let top = completions.first {
            selectCompletion(top)
        } else {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = text
            MKLocalSearch(request: request).start { [weak self] response, _ in
                guard let self, let item = response?.mapItems.first else { return }
                DispatchQueue.main.async {
                    self.calculateRoute(to: item.placemark.coordinate, name: item.name)
                }
            }
        }
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        if !completions.isEmpty { showCompletions() }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        hideCompletions()
    }
}

// MARK: - MKLocalSearchCompleterDelegate

extension TripPlannerViewController: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        completions = Array(completer.results.prefix(6))
        if searchField.isFirstResponder {
            showCompletions()
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        completions = []
        hideCompletions()
    }
}

// MARK: - UITableViewDataSource / Delegate

extension TripPlannerViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        if tableView === completionsTable { return 1 }
        return tripStations.isEmpty ? 0 : 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView === completionsTable { return completions.count }
        return tripStations.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard tableView !== completionsTable, !tripStations.isEmpty else { return nil }
        let header = UIView()
        header.backgroundColor = primaryBg

        let label = UILabel()
        label.text = "\(tripStations.count) station\(tripStations.count == 1 ? "" : "s") within \(Int(corridorMiles)) miles of your route"
        label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = accentGold
        label.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: header.centerYAnchor)
        ])
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if tableView === completionsTable { return 0 }
        return tripStations.isEmpty ? 0 : 36
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView === completionsTable {
            let cell = tableView.dequeueReusableCell(withIdentifier: "completion", for: indexPath)
            let completion = completions[indexPath.row]
            cell.backgroundColor = UIColor(red: 18/255, green: 32/255, blue: 54/255, alpha: 1)
            cell.textLabel?.text = completion.title
            cell.textLabel?.textColor = .white
            cell.textLabel?.font = UIFont.systemFont(ofSize: 15)
            cell.detailTextLabel?.text = nil
            cell.accessoryType = .none
            let bg = UIView()
            bg.backgroundColor = accentGold.withAlphaComponent(0.15)
            cell.selectedBackgroundView = bg
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: TripStationCell.reuseId, for: indexPath) as! TripStationCell
        cell.configure(with: tripStations[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if tableView === completionsTable {
            selectCompletion(completions[indexPath.row])
            return
        }

        // Navigate to station details
        guard let storyboard = self.storyboard ?? UIStoryboard(name: "Main", bundle: nil) as UIStoryboard?,
              let detailsVC = storyboard.instantiateViewController(withIdentifier: "StationDetailsViewController") as? StationDetailsViewController
        else { return }

        detailsVC.userLocation = userLocation
        let ts = tripStations[indexPath.row]
        switch ts.type {
        case .gas(let s):  detailsVC.stationDetails     = s
        case .dump(let s): detailsVC.dumpStationDetails = s
        }
        navigationController?.pushViewController(detailsVC, animated: true)
    }
}

// MARK: - MKMapViewDelegate

extension TripPlannerViewController: MKMapViewDelegate {

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = accentGold.withAlphaComponent(0.85)
        renderer.lineWidth = 4
        return renderer
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else { return nil }

        if let trip = annotation as? TripStationAnnotation {
            let id = "tripStation"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            }
            view?.annotation = annotation
            switch trip.stationType {
            case .gas:
                view?.markerTintColor = UIColor(red: 212/255, green: 175/255, blue: 55/255, alpha: 1)
                view?.glyphImage = UIImage(systemName: "fuelpump.fill")
            case .dump:
                view?.markerTintColor = UIColor(red: 52/255, green: 120/255, blue: 246/255, alpha: 1)
                view?.glyphImage = UIImage(systemName: "drop.fill")
            case .none:
                view?.markerTintColor = .gray
            }
            view?.canShowCallout = true
            return view
        }

        // Destination pin
        let id = "destination"
        var view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
        if view == nil {
            view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
        }
        view?.annotation = annotation
        view?.markerTintColor = .systemGreen
        view?.glyphImage = UIImage(systemName: "flag.fill")
        view?.canShowCallout = true
        return view
    }
}

// MARK: - TripStationCell

class TripStationCell: UITableViewCell {
    static let reuseId = "TripStationCell"

    private let cardColor  = UIColor(red: 22/255,  green: 38/255,  blue: 62/255,  alpha: 1)
    private let accentGold = UIColor(red: 212/255, green: 175/255, blue: 55/255,  alpha: 1)
    private let mutedText  = UIColor(red: 150/255, green: 165/255, blue: 190/255, alpha: 1)

    private let card          = UIView()
    private let iconView      = UIImageView()
    private let nameLabel     = UILabel()
    private let locationLabel = UILabel()
    private let milesLabel    = UILabel()     // "42 mi from start"
    private let offsetLabel   = UILabel()    // "0.4 mi off route"
    private let chevron       = UIImageView(image: UIImage(systemName: "chevron.right"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        setupCard()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupCard() {
        card.backgroundColor = cardColor
        card.layer.cornerRadius = 14
        card.translatesAutoresizingMaskIntoConstraints = false

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = accentGold
        iconView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.numberOfLines = 1
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        locationLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        locationLabel.textColor = mutedText
        locationLabel.translatesAutoresizingMaskIntoConstraints = false

        milesLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        milesLabel.textColor = accentGold
        milesLabel.translatesAutoresizingMaskIntoConstraints = false

        offsetLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        offsetLabel.textColor = mutedText
        offsetLabel.translatesAutoresizingMaskIntoConstraints = false

        chevron.tintColor = mutedText
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [nameLabel, locationLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let tagStack = UIStackView(arrangedSubviews: [milesLabel, offsetLabel])
        tagStack.axis = .vertical
        tagStack.alignment = .trailing
        tagStack.spacing = 2
        tagStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(card)
        card.addSubview(iconView)
        card.addSubview(textStack)
        card.addSubview(tagStack)
        card.addSubview(chevron)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: tagStack.leadingAnchor, constant: -8),

            tagStack.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
            tagStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            tagStack.topAnchor.constraint(greaterThanOrEqualTo: card.topAnchor, constant: 14),
            tagStack.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -14),

            chevron.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            chevron.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            chevron.heightAnchor.constraint(equalToConstant: 12),
        ])
    }

    func configure(with trip: TripStation) {
        iconView.image = UIImage(systemName: trip.type.systemIcon)
        switch trip.type {
        case .gas:
            iconView.tintColor = accentGold
        case .dump:
            iconView.tintColor = UIColor(red: 52/255, green: 120/255, blue: 246/255, alpha: 1)
        }
        nameLabel.text     = trip.type.name
        locationLabel.text = trip.type.locationLabel

        let startMi = trip.milesFromStart
        milesLabel.text  = String(format: "%.0f mi along route", startMi)
        let offMi = trip.milesFromRoute
        offsetLabel.text = offMi < 0.1 ? "On route" : String(format: "%.1f mi off route", offMi)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.text     = nil
        locationLabel.text = nil
        milesLabel.text    = nil
        offsetLabel.text   = nil
        iconView.image     = nil
    }
}
