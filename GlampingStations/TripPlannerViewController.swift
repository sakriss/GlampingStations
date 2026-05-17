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
}

struct TripStation {
    let type: TripStationType
    let milesFromStart: Double
    let milesFromRoute: Double
}

enum RouteWarningSeverity {
    case risk
    case unknown
    case info

    var title: String {
        switch self {
        case .risk: return "Possible Risk"
        case .unknown: return "Unknown Clearance"
        case .info: return "Advisory"
        }
    }

    var color: UIColor {
        switch self {
        case .risk: return .systemRed
        case .unknown: return .systemOrange
        case .info: return .systemBlue
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .risk: return "risk"
        case .unknown: return "unknown"
        case .info: return "info"
        }
    }
}

struct RouteWarning {
    let title: String
    let detail: String
    let coordinate: CLLocationCoordinate2D
    let severity: RouteWarningSeverity
    let source: String
    let confidence: String
    let riskType: String
    let locationDescription: String
    let listedClearanceFeet: Double?
    let vehicleHeightFeet: Double?
    let sourceReference: String
    let meaning: String
    let rawTagsSummary: String

    var stableID: String {
        "\(title)_\(coordinate.latitude.rounded(toPlaces: 5))_\(coordinate.longitude.rounded(toPlaces: 5))"
    }

    var expandedDetails: [String] {
        var details = [
            "Type: \(riskType)",
            "Location: \(locationDescription)",
            "Confidence: \(confidence)",
            "Source: \(sourceReference)"
        ]

        if let listedClearanceFeet {
            details.insert(String(format: "Listed clearance: %.1f ft", listedClearanceFeet), at: 1)
        }
        if let vehicleHeightFeet {
            details.insert(String(format: "Your height: %.1f ft", vehicleHeightFeet), at: min(2, details.count))
        }
        if !meaning.isEmpty {
            details.append("What it means: \(meaning)")
        }
        if !rawTagsSummary.isEmpty {
            details.append("Map tags: \(rawTagsSummary)")
        }

        return details
    }

    var mapCalloutDetails: String {
        var lines = [riskType, detail]
        if locationDescription.isEmpty == false {
            lines.append(locationDescription)
        }
        if meaning.isEmpty == false {
            lines.append(meaning)
        }
        return lines.joined(separator: "\n")
    }

    init(
        title: String,
        detail: String,
        coordinate: CLLocationCoordinate2D,
        severity: RouteWarningSeverity,
        source: String,
        confidence: String,
        riskType: String = "Route advisory",
        locationDescription: String = "",
        listedClearanceFeet: Double? = nil,
        vehicleHeightFeet: Double? = nil,
        sourceReference: String = "",
        meaning: String = "",
        rawTagsSummary: String = ""
    ) {
        self.title = title
        self.detail = detail
        self.coordinate = coordinate
        self.severity = severity
        self.source = source
        self.confidence = confidence
        self.riskType = riskType
        self.locationDescription = locationDescription.isEmpty
            ? String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
            : locationDescription
        self.listedClearanceFeet = listedClearanceFeet
        self.vehicleHeightFeet = vehicleHeightFeet
        self.sourceReference = sourceReference.isEmpty ? source : sourceReference
        self.meaning = meaning
        self.rawTagsSummary = rawTagsSummary
    }
}

private enum RouteRow {
    case warning(RouteWarning)
    case station(TripStation)
    case premiumLocked
}

class TripStationAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    var stationType: TripStationType?

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}

class RouteWarningAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    let severity: RouteWarningSeverity
    let warning: RouteWarning

    init(warning: RouteWarning) {
        self.coordinate = warning.coordinate
        self.title = warning.title
        self.subtitle = "\(warning.riskType) - \(warning.confidence)"
        self.severity = warning.severity
        self.warning = warning
    }
}

// MARK: - TripPlannerViewController

class TripPlannerViewController: UIViewController {

    // MARK: - Colors

    private var primaryBg: UIColor { AppDelegate.primaryBg }
    private var cardColor: UIColor { AppDelegate.cardColor }
    private var accentGold: UIColor { AppDelegate.accentGold }
    private var mutedText: UIColor { AppDelegate.mutedText }

    // MARK: - Constants

    private let heightStorageKey = "routes.vehicleHeightFeet"
    private let warningUnlockCount = 2
    private let stopUnlockCount = 4

    // MARK: - Public

    var userLocation: CLLocation = CLLocation(latitude: 0, longitude: 0)

    // MARK: - UI

    private let mapView = MKMapView()
    private let bottomSheet = UIView()
    private let handleView = UIView()
    private let searchField = UITextField()
    private let clearButton = UIButton(type: .system)
    private let heightField = UITextField()
    private let confidenceLabel = UILabel()
    private let warningChip = UILabel()
    private let routeSummaryLabel = UILabel()
    private let openMapsButton = UIButton(type: .system)
    private let reportButton = UIButton(type: .system)
    private let tableSegment = UISegmentedControl(items: ["Warnings", "Stops"])
    private let tableView = UITableView()
    private let statusLabel = UILabel()
    private let loadingView = UIActivityIndicatorView(style: .medium)

    private var completionsTable: UITableView?
    private var completionsTableHeightConstraint: NSLayoutConstraint?

    // MARK: - State

    private var routePolyline: MKPolyline?
    private var destinationCoordinate: CLLocationCoordinate2D?
    private var destinationName: String?
    private var tripStations: [TripStation] = []
    private var routeWarnings: [RouteWarning] = []
    private var rows: [RouteRow] = []
    private var expandedWarningIDs = Set<String>()
    private var searchCompleter = MKLocalSearchCompleter()
    private var completions: [MKLocalSearchCompletion] = []
    private var corridorMiles: Double = 25.0
    private var didLoadUITestFixture = false
    private var isUITestFixtureActive = false
    private var bottomSheetHeightConstraint: NSLayoutConstraint?
    private var sheetPanStartHeight: CGFloat = 0
    private var isSheetHeightConfigured = false
    private var didManuallyAdjustSheet = false
    private var didAutoPromoteSheet = false
    private let collapsedSheetRatio: CGFloat = 0.48
    private let mediumSheetRatio: CGFloat = 0.64
    private let expandedSheetRatio: CGFloat = 0.82

    private var vehicleHeightFeet: Double {
        get {
            let stored = UserDefaults.standard.double(forKey: heightStorageKey)
            return stored > 0 ? stored : 12.5
        }
        set {
            UserDefaults.standard.set(newValue, forKey: heightStorageKey)
        }
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Routes"
        view.backgroundColor = primaryBg

        if navigationController?.presentingViewController != nil && tabBarController == nil {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "xmark"),
                style: .plain,
                target: self,
                action: #selector(closeTapped)
            )
        }

        setupMap()
        setupBottomSheet()
        setupCompletionsTable()
        layoutViews()
        updateHeightField()
        updateRouteSummary()

        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .pointOfInterest, .query]

        NotificationCenter.default.addObserver(self, selector: #selector(premiumStatusChanged), name: PremiumManager.premiumStatusChanged, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.standardAppearance = AppDelegate.tabBarAppearance
        tabBarController?.tabBar.scrollEdgeAppearance = AppDelegate.tabBarAppearance
        navigationController?.navigationBar.standardAppearance = AppDelegate.navBarAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = AppDelegate.navBarAppearance
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadUITestFixtureIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard view.bounds.height > 0 else { return }
        if !isSheetHeightConfigured {
            bottomSheetHeightConstraint?.constant = heightForSheetRatio(collapsedSheetRatio)
            isSheetHeightConfigured = true
        } else if let constraint = bottomSheetHeightConstraint {
            let clampedHeight = clampedSheetHeight(constraint.constant)
            if abs(clampedHeight - constraint.constant) > 0.5 {
                constraint.constant = clampedHeight
            }
        }
    }

    // MARK: - Setup

    private func setupMap() {
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.accessibilityIdentifier = "routesMap"
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.showsScale = true

        if userLocation.coordinate.latitude != 0 {
            let region = MKCoordinateRegion(center: userLocation.coordinate, latitudinalMeters: 600_000, longitudinalMeters: 600_000)
            mapView.setRegion(region, animated: false)
        }
    }

    private func setupBottomSheet() {
        bottomSheet.translatesAutoresizingMaskIntoConstraints = false
        bottomSheet.backgroundColor = primaryBg
        bottomSheet.layer.cornerRadius = 18
        bottomSheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        bottomSheet.layer.shadowColor = UIColor.black.cgColor
        bottomSheet.layer.shadowOpacity = 0.18
        bottomSheet.layer.shadowRadius = 14
        bottomSheet.layer.shadowOffset = CGSize(width: 0, height: -4)

        handleView.translatesAutoresizingMaskIntoConstraints = false
        handleView.backgroundColor = mutedText.withAlphaComponent(0.45)
        handleView.layer.cornerRadius = 2
        handleView.isUserInteractionEnabled = true

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(bottomSheetPanned(_:)))
        panGesture.delegate = self
        bottomSheet.addGestureRecognizer(panGesture)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(bottomSheetHandleTapped))
        handleView.addGestureRecognizer(tapGesture)

        setupSearchField()
        setupHeightField()
        setupSummaryViews()
        setupTableView()
    }

    private func setupSearchField() {
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.accessibilityIdentifier = "routesDestinationField"
        searchField.placeholder = "Where are you headed?"
        searchField.textColor = .label
        searchField.backgroundColor = AppDelegate.inputBg
        searchField.layer.cornerRadius = 10
        searchField.layer.masksToBounds = true
        searchField.font = UIFont.systemFont(ofSize: 16)
        searchField.returnKeyType = .search
        searchField.delegate = self
        searchField.addTarget(self, action: #selector(searchFieldChanged), for: .editingChanged)

        let iconContainer = UIView(frame: CGRect(x: 0, y: 0, width: 36, height: 20))
        let iconView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        iconView.tintColor = mutedText
        iconView.frame = CGRect(x: 10, y: 0, width: 18, height: 18)
        iconContainer.addSubview(iconView)
        searchField.leftView = iconContainer
        searchField.leftViewMode = .always

        clearButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clearButton.tintColor = mutedText
        clearButton.frame = CGRect(x: 0, y: 0, width: 36, height: 20)
        clearButton.addTarget(self, action: #selector(clearSearch), for: .touchUpInside)
        clearButton.isHidden = true
        searchField.rightView = clearButton
        searchField.rightViewMode = .always

        searchField.attributedPlaceholder = NSAttributedString(
            string: "Where are you headed?",
            attributes: [.foregroundColor: mutedText]
        )
    }

    private func setupHeightField() {
        heightField.translatesAutoresizingMaskIntoConstraints = false
        heightField.accessibilityIdentifier = "routesHeightField"
        heightField.textColor = .label
        heightField.backgroundColor = AppDelegate.inputBg
        heightField.layer.cornerRadius = 10
        heightField.layer.masksToBounds = true
        heightField.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        heightField.keyboardType = .decimalPad
        heightField.delegate = self
        heightField.textAlignment = .center
        heightField.addTarget(self, action: #selector(heightChanged), for: .editingChanged)
    }

    private func setupSummaryViews() {
        confidenceLabel.translatesAutoresizingMaskIntoConstraints = false
        confidenceLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        confidenceLabel.textColor = mutedText
        confidenceLabel.text = "Advisory routing - US open data"
        confidenceLabel.numberOfLines = 1

        warningChip.translatesAutoresizingMaskIntoConstraints = false
        warningChip.accessibilityIdentifier = "routesWarningChip"
        warningChip.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        warningChip.textAlignment = .center
        warningChip.layer.cornerRadius = 11
        warningChip.layer.masksToBounds = true

        routeSummaryLabel.translatesAutoresizingMaskIntoConstraints = false
        routeSummaryLabel.accessibilityIdentifier = "routesSummaryLabel"
        routeSummaryLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        routeSummaryLabel.textColor = mutedText
        routeSummaryLabel.numberOfLines = 2

        openMapsButton.translatesAutoresizingMaskIntoConstraints = false
        openMapsButton.accessibilityIdentifier = "routesOpenMapsButton"
        openMapsButton.setTitle("Open in Maps", for: .normal)
        openMapsButton.setImage(UIImage(systemName: "arrow.triangle.turn.up.right.diamond.fill"), for: .normal)
        openMapsButton.tintColor = UIColor(red: 10/255, green: 25/255, blue: 47/255, alpha: 1)
        openMapsButton.backgroundColor = accentGold
        openMapsButton.layer.cornerRadius = 11
        openMapsButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        openMapsButton.isEnabled = false
        openMapsButton.alpha = 0.45
        openMapsButton.addTarget(self, action: #selector(openInMapsTapped), for: .touchUpInside)

        reportButton.translatesAutoresizingMaskIntoConstraints = false
        reportButton.accessibilityIdentifier = "routesReportIssueButton"
        reportButton.setTitle("Report Issue", for: .normal)
        reportButton.setImage(UIImage(systemName: "exclamationmark.bubble.fill"), for: .normal)
        reportButton.tintColor = accentGold
        reportButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        reportButton.isEnabled = false
        reportButton.alpha = 0.45
        reportButton.addTarget(self, action: #selector(reportIssueTapped), for: .touchUpInside)

        tableSegment.translatesAutoresizingMaskIntoConstraints = false
        tableSegment.accessibilityIdentifier = "routesDetailsSegment"
        tableSegment.selectedSegmentIndex = 0
        tableSegment.selectedSegmentTintColor = accentGold
        tableSegment.backgroundColor = AppDelegate.inputBg
        tableSegment.setTitleTextAttributes([.foregroundColor: mutedText], for: .normal)
        tableSegment.setTitleTextAttributes([.foregroundColor: UIColor(red: 10/255, green: 25/255, blue: 47/255, alpha: 1)], for: .selected)
        tableSegment.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.accessibilityIdentifier = "routesStatusLabel"
        statusLabel.text = "Preview an RV route, check known clearances, and find fuel or dump stops along the way."
        statusLabel.font = UIFont.systemFont(ofSize: 14)
        statusLabel.textColor = mutedText
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.color = accentGold
        loadingView.hidesWhenStopped = true
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.accessibilityIdentifier = "routesDetailsTable"
        tableView.backgroundColor = primaryBg
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 82
        tableView.register(RouteWarningCell.self, forCellReuseIdentifier: RouteWarningCell.reuseId)
        tableView.register(TripStationCell.self, forCellReuseIdentifier: TripStationCell.reuseId)
        tableView.register(PremiumLockedCell.self, forCellReuseIdentifier: PremiumLockedCell.reuseId)
        tableView.contentInset = UIEdgeInsets(top: 6, left: 0, bottom: 20, right: 0)
    }

    private func setupCompletionsTable() {
        let ct = UITableView()
        ct.translatesAutoresizingMaskIntoConstraints = false
        ct.backgroundColor = cardColor
        ct.layer.cornerRadius = 10
        ct.layer.borderWidth = 1
        ct.layer.borderColor = AppDelegate.separatorColor.cgColor
        ct.separatorColor = AppDelegate.separatorColor
        ct.rowHeight = 50
        ct.dataSource = self
        ct.delegate = self
        ct.isHidden = true
        ct.register(UITableViewCell.self, forCellReuseIdentifier: "completion")
        completionsTable = ct
    }

    private func layoutViews() {
        view.addSubview(mapView)
        view.addSubview(bottomSheet)

        bottomSheet.addSubview(handleView)
        bottomSheet.addSubview(searchField)
        bottomSheet.addSubview(heightField)
        bottomSheet.addSubview(confidenceLabel)
        bottomSheet.addSubview(warningChip)
        bottomSheet.addSubview(routeSummaryLabel)
        bottomSheet.addSubview(openMapsButton)
        bottomSheet.addSubview(reportButton)
        bottomSheet.addSubview(tableSegment)
        bottomSheet.addSubview(tableView)
        bottomSheet.addSubview(statusLabel)
        bottomSheet.addSubview(loadingView)

        if let ct = completionsTable {
            bottomSheet.addSubview(ct)
        }

        let safe = view.safeAreaLayoutGuide
        let sheetHeight = bottomSheet.heightAnchor.constraint(equalToConstant: 360)
        sheetHeight.priority = .required
        bottomSheetHeightConstraint = sheetHeight

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            bottomSheet.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomSheet.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomSheet.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sheetHeight,

            handleView.topAnchor.constraint(equalTo: bottomSheet.topAnchor, constant: 8),
            handleView.centerXAnchor.constraint(equalTo: bottomSheet.centerXAnchor),
            handleView.widthAnchor.constraint(equalToConstant: 42),
            handleView.heightAnchor.constraint(equalToConstant: 4),

            searchField.topAnchor.constraint(equalTo: handleView.bottomAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: bottomSheet.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: heightField.leadingAnchor, constant: -10),
            searchField.heightAnchor.constraint(equalToConstant: 44),

            heightField.trailingAnchor.constraint(equalTo: bottomSheet.trailingAnchor, constant: -16),
            heightField.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            heightField.widthAnchor.constraint(equalToConstant: 82),
            heightField.heightAnchor.constraint(equalToConstant: 44),

            confidenceLabel.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 10),
            confidenceLabel.leadingAnchor.constraint(equalTo: bottomSheet.leadingAnchor, constant: 16),
            confidenceLabel.trailingAnchor.constraint(lessThanOrEqualTo: warningChip.leadingAnchor, constant: -8),

            warningChip.centerYAnchor.constraint(equalTo: confidenceLabel.centerYAnchor),
            warningChip.trailingAnchor.constraint(equalTo: bottomSheet.trailingAnchor, constant: -16),
            warningChip.widthAnchor.constraint(greaterThanOrEqualToConstant: 86),
            warningChip.heightAnchor.constraint(equalToConstant: 22),

            routeSummaryLabel.topAnchor.constraint(equalTo: confidenceLabel.bottomAnchor, constant: 8),
            routeSummaryLabel.leadingAnchor.constraint(equalTo: bottomSheet.leadingAnchor, constant: 16),
            routeSummaryLabel.trailingAnchor.constraint(equalTo: bottomSheet.trailingAnchor, constant: -16),

            openMapsButton.topAnchor.constraint(equalTo: routeSummaryLabel.bottomAnchor, constant: 10),
            openMapsButton.leadingAnchor.constraint(equalTo: bottomSheet.leadingAnchor, constant: 16),
            openMapsButton.heightAnchor.constraint(equalToConstant: 42),

            reportButton.leadingAnchor.constraint(equalTo: openMapsButton.trailingAnchor, constant: 10),
            reportButton.trailingAnchor.constraint(equalTo: bottomSheet.trailingAnchor, constant: -16),
            reportButton.centerYAnchor.constraint(equalTo: openMapsButton.centerYAnchor),
            reportButton.widthAnchor.constraint(equalTo: openMapsButton.widthAnchor),
            reportButton.heightAnchor.constraint(equalToConstant: 42),

            tableSegment.topAnchor.constraint(equalTo: openMapsButton.bottomAnchor, constant: 12),
            tableSegment.leadingAnchor.constraint(equalTo: bottomSheet.leadingAnchor, constant: 16),
            tableSegment.trailingAnchor.constraint(equalTo: bottomSheet.trailingAnchor, constant: -16),
            tableSegment.heightAnchor.constraint(equalToConstant: 32),

            tableView.topAnchor.constraint(equalTo: tableSegment.bottomAnchor, constant: 4),
            tableView.leadingAnchor.constraint(equalTo: bottomSheet.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: bottomSheet.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: safe.bottomAnchor),

            statusLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: tableView.topAnchor, constant: 26),
            statusLabel.leadingAnchor.constraint(equalTo: bottomSheet.leadingAnchor, constant: 30),
            statusLabel.trailingAnchor.constraint(equalTo: bottomSheet.trailingAnchor, constant: -30),

            loadingView.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            loadingView.topAnchor.constraint(equalTo: tableView.topAnchor, constant: 34),
        ])

        if let ct = completionsTable {
            let h = ct.heightAnchor.constraint(equalToConstant: 0)
            h.isActive = true
            completionsTableHeightConstraint = h
            NSLayoutConstraint.activate([
                ct.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 4),
                ct.leadingAnchor.constraint(equalTo: searchField.leadingAnchor),
                ct.trailingAnchor.constraint(equalTo: searchField.trailingAnchor)
            ])
            bottomSheet.bringSubviewToFront(ct)
        }
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func premiumStatusChanged() {
        refreshRows()
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

    @objc private func heightChanged() {
        let normalized = (heightField.text ?? "").replacingOccurrences(of: " ft", with: "")
        if let value = Double(normalized), value > 0 {
            vehicleHeightFeet = value
            classifyWarnings()
        }
    }

    @objc private func segmentChanged() {
        refreshRows()
        if tableSegment.selectedSegmentIndex == 1, !didManuallyAdjustSheet {
            setBottomSheetHeight(heightForSheetRatio(mediumSheetRatio), animated: true)
        }
    }

    @objc private func bottomSheetHandleTapped() {
        didManuallyAdjustSheet = true
        let currentHeight = bottomSheetHeightConstraint?.constant ?? heightForSheetRatio(collapsedSheetRatio)
        let collapsedHeight = heightForSheetRatio(collapsedSheetRatio)
        let mediumHeight = heightForSheetRatio(mediumSheetRatio)
        let target = currentHeight < mediumHeight ? mediumHeight : collapsedHeight
        setBottomSheetHeight(target, animated: true)
    }

    @objc private func bottomSheetPanned(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            didManuallyAdjustSheet = true
            sheetPanStartHeight = bottomSheetHeightConstraint?.constant ?? heightForSheetRatio(collapsedSheetRatio)
        case .changed:
            let translation = gesture.translation(in: view)
            setBottomSheetHeight(sheetPanStartHeight - translation.y, animated: false)
        case .ended, .cancelled, .failed:
            let velocity = gesture.velocity(in: view).y
            let targetHeight = nearestSheetDetentHeight(
                from: bottomSheetHeightConstraint?.constant ?? sheetPanStartHeight,
                velocityY: velocity
            )
            setBottomSheetHeight(targetHeight, animated: true)
        default:
            break
        }
    }

    @objc private func openInMapsTapped() {
        guard let destinationCoordinate else { return }
        let location = CLLocation(latitude: destinationCoordinate.latitude, longitude: destinationCoordinate.longitude)
        let item = MKMapItem(location: location, address: nil)
        item.name = destinationName ?? "Destination"
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    @objc private func reportIssueTapped() {
        guard destinationCoordinate != nil else { return }
        let message = "Reports are sent as feedback for review. They are not treated as verified clearance data until checked."
        let alert = UIAlertController(title: "Report Route Issue", message: message, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Low bridge, bad route, closure..."
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Submit", style: .default) { [weak self] _ in
            self?.showToast("Thanks - your report was captured for review.")
        })
        present(alert, animated: true)
    }

    private func showPaywall() {
        let paywall = PaywallViewController()
        paywall.modalPresentationStyle = .formSheet
        present(paywall, animated: true)
    }

    private func showToast(_ text: String) {
        let alert = UIAlertController(title: nil, message: text, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            alert.dismiss(animated: true)
        }
    }

    private func showWarningDetails(_ warning: RouteWarning) {
        let message = ([warning.detail] + warning.expandedDetails).joined(separator: "\n\n")
        let alert = UIAlertController(title: warning.title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Bottom Sheet

    private func heightForSheetRatio(_ ratio: CGFloat) -> CGFloat {
        clampedSheetHeight(view.bounds.height * ratio)
    }

    private func clampedSheetHeight(_ proposedHeight: CGFloat) -> CGFloat {
        let availableHeight = max(view.bounds.height, 1)
        let absoluteMaxHeight = max(280, availableHeight - view.safeAreaInsets.top - 12)
        let maxHeight = min(availableHeight * expandedSheetRatio, absoluteMaxHeight)
        let minHeight = min(max(availableHeight * collapsedSheetRatio, 320), maxHeight)
        return min(max(proposedHeight, minHeight), maxHeight)
    }

    private func setBottomSheetHeight(_ height: CGFloat, animated: Bool) {
        bottomSheetHeightConstraint?.constant = clampedSheetHeight(height)
        let changes = { self.view.layoutIfNeeded() }

        if animated {
            UIView.animate(
                withDuration: 0.24,
                delay: 0,
                usingSpringWithDamping: 0.88,
                initialSpringVelocity: 0.4,
                options: [.beginFromCurrentState, .allowUserInteraction],
                animations: changes
            )
        } else {
            changes()
        }
    }

    private func nearestSheetDetentHeight(from height: CGFloat, velocityY: CGFloat) -> CGFloat {
        let collapsed = heightForSheetRatio(collapsedSheetRatio)
        let medium = heightForSheetRatio(mediumSheetRatio)
        let expanded = heightForSheetRatio(expandedSheetRatio)

        if velocityY < -650 { return expanded }
        if velocityY > 650 { return collapsed }

        return [collapsed, medium, expanded].min { abs($0 - height) < abs($1 - height) } ?? medium
    }

    private func promoteSheetForWarningsIfNeeded() {
        guard !didManuallyAdjustSheet,
              !didAutoPromoteSheet,
              tableSegment.selectedSegmentIndex == 0,
              routeWarnings.count > warningUnlockCount
        else { return }

        didAutoPromoteSheet = true
        setBottomSheetHeight(heightForSheetRatio(mediumSheetRatio), animated: true)
    }

    // MARK: - Completions

    private func showCompletions() {
        guard let ct = completionsTable else { return }
        let rowHeight: CGFloat = 50
        let maxRows: CGFloat = 4
        completionsTableHeightConstraint?.constant = min(CGFloat(completions.count) * rowHeight, maxRows * rowHeight)
        ct.isHidden = completions.isEmpty
        ct.reloadData()
        bottomSheet.bringSubviewToFront(ct)
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
            guard let self else { return }
            DispatchQueue.main.async {
                if let item = response?.mapItems.first {
                    self.calculateRoute(to: item.location.coordinate, name: item.name ?? completion.title)
                } else {
                    self.showSearchError(error)
                }
            }
        }
    }

    // MARK: - Route Calculation

    private func calculateRoute(to destination: CLLocationCoordinate2D, name: String?) {
        loadingView.startAnimating()
        statusLabel.isHidden = true
        routeWarnings = []
        expandedWarningIDs.removeAll()
        tripStations = []
        rows = []
        tableView.reloadData()

        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })

        let destPin = MKPointAnnotation()
        destPin.coordinate = destination
        destPin.title = name ?? "Destination"
        mapView.addAnnotation(destPin)

        let srcCoord = userLocation.coordinate.latitude != 0 ? userLocation.coordinate : mapView.userLocation.coordinate
        let request = MKDirections.Request()
        request.source = MKMapItem(location: CLLocation(latitude: srcCoord.latitude, longitude: srcCoord.longitude), address: nil)
        request.destination = MKMapItem(location: CLLocation(latitude: destination.latitude, longitude: destination.longitude), address: nil)
        request.transportType = .automobile

        MKDirections(request: request).calculate { [weak self] response, error in
            guard let self else { return }
            DispatchQueue.main.async {
                if let error {
                    self.loadingView.stopAnimating()
                    self.statusLabel.text = "Couldn't calculate route: \(error.localizedDescription)"
                    self.statusLabel.isHidden = false
                    self.updateRouteSummary()
                    return
                }
                guard let route = response?.routes.first else {
                    self.loadingView.stopAnimating()
                    self.statusLabel.text = "No driving route found."
                    self.statusLabel.isHidden = false
                    self.updateRouteSummary()
                    return
                }

                self.destinationCoordinate = destination
                self.destinationName = name
                self.routePolyline = route.polyline
                self.mapView.addOverlay(route.polyline, level: .aboveRoads)
                self.mapView.setVisibleMapRect(
                    route.polyline.boundingMapRect,
                    edgePadding: UIEdgeInsets(top: 80, left: 36, bottom: 300, right: 36),
                    animated: true
                )
                self.openMapsButton.isEnabled = true
                self.openMapsButton.alpha = 1
                self.reportButton.isEnabled = true
                self.reportButton.alpha = 1
                self.updateRouteSummary(route: route)
                self.findStationsAlongRoute()
                self.fetchRouteWarnings()
            }
        }
    }

    private func showSearchError(_ error: Error?) {
        statusLabel.text = error == nil ? "No destination found." : "Search failed: \(error!.localizedDescription)"
        statusLabel.isHidden = false
    }

    private func showEmptyDestinationError() {
        statusLabel.text = "Enter a destination to preview a route."
        statusLabel.isHidden = false
        UIAccessibility.post(notification: .announcement, argument: statusLabel.text)
    }

    private func updateRouteSummary(route: MKRoute? = nil) {
        if let route {
            let miles = route.distance / 1609.344
            let minutes = Int(route.expectedTravelTime / 60)
            routeSummaryLabel.text = String(format: "%.0f mi - about %dh %02dm - planning only, verify before driving", miles, minutes / 60, minutes % 60)
        } else {
            routeSummaryLabel.text = "Planning only. This app shows advisory warnings from open data, not guaranteed RV-safe navigation."
        }
        updateWarningChip()
    }

    private func updateHeightField() {
        heightField.text = String(format: "%.1f ft", vehicleHeightFeet)
    }

    // MARK: - Route Warnings

    private func fetchRouteWarnings() {
        guard let polyline = routePolyline else {
            loadingView.stopAnimating()
            return
        }
        let routePoints = polyline.coordinates
        let samples = sampledWarningCoordinates(from: routePoints, maxSamples: 24, spacingMeters: 16_000)
        Task {
            do {
                let elements = try await OverpassService.shared.fetchRouteAdvisories(near: samples, radiusMeters: 900)
                let warnings = self.makeWarnings(from: elements, route: routePoints)
                await MainActor.run {
                    self.routeWarnings = warnings
                    self.classifyWarnings()
                    self.loadingView.stopAnimating()
                }
            } catch {
                await MainActor.run {
                    let center = polyline.coordinate
                    self.routeWarnings = [
                        RouteWarning(
                            title: "Clearance check unavailable",
                            detail: "Open-data warning lookup failed. Route preview is still available.",
                            coordinate: center,
                            severity: .unknown,
                            source: "Open data",
                            confidence: "Unknown"
                        )
                    ]
                    self.loadingView.stopAnimating()
                    self.classifyWarnings()
                }
            }
        }
    }

    private func makeWarnings(from elements: [OverpassElement], route points: [CLLocationCoordinate2D]) -> [RouteWarning] {
        guard !points.isEmpty else { return [] }
        let maxDistanceMeters = 1_100.0
        var warnings: [RouteWarning] = []
        var seenElementIds = Set<Int64>()
        let totalLen = max(totalPolylineLength(points: points), 1)

        for element in elements {
            guard seenElementIds.insert(element.id).inserted else { continue }
            guard let lat = element.effectiveLat,
                  let lon = element.effectiveLon,
                  let tags = element.tags else { continue }
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let distance = minDistanceAndProgress(coord: coordinate, points: points, totalLen: totalLen).0
            guard distance <= maxDistanceMeters else { continue }

            let name = tags["name"] ?? tags["ref"] ?? "Route segment"
            let location = warningLocationDescription(tags: tags, coordinate: coordinate)
            let sourceRef = "\(element.type.capitalized) #\(element.id)"
            let rawTags = warningTagsSummary(tags)
            let heightText = tags["maxheight"] ?? tags["maxheight:physical"] ?? tags["maxheight:forward"] ?? tags["maxheight:backward"]
            if let heightText, let feet = parseHeightFeet(heightText) {
                let diff = feet - vehicleHeightFeet
                let severity: RouteWarningSeverity = diff < 0.5 ? .risk : .info
                let detail = String(format: "Listed clearance %@. Your saved RV height is %.1f ft.", heightText, vehicleHeightFeet)
                warnings.append(RouteWarning(
                    title: name,
                    detail: detail,
                    coordinate: coordinate,
                    severity: severity,
                    source: "OpenStreetMap",
                    confidence: "Known clearance",
                    riskType: "Low clearance",
                    locationDescription: location,
                    listedClearanceFeet: feet,
                    vehicleHeightFeet: vehicleHeightFeet,
                    sourceReference: sourceRef,
                    meaning: lowClearanceMeaning(listedFeet: feet, vehicleFeet: vehicleHeightFeet),
                    rawTagsSummary: rawTags
                ))
                continue
            }

            if tags["tunnel"] != nil || tags["covered"] != nil || tags["maxweight"] != nil || tags["hgv"] == "no" {
                let detail = advisoryDetail(tags: tags)
                warnings.append(RouteWarning(
                    title: name,
                    detail: detail,
                    coordinate: coordinate,
                    severity: .unknown,
                    source: "OpenStreetMap",
                    confidence: "Needs verification",
                    riskType: warningRiskType(tags: tags),
                    locationDescription: location,
                    sourceReference: sourceRef,
                    meaning: unknownWarningMeaning(tags: tags),
                    rawTagsSummary: rawTags
                ))
            }
        }

        if warnings.isEmpty {
            let center = routePolyline?.coordinate ?? points[points.count / 2]
            warnings.append(RouteWarning(
                title: "No known clearance conflicts found",
                detail: "Open data did not return a nearby low-clearance conflict. Unknown or stale data may still exist.",
                coordinate: center,
                severity: .info,
                source: "Open data",
                confidence: "Advisory"
            ))
        }

        return Array(warnings.prefix(20))
    }

    private func advisoryDetail(tags: [String: String]) -> String {
        if let maxweight = tags["maxweight"] {
            return "Weight restriction listed: \(maxweight). Verify if your route depends on this segment."
        }
        if tags["hgv"] == "no" {
            return "Truck access restriction is listed here. RV access may need manual verification."
        }
        if tags["tunnel"] != nil {
            return "Tunnel or underpass nearby without a verified clearance in open data."
        }
        if tags["covered"] != nil {
            return "Covered roadway nearby without a verified clearance in open data."
        }
        return "Bridge-related map data nearby without a verified clearance."
    }

    private func warningRiskType(tags: [String: String]) -> String {
        if tags["maxweight"] != nil { return "Weight restriction" }
        if tags["hgv"] == "no" { return "Truck/RV access restriction" }
        if tags["tunnel"] != nil { return "Tunnel or underpass" }
        if tags["covered"] != nil { return "Covered roadway" }
        if tags["bridge"] != nil { return "Bridge clearance candidate" }
        return "Route advisory"
    }

    private func lowClearanceMeaning(listedFeet: Double, vehicleFeet: Double) -> String {
        let clearanceBuffer = listedFeet - vehicleFeet
        if clearanceBuffer < 0 {
            return String(format: "The listed clearance is %.1f ft lower than your RV height. Treat this as a likely avoid/verify-before-driving risk.", abs(clearanceBuffer))
        }
        if clearanceBuffer < 0.5 {
            return String(format: "Only %.1f ft of listed clearance remains. Posted heights can vary by lane, resurfacing, signage, and data age.", clearanceBuffer)
        }
        return String(format: "The listed clearance is %.1f ft above your saved height, but this is still advisory open data.", clearanceBuffer)
    }

    private func unknownWarningMeaning(tags: [String: String]) -> String {
        if tags["maxweight"] != nil {
            return "This may matter for heavier RVs, trailers, or tow vehicles. The app does not yet know your weight, so verify posted restrictions."
        }
        if tags["hgv"] == "no" {
            return "The road is tagged as restricted for heavy goods vehicles. RV access is not always the same, so check local signs before relying on it."
        }
        if tags["tunnel"] != nil || tags["covered"] != nil {
            return "A tunnel, covered roadway, or underpass is near the route, but open data did not include a verified height."
        }
        return "This map feature may represent a bridge or access constraint, but clearance details are missing or need confirmation."
    }

    private func warningLocationDescription(tags: [String: String], coordinate: CLLocationCoordinate2D) -> String {
        if let fullAddress = tags["addr:full"], !fullAddress.isEmpty {
            return fullAddress
        }

        let streetPieces = [tags["addr:housenumber"], tags["addr:street"]]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        let localityPieces = [tags["addr:city"], tags["addr:state"]]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        let address = (streetPieces + localityPieces).joined(separator: ", ")
        if !address.isEmpty { return address }

        if let road = tags["name"] ?? tags["ref"] {
            return String(format: "%@ near %.5f, %.5f", road, coordinate.latitude, coordinate.longitude)
        }

        return String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }

    private func warningTagsSummary(_ tags: [String: String]) -> String {
        let interestingKeys = [
            "maxheight", "maxheight:physical", "maxheight:forward", "maxheight:backward",
            "maxweight", "hgv", "bridge", "tunnel", "covered", "access"
        ]
        return interestingKeys.compactMap { key in
            guard let value = tags[key], !value.isEmpty else { return nil }
            return "\(key)=\(value)"
        }.joined(separator: ", ")
    }

    private func classifyWarnings() {
        routeWarnings = routeWarnings.map { warning in
            guard warning.confidence == "Known clearance",
                  let listedFeet = warning.listedClearanceFeet ?? listedFeet(from: warning.detail) else { return warning }
            let severity: RouteWarningSeverity = listedFeet - vehicleHeightFeet < 0.5 ? .risk : .info
            let detail = String(format: "Listed clearance %.1f ft. Your saved RV height is %.1f ft.", listedFeet, vehicleHeightFeet)
            return RouteWarning(
                title: warning.title,
                detail: detail,
                coordinate: warning.coordinate,
                severity: severity,
                source: warning.source,
                confidence: warning.confidence,
                riskType: warning.riskType,
                locationDescription: warning.locationDescription,
                listedClearanceFeet: listedFeet,
                vehicleHeightFeet: vehicleHeightFeet,
                sourceReference: warning.sourceReference,
                meaning: lowClearanceMeaning(listedFeet: listedFeet, vehicleFeet: vehicleHeightFeet),
                rawTagsSummary: warning.rawTagsSummary
            )
        }
        addWarningAnnotations()
        updateWarningChip()
        refreshRows()
    }

    private func addWarningAnnotations() {
        mapView.removeAnnotations(mapView.annotations.filter { $0 is RouteWarningAnnotation })
        for warning in routeWarnings where warning.severity != .info || PremiumManager.shared.isPremium {
            mapView.addAnnotation(RouteWarningAnnotation(warning: warning))
        }
    }

    private func updateWarningChip() {
        let risks = routeWarnings.filter { $0.severity == .risk }.count
        let unknowns = routeWarnings.filter { $0.severity == .unknown }.count
        if risks > 0 {
            warningChip.text = "\(risks) risk\(risks == 1 ? "" : "s")"
            warningChip.textColor = .white
            warningChip.backgroundColor = RouteWarningSeverity.risk.color
        } else if unknowns > 0 {
            warningChip.text = "\(unknowns) unknown"
            warningChip.textColor = .white
            warningChip.backgroundColor = RouteWarningSeverity.unknown.color
        } else if routePolyline != nil {
            warningChip.text = "Advisory"
            warningChip.textColor = .white
            warningChip.backgroundColor = RouteWarningSeverity.info.color
        } else {
            warningChip.text = "Preview"
            warningChip.textColor = mutedText
            warningChip.backgroundColor = AppDelegate.inputBg
        }
    }

    private func listedFeet(from detail: String) -> Double? {
        let parts = detail.components(separatedBy: " ")
        for part in parts {
            if let value = Double(part) { return value }
        }
        return nil
    }

    // MARK: - Corridor Stops

    private func findStationsAlongRoute() {
        guard let polyline = routePolyline else { return }
        let points = polyline.coordinates
        guard !points.isEmpty else { return }
        tripStations = routeStops(
            gasStations: StationsController.shared.stationArray,
            dumpStations: DumpStationsController.shared.dumpStationArray,
            points: points
        )
        addStationAnnotations()
        refreshRows()
        if !isUITestFixtureActive {
            fetchOpenDataStopsAlongRoute(points: points)
        }
    }

    private func fetchOpenDataStopsAlongRoute(points: [CLLocationCoordinate2D]) {
        let samples = sampledWarningCoordinates(from: points, maxSamples: 10, spacingMeters: 32_000)
        Task {
            do {
                let elements = try await OverpassService.shared.fetchRouteStops(near: samples, radiusMeters: Int(corridorMiles * 1609.344))
                let overpassGas = elements.compactMap { element -> Station? in
                    guard element.tags?["amenity"] == "fuel" else { return nil }
                    return OverpassParser.toStation(element)
                }
                let overpassDump = elements.compactMap { element -> DumpStation? in
                    guard element.tags?["amenity"] == "sanitary_dump_station" else { return nil }
                    return OverpassParser.toDumpStation(element)
                }
                let merged = self.routeStops(
                    gasStations: StationsController.shared.stationArray + overpassGas,
                    dumpStations: DumpStationsController.shared.dumpStationArray + overpassDump,
                    points: points
                )
                await MainActor.run {
                    self.tripStations = self.dedupedTripStations(merged)
                    self.addStationAnnotations()
                    self.refreshRows()
                }
            } catch {
                print("Route stop open-data lookup failed: \(error)")
            }
        }
    }

    private func routeStops(gasStations: [Station], dumpStations: [DumpStation], points: [CLLocationCoordinate2D]) -> [TripStation] {
        let totalLen = totalPolylineLength(points: points)
        guard totalLen > 0 else { return [] }

        let corridorMeters = corridorMiles * 1609.344
        var result: [TripStation] = []
        let rvGasStations = gasStations.filter { station in
            if station.favorite || station.source != "overpass" { return true }
            if station.isTruckStop { return true }
            return station.amenity?.diesel == true
        }

        for station in rvGasStations {
            let coord = CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude)
            let (dist, progress) = minDistanceAndProgress(coord: coord, points: points, totalLen: totalLen)
            if dist <= corridorMeters {
                result.append(TripStation(type: .gas(station), milesFromStart: progress * totalLen / 1609.344, milesFromRoute: dist / 1609.344))
            }
        }

        for station in dumpStations {
            let coord = CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude)
            let (dist, progress) = minDistanceAndProgress(coord: coord, points: points, totalLen: totalLen)
            if dist <= corridorMeters {
                result.append(TripStation(type: .dump(station), milesFromStart: progress * totalLen / 1609.344, milesFromRoute: dist / 1609.344))
            }
        }

        return result.sorted { $0.milesFromStart < $1.milesFromStart }
    }

    private func dedupedTripStations(_ stations: [TripStation]) -> [TripStation] {
        var seen = Set<String>()
        var result: [TripStation] = []
        for station in stations {
            let coordinate = station.type.coordinate
            let latBucket = Int(coordinate.latitude * 10_000)
            let lonBucket = Int(coordinate.longitude * 10_000)
            let key = "\(station.type.name.lowercased())_\(latBucket)_\(lonBucket)"
            if seen.insert(key).inserted {
                result.append(station)
            }
        }
        return result
    }

    private func addStationAnnotations() {
        mapView.removeAnnotations(mapView.annotations.filter { $0 is TripStationAnnotation })
        let visibleStations = PremiumManager.shared.isPremium ? tripStations : Array(tripStations.prefix(stopUnlockCount))
        for ts in visibleStations {
            let ann = TripStationAnnotation(coordinate: ts.type.coordinate)
            ann.title = ts.type.name
            ann.subtitle = String(format: "%.1f mi off route", ts.milesFromRoute)
            ann.stationType = ts.type
            mapView.addAnnotation(ann)
        }
    }

    private func refreshRows() {
        if tableSegment.selectedSegmentIndex == 0 {
            if PremiumManager.shared.isPremium {
                rows = routeWarnings.map { .warning($0) }
            } else {
                rows = routeWarnings.prefix(warningUnlockCount).map { .warning($0) }
                if routeWarnings.count > warningUnlockCount { rows.append(.premiumLocked) }
            }
        } else {
            if PremiumManager.shared.isPremium {
                rows = tripStations.map { .station($0) }
            } else {
                rows = tripStations.prefix(stopUnlockCount).map { .station($0) }
                if tripStations.count > stopUnlockCount { rows.append(.premiumLocked) }
            }
        }

        let hasRoute = routePolyline != nil
        statusLabel.isHidden = hasRoute && !rows.isEmpty
        if hasRoute && rows.isEmpty {
            statusLabel.text = tableSegment.selectedSegmentIndex == 0
                ? "No warnings found in open data for this route. Unknowns may still exist."
                : "No fuel or dump stops found within \(Int(corridorMiles)) miles of this route."
            statusLabel.isHidden = false
        }
        tableView.reloadData()
        addStationAnnotations()
        promoteSheetForWarningsIfNeeded()
    }

    // MARK: - UI Test Fixtures

    private func loadUITestFixtureIfNeeded() {
        guard !didLoadUITestFixture else { return }
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("UITestRoutesWarning")
                || arguments.contains("UITestRoutesNoWarnings")
                || arguments.contains("UITestRoutesI5Stops")
                || arguments.contains("UITestRoutesI90Stops")
                || arguments.contains("UITestRoutesCoastStops")
                || arguments.contains("UITestRoutesArizonaStops")
                || arguments.contains("UITestRoutesMontanaStops")
                || arguments.contains("UITestRoutesNebraskaStops")
        else { return }
        didLoadUITestFixture = true
        isUITestFixtureActive = true

        let routePoints = uiTestRoutePoints(for: arguments)
        let polyline = MKPolyline(coordinates: routePoints, count: routePoints.count)
        routePolyline = polyline
        userLocation = CLLocation(latitude: routePoints[0].latitude, longitude: routePoints[0].longitude)
        destinationCoordinate = routePoints.last
        if arguments.contains("UITestRoutesI90Stops") {
            destinationName = "I-90 Test Destination"
        } else if arguments.contains("UITestRoutesCoastStops") {
            destinationName = "US-101 Test Destination"
        } else if arguments.contains("UITestRoutesArizonaStops") {
            destinationName = "Arizona Test Destination"
        } else if arguments.contains("UITestRoutesMontanaStops") {
            destinationName = "Montana Test Destination"
        } else if arguments.contains("UITestRoutesNebraskaStops") {
            destinationName = "Nebraska Test Destination"
        } else {
            destinationName = "I-5 Test Destination"
        }
        searchField.text = destinationName
        clearButton.isHidden = false

        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        mapView.addOverlay(polyline, level: .aboveRoads)

        let destPin = MKPointAnnotation()
        destPin.coordinate = routePoints.last!
        destPin.title = destinationName
        mapView.addAnnotation(destPin)
        mapView.setVisibleMapRect(
            polyline.boundingMapRect,
            edgePadding: UIEdgeInsets(top: 80, left: 36, bottom: 300, right: 36),
            animated: false
        )

        openMapsButton.isEnabled = true
        openMapsButton.alpha = 1
        reportButton.isEnabled = true
        reportButton.alpha = 1
        routeSummaryLabel.text = "120 mi - about 2h 05m - planning only, verify before driving"
        loadingView.stopAnimating()
        statusLabel.isHidden = true

        if arguments.contains("UITestRoutesWarning") {
            routeWarnings = [
                RouteWarning(
                    title: "Low Clearance Test Bridge",
                    detail: "Listed clearance 11.2 ft. Your saved RV height is 12.5 ft.",
                    coordinate: routePoints[1],
                    severity: .risk,
                    source: "OpenStreetMap",
                    confidence: "Known clearance",
                    riskType: "Low clearance",
                    locationDescription: "Test Bridge Rd near 45.51, -122.70",
                    listedClearanceFeet: 11.2,
                    vehicleHeightFeet: vehicleHeightFeet,
                    sourceReference: "OSM way #1001",
                    meaning: "The listed clearance is lower than your saved RV height. Verify before driving and consider another route.",
                    rawTagsSummary: "maxheight=11.2 ft, bridge=yes"
                )
            ]
        } else if arguments.contains("UITestRoutesI5Stops")
                    || arguments.contains("UITestRoutesI90Stops")
                    || arguments.contains("UITestRoutesCoastStops")
                    || arguments.contains("UITestRoutesArizonaStops")
                    || arguments.contains("UITestRoutesMontanaStops")
                    || arguments.contains("UITestRoutesNebraskaStops") {
            routeWarnings = [
                RouteWarning(
                    title: "No known clearance conflicts found",
                    detail: "Open data did not return a nearby low-clearance conflict. Unknown or stale data may still exist.",
                    coordinate: routePoints[routePoints.count / 2],
                    severity: .info,
                    source: "Open data",
                    confidence: "Advisory"
                )
            ]
            let fixtures = loadBundledStationFixtures()
            let stateFixtures = uiTestStateStationFixtures(for: arguments)
            tripStations = routeStops(gasStations: fixtures.gas + stateFixtures.gas, dumpStations: fixtures.dump + stateFixtures.dump, points: routePoints)
        } else {
            routeWarnings = [
                RouteWarning(
                    title: "No known clearance conflicts found",
                    detail: "Open data did not return a nearby low-clearance conflict. Unknown or stale data may still exist.",
                    coordinate: routePoints[1],
                    severity: .info,
                    source: "Open data",
                    confidence: "Advisory"
                )
            ]
        }

        classifyWarnings()
    }

    private func uiTestRoutePoints(for arguments: [String]) -> [CLLocationCoordinate2D] {
        if arguments.contains("UITestRoutesArizonaStops") {
            return [
                CLLocationCoordinate2D(latitude: 33.4150, longitude: -111.9800),
                CLLocationCoordinate2D(latitude: 33.4484, longitude: -112.0740),
                CLLocationCoordinate2D(latitude: 33.5400, longitude: -112.1800)
            ]
        }

        if arguments.contains("UITestRoutesMontanaStops") {
            return [
                CLLocationCoordinate2D(latitude: 45.7600, longitude: -108.5800),
                CLLocationCoordinate2D(latitude: 45.7833, longitude: -108.5007),
                CLLocationCoordinate2D(latitude: 45.8300, longitude: -108.3600)
            ]
        }

        if arguments.contains("UITestRoutesNebraskaStops") {
            return [
                CLLocationCoordinate2D(latitude: 40.7600, longitude: -99.8500),
                CLLocationCoordinate2D(latitude: 40.6993, longitude: -99.0817),
                CLLocationCoordinate2D(latitude: 40.6900, longitude: -98.9000)
            ]
        }

        if arguments.contains("UITestRoutesI90Stops") {
            return [
                CLLocationCoordinate2D(latitude: 47.4800, longitude: -121.8000),
                CLLocationCoordinate2D(latitude: 47.1642, longitude: -120.8431),
                CLLocationCoordinate2D(latitude: 47.1034, longitude: -119.6287),
                CLLocationCoordinate2D(latitude: 47.1350, longitude: -118.6750)
            ]
        }

        if arguments.contains("UITestRoutesCoastStops") {
            return [
                CLLocationCoordinate2D(latitude: 43.5300, longitude: -124.2200),
                CLLocationCoordinate2D(latitude: 43.60135, longitude: -124.17782),
                CLLocationCoordinate2D(latitude: 43.704032, longitude: -124.106538),
                CLLocationCoordinate2D(latitude: 43.7800, longitude: -124.1500)
            ]
        }

        if arguments.contains("UITestRoutesI5Stops") {
            return [
                CLLocationCoordinate2D(latitude: 45.2411, longitude: -122.8270),
                CLLocationCoordinate2D(latitude: 45.8354, longitude: -122.6845),
                CLLocationCoordinate2D(latitude: 46.8202, longitude: -122.9904),
                CLLocationCoordinate2D(latitude: 47.3385, longitude: -122.3114)
            ]
        }

        return [
            CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.2712),
            CLLocationCoordinate2D(latitude: 37.8715, longitude: -122.2730)
        ]
    }

    private func uiTestStateStationFixtures(for arguments: [String]) -> (gas: [Station], dump: [DumpStation]) {
        if arguments.contains("UITestRoutesArizonaStops") {
            return (
                gas: [
                    makeUITestGasStation(id: "az_fuel", name: "Phoenix RV Fuel", latitude: 33.4488, longitude: -112.0700, state: "AZ")
                ],
                dump: [
                    makeUITestDumpStation(id: "az_dump", name: "Phoenix RV Dump", latitude: 33.4550, longitude: -112.0900, state: "AZ")
                ]
            )
        }

        if arguments.contains("UITestRoutesMontanaStops") {
            return (
                gas: [
                    makeUITestGasStation(id: "mt_fuel", name: "Billings RV Fuel", latitude: 45.7830, longitude: -108.5050, state: "MT")
                ],
                dump: [
                    makeUITestDumpStation(id: "mt_dump", name: "Billings RV Dump", latitude: 45.7900, longitude: -108.4950, state: "MT")
                ]
            )
        }

        if arguments.contains("UITestRoutesNebraskaStops") {
            return (
                gas: [
                    makeUITestGasStation(id: "ne_fuel", name: "Kearney RV Fuel", latitude: 40.7000, longitude: -99.0800, state: "NE")
                ],
                dump: [
                    makeUITestDumpStation(id: "ne_dump", name: "Kearney RV Dump", latitude: 40.7050, longitude: -99.0900, state: "NE")
                ]
            )
        }

        return (gas: [], dump: [])
    }

    private func makeUITestGasStation(id: String, name: String, latitude: Double, longitude: Double, state: String) -> Station {
        var amenity = Amenity(shower: false, bathroom: true, trailerParking: true, defAtPump: true, repairShop: false, catScale: false)
        amenity.diesel = true
        amenity.hgvAccess = true
        let station = Station(
            id: id,
            latitude: latitude,
            longitude: longitude,
            name: name,
            rating: "Test",
            comment: "UI test fixture",
            canopyHeight: "Open",
            amenity: amenity,
            favorite: false,
            state: state,
            city: nil,
            address: nil,
            source: "overpass"
        )
        station.isTruckStop = true
        return station
    }

    private func makeUITestDumpStation(id: String, name: String, latitude: Double, longitude: Double, state: String) -> DumpStation {
        DumpStation(
            id: id,
            latitude: latitude,
            longitude: longitude,
            name: name,
            rating: "Test",
            comment: "UI test fixture",
            cost: nil,
            canopyHeight: "Open",
            amenities: DumpAmenities(potableWater: true, rinseWater: true, trailerParking: true, restrooms: true, vending: false, evCharging: false),
            favorite: false,
            state: state,
            city: nil,
            address: nil,
            source: "overpass"
        )
    }

    private func loadBundledStationFixtures() -> (gas: [Station], dump: [DumpStation]) {
        let gas = decodeBundledFixture([Station].self, resource: "stations") ?? []
        let dump = decodeBundledFixture([DumpStation].self, resource: "dumpstations") ?? []
        return (gas, dump)
    }

    private func decodeBundledFixture<T: Decodable>(_ type: T.Type, resource: String) -> T? {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Geometry Helpers

    private func minDistanceAndProgress(coord: CLLocationCoordinate2D, points: [CLLocationCoordinate2D], totalLen: Double) -> (Double, Double) {
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

        let lastDist = haversineDist(coord, points[points.count - 1])
        if lastDist < minDist {
            minDist = lastDist
            bestProgress = 1.0
        }
        return (minDist, bestProgress)
    }

    private func pointToSegmentDist(p: CLLocationCoordinate2D, a: CLLocationCoordinate2D, b: CLLocationCoordinate2D) -> (Double, Double) {
        let dx = b.longitude - a.longitude
        let dy = b.latitude - a.latitude
        let lenSq = dx * dx + dy * dy
        if lenSq == 0 { return (haversineDist(p, a), 0) }
        let t = max(0, min(1, ((p.longitude - a.longitude) * dx + (p.latitude - a.latitude) * dy) / lenSq))
        let closest = CLLocationCoordinate2D(latitude: a.latitude + t * dy, longitude: a.longitude + t * dx)
        return (haversineDist(p, closest), t)
    }

    private func haversineDist(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    private func totalPolylineLength(points: [CLLocationCoordinate2D]) -> Double {
        guard points.count > 1 else { return 0 }
        return (0..<(points.count - 1)).reduce(0.0) { $0 + haversineDist(points[$1], points[$1 + 1]) }
    }

    private func sampledWarningCoordinates(from points: [CLLocationCoordinate2D], maxSamples: Int, spacingMeters: Double) -> [CLLocationCoordinate2D] {
        guard points.count > 1 else { return points }
        let totalLen = totalPolylineLength(points: points)
        guard totalLen > 0 else { return [points[0]] }

        let targetCount = min(maxSamples, max(2, Int(ceil(totalLen / spacingMeters)) + 1))
        let interval = totalLen / Double(targetCount - 1)
        var samples: [CLLocationCoordinate2D] = [points[0]]
        var nextDistance = interval
        var walked = 0.0

        for index in 0..<(points.count - 1) {
            let start = points[index]
            let end = points[index + 1]
            let segmentLength = haversineDist(start, end)
            while walked + segmentLength >= nextDistance && samples.count < targetCount - 1 {
                let t = (nextDistance - walked) / max(segmentLength, 1)
                samples.append(CLLocationCoordinate2D(
                    latitude: start.latitude + (end.latitude - start.latitude) * t,
                    longitude: start.longitude + (end.longitude - start.longitude) * t
                ))
                nextDistance += interval
            }
            walked += segmentLength
        }

        samples.append(points[points.count - 1])
        return samples
    }

    private func boundingBox(for points: [CLLocationCoordinate2D], paddingDegrees: Double) -> OverpassBoundingBox {
        let lats = points.map { $0.latitude }
        let lons = points.map { $0.longitude }
        return OverpassBoundingBox(
            south: (lats.min() ?? 0) - paddingDegrees,
            west: (lons.min() ?? 0) - paddingDegrees,
            north: (lats.max() ?? 0) + paddingDegrees,
            east: (lons.max() ?? 0) + paddingDegrees
        )
    }

    private func parseHeightFeet(_ raw: String) -> Double? {
        let value = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if value == "default" || value == "none" { return nil }
        if value.contains("'") {
            let pieces = value.replacingOccurrences(of: "\"", with: "").components(separatedBy: "'")
            let feet = Double(pieces.first?.trimmingCharacters(in: .whitespaces) ?? "") ?? 0
            let inches = pieces.count > 1 ? (Double(pieces[1].trimmingCharacters(in: .whitespaces)) ?? 0) : 0
            return feet + inches / 12.0
        }
        let number = value.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined()
        guard let parsed = Double(number), parsed > 0 else { return nil }
        if value.contains("ft") || value.contains("feet") { return parsed }
        return parsed * 3.28084
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

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

// MARK: - UIGestureRecognizerDelegate

extension TripPlannerViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let touchPoint = touch.location(in: bottomSheet)
        if tableView.frame.contains(touchPoint) {
            let topOffset = -tableView.adjustedContentInset.top
            return tableView.contentOffset.y <= topOffset + 1
        }
        return true
    }
}

// MARK: - UITextFieldDelegate

extension TripPlannerViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === heightField {
            textField.resignFirstResponder()
            updateHeightField()
            classifyWarnings()
            return true
        }

        let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            showEmptyDestinationError()
            return true
        }
        textField.resignFirstResponder()
        hideCompletions()

        if let top = completions.first {
            selectCompletion(top)
        } else {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = text
            MKLocalSearch(request: request).start { [weak self] response, error in
                guard let self else { return }
                DispatchQueue.main.async {
                    if let item = response?.mapItems.first {
                        self.calculateRoute(to: item.location.coordinate, name: item.name ?? text)
                    } else {
                        self.showSearchError(error)
                    }
                }
            }
        }
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField === searchField, !completions.isEmpty { showCompletions() }
        if textField === heightField {
            textField.text = String(format: "%.1f", vehicleHeightFeet)
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField === searchField { hideCompletions() }
        if textField === heightField { updateHeightField() }
    }
}

// MARK: - MKLocalSearchCompleterDelegate

extension TripPlannerViewController: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        completions = Array(completer.results.prefix(6))
        if searchField.isFirstResponder { showCompletions() }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        completions = []
        hideCompletions()
    }
}

// MARK: - UITableViewDataSource / Delegate

extension TripPlannerViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView === completionsTable { return completions.count }
        return rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView === completionsTable {
            let cell = tableView.dequeueReusableCell(withIdentifier: "completion", for: indexPath)
            let completion = completions[indexPath.row]
            cell.backgroundColor = cardColor
            cell.textLabel?.text = completion.title
            cell.textLabel?.textColor = .label
            cell.textLabel?.font = UIFont.systemFont(ofSize: 15)
            cell.selectedBackgroundView = UIView()
            cell.selectedBackgroundView?.backgroundColor = accentGold.withAlphaComponent(0.16)
            return cell
        }

        switch rows[indexPath.row] {
        case .warning(let warning):
            let cell = tableView.dequeueReusableCell(withIdentifier: RouteWarningCell.reuseId, for: indexPath) as! RouteWarningCell
            cell.configure(with: warning, expanded: expandedWarningIDs.contains(warning.stableID))
            return cell
        case .station(let station):
            let cell = tableView.dequeueReusableCell(withIdentifier: TripStationCell.reuseId, for: indexPath) as! TripStationCell
            cell.configure(with: station)
            return cell
        case .premiumLocked:
            let cell = tableView.dequeueReusableCell(withIdentifier: PremiumLockedCell.reuseId, for: indexPath) as! PremiumLockedCell
            cell.configure(kind: tableSegment.selectedSegmentIndex == 0 ? "warnings" : "route stops")
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if tableView === completionsTable {
            selectCompletion(completions[indexPath.row])
            return
        }

        switch rows[indexPath.row] {
        case .premiumLocked:
            showPaywall()
        case .warning(let warning):
            if expandedWarningIDs.contains(warning.stableID) {
                expandedWarningIDs.remove(warning.stableID)
            } else {
                expandedWarningIDs.insert(warning.stableID)
            }
            tableView.reloadRows(at: [indexPath], with: .automatic)
            mapView.setCenter(warning.coordinate, animated: true)
        case .station(let trip):
            guard let storyboard = self.storyboard ?? UIStoryboard(name: "Main", bundle: nil) as UIStoryboard?,
                  let detailsVC = storyboard.instantiateViewController(withIdentifier: "StationDetailsViewController") as? StationDetailsViewController
            else { return }
            detailsVC.userLocation = userLocation
            switch trip.type {
            case .gas(let s): detailsVC.stationDetails = s
            case .dump(let s): detailsVC.dumpStationDetails = s
            }
            navigationController?.pushViewController(detailsVC, animated: true)
        }
    }
}

// MARK: - MKMapViewDelegate

extension TripPlannerViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = accentGold.withAlphaComponent(0.88)
        renderer.lineWidth = 4
        return renderer
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else { return nil }

        if let warning = annotation as? RouteWarningAnnotation {
            let id = "routeWarning"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
            if view == nil { view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id) }
            view?.annotation = annotation
            view?.accessibilityIdentifier = "routeWarningMarker_\(warning.severity.accessibilityIdentifier)"
            view?.accessibilityLabel = warning.title
            view?.accessibilityValue = warning.subtitle
            view?.markerTintColor = warning.severity.color
            view?.glyphImage = UIImage(systemName: warning.severity == .risk ? "exclamationmark.triangle.fill" : "questionmark.diamond.fill")
            view?.canShowCallout = true
            let detailLabel = UILabel()
            detailLabel.font = UIFont.systemFont(ofSize: 12)
            detailLabel.textColor = .label
            detailLabel.numberOfLines = 0
            detailLabel.text = warning.warning.mapCalloutDetails
            detailLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 260).isActive = true
            view?.detailCalloutAccessoryView = detailLabel
            view?.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            return view
        }

        if let trip = annotation as? TripStationAnnotation {
            let id = "tripStation"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
            if view == nil { view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id) }
            view?.annotation = annotation
            switch trip.stationType {
            case .gas:
                view?.markerTintColor = accentGold
                view?.glyphImage = UIImage(systemName: "fuelpump.fill")
            case .dump:
                view?.markerTintColor = UIColor(red: 139/255, green: 90/255, blue: 43/255, alpha: 1)
                view?.glyphImage = UIImage(systemName: "drop.fill")
            case .none:
                view?.markerTintColor = .gray
            }
            view?.canShowCallout = true
            return view
        }

        let id = "destination"
        var view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
        if view == nil { view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id) }
        view?.annotation = annotation
        view?.markerTintColor = .systemGreen
        view?.glyphImage = UIImage(systemName: "flag.fill")
        view?.canShowCallout = true
        return view
    }

    func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
        guard let warningAnnotation = annotation as? RouteWarningAnnotation else { return }
        tableSegment.selectedSegmentIndex = 0
        expandedWarningIDs.insert(warningAnnotation.warning.stableID)
        refreshRows()
    }

    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if let warningAnnotation = view.annotation as? RouteWarningAnnotation {
            showWarningDetails(warningAnnotation.warning)
        }
    }
}

// MARK: - Cells

class RouteWarningCell: UITableViewCell {
    static let reuseId = "RouteWarningCell"

    private let card = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let sourceLabel = UILabel()
    private let expandedDetailsLabel = UILabel()
    private let expandHintLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        card.backgroundColor = AppDelegate.cardColor
        card.layer.cornerRadius = 12
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = UIFont.systemFont(ofSize: 12)
        detailLabel.textColor = AppDelegate.mutedText
        detailLabel.numberOfLines = 0

        sourceLabel.translatesAutoresizingMaskIntoConstraints = false
        sourceLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        sourceLabel.textColor = AppDelegate.accentGold

        expandedDetailsLabel.translatesAutoresizingMaskIntoConstraints = false
        expandedDetailsLabel.font = UIFont.systemFont(ofSize: 12)
        expandedDetailsLabel.textColor = AppDelegate.mutedText
        expandedDetailsLabel.numberOfLines = 0

        expandHintLabel.translatesAutoresizingMaskIntoConstraints = false
        expandHintLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        expandHintLabel.textColor = AppDelegate.mutedText

        let stack = UIStackView(arrangedSubviews: [titleLabel, detailLabel, sourceLabel, expandedDetailsLabel, expandHintLabel])
        stack.axis = .vertical
        stack.spacing = 3
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconView)
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            stack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])
    }

    func configure(with warning: RouteWarning, expanded: Bool) {
        iconView.tintColor = warning.severity.color
        iconView.image = UIImage(systemName: warning.severity == .risk ? "exclamationmark.triangle.fill" : warning.severity == .unknown ? "questionmark.diamond.fill" : "checkmark.shield.fill")
        titleLabel.text = warning.title
        detailLabel.text = warning.detail
        sourceLabel.text = "\(warning.severity.title) - \(warning.riskType) - \(warning.confidence)"
        expandedDetailsLabel.text = expanded ? warning.expandedDetails.joined(separator: "\n") : nil
        expandedDetailsLabel.isHidden = !expanded
        expandHintLabel.text = expanded ? "Tap to collapse" : "Tap for details"
        accessibilityIdentifier = "routeWarningCell_\(warning.severity.accessibilityIdentifier)"
        accessibilityLabel = "\(warning.title). \(warning.detail). \(warning.riskType). \(expanded ? warning.expandedDetails.joined(separator: ". ") : "Tap for details.")"
    }
}

class TripStationCell: UITableViewCell {
    static let reuseId = "TripStationCell"

    private let card = UIView()
    private let iconView = UIImageView()
    private let nameLabel = UILabel()
    private let locationLabel = UILabel()
    private let milesLabel = UILabel()
    private let offsetLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        setupCard()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupCard() {
        card.backgroundColor = AppDelegate.cardColor
        card.layer.cornerRadius = 12
        card.translatesAutoresizingMaskIntoConstraints = false

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = AppDelegate.accentGold
        iconView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        nameLabel.textColor = .label
        nameLabel.numberOfLines = 1
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        locationLabel.font = UIFont.systemFont(ofSize: 12)
        locationLabel.textColor = AppDelegate.mutedText
        locationLabel.translatesAutoresizingMaskIntoConstraints = false

        milesLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        milesLabel.textColor = AppDelegate.accentGold
        milesLabel.translatesAutoresizingMaskIntoConstraints = false

        offsetLabel.font = UIFont.systemFont(ofSize: 11)
        offsetLabel.textColor = AppDelegate.mutedText
        offsetLabel.translatesAutoresizingMaskIntoConstraints = false

        chevron.tintColor = AppDelegate.mutedText
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
            chevron.heightAnchor.constraint(equalToConstant: 12)
        ])
    }

    func configure(with trip: TripStation) {
        iconView.image = UIImage(systemName: trip.type.systemIcon)
        iconView.tintColor = trip.type.systemIcon == "fuelpump.fill" ? AppDelegate.accentGold : UIColor(red: 139/255, green: 90/255, blue: 43/255, alpha: 1)
        nameLabel.text = trip.type.name
        locationLabel.text = trip.type.locationLabel
        milesLabel.text = String(format: "%.0f mi along route", trip.milesFromStart)
        offsetLabel.text = trip.milesFromRoute < 0.1 ? "On route" : String(format: "%.1f mi off route", trip.milesFromRoute)
    }
}

class PremiumLockedCell: UITableViewCell {
    static let reuseId = "PremiumLockedCell"

    private let card = UIView()
    private let label = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        card.backgroundColor = AppDelegate.accentGold.withAlphaComponent(0.12)
        card.layer.cornerRadius = 12
        card.layer.borderWidth = 1
        card.layer.borderColor = AppDelegate.accentGold.withAlphaComponent(0.3).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        label.textColor = AppDelegate.accentGold
        label.textAlignment = .center
        card.addSubview(label)
        contentView.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(kind: String) {
        label.text = "Unlock Premium to see all \(kind)"
    }
}
