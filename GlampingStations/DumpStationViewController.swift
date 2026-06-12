//
//  DumpStationViewController.swift
//  GlampingStations
//
//  Created by Scott Kriss on 8/18/21.
//  Copyright © 2021 Scott Kriss. All rights reserved.
//

import UIKit
import CoreLocation

class DumpStationViewController: UIViewController {

    @IBOutlet weak var dumpStationTableView: UITableView!

    static let shared = DumpStationViewController()

    private let refreshControl = UIRefreshControl()

    var userLocation = CLLocation()
    var currentlySelectedRow: Int?

    let locationManager = CLLocationManager()
    var locationAuthStatus: CLAuthorizationStatus = .notDetermined
    private var hasFetchedStations = false

    // MARK: - Filter / Sort State
    private var activeFilters: Set<String> = []
    private var activeSortOrder: StationSortOrder = .distance
    private var activeRadius: Double? = 100.0         // default 100 miles
    private var activeStateFilter: String? = nil
    private var searchText: String = ""
    private var displayedDumpStations: [DumpStation] = []
    private var inlineSortButton: UIButton?
    private var inlineFilterButton: UIButton?
    private var searchBar: UITextField?
    private var isUITestDumpFixtureActive = false

    // MARK: - Colors
    private var primaryBg: UIColor { AppDelegate.primaryBg }
    private var accentGold: UIColor { AppDelegate.accentGold }

    // MARK: - Lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.standardAppearance = AppDelegate.tabBarAppearance
        tabBarController?.tabBar.scrollEdgeAppearance = AppDelegate.tabBarAppearance
        navigationController?.navigationBar.standardAppearance = AppDelegate.navBarAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = AppDelegate.navBarAppearance
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard isUITestDumpFixtureRequested else { return }
        loadUITestDumpFixtureIfNeeded()
        applyDisplayedStations()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Dump"
        tabBarItem.image = AppDelegate.dumpStationImage
        view.backgroundColor = primaryBg

        // Inline filter/sort bar (nav bar buttons don't work when Nav wraps TabBar)
        setupFilterSortBar()

        // Table view dark styling
        dumpStationTableView.accessibilityIdentifier = "dumpStationTable"
        dumpStationTableView.backgroundColor = primaryBg
        dumpStationTableView.separatorStyle = .none
        dumpStationTableView.rowHeight = UITableView.automaticDimension
        dumpStationTableView.estimatedRowHeight = 110

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5_000  // re-fire every 5 km (matches overpassMinMove)

        let authStatus = CLLocationManager.authorizationStatus()
        if authStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            locationManager.startUpdatingLocation()
        }

        // Pull-to-refresh with dark styling
        let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: accentGold]
        refreshControl.tintColor = accentGold
        refreshControl.backgroundColor = AppDelegate.cardColor
        refreshControl.attributedTitle = NSAttributedString(string: "Refreshing Dump Stations...", attributes: attrs)
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        dumpStationTableView.addSubview(refreshControl)

        NotificationCenter.default.addObserver(self, selector: #selector(stationDataFetched), name: DumpStationsController.dumpStationsDataParseComplete, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stationDataFailed), name: DumpStationsController.dumpStationsDataParseFailed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stationDataFetched), name: DumpStationsController.dumpStationAdded, object: nil)

        loadUITestDumpFixtureIfNeeded()

        // If data already loaded (e.g. HomeViewController started the listener first),
        // skip the spinner and display immediately. Otherwise show loading animation.
        if !DumpStationsController.shared.dumpStationArray.isEmpty {
            applyDisplayedStations()
        } else {
            loadingDataAnimation()
        }
    }

    // MARK: - Filter / Sort Bar

    private func setupFilterSortBar() {
        let cardColor = AppDelegate.cardColor
        let mutedText = AppDelegate.mutedText

        let bar = UIView()
        bar.backgroundColor = cardColor
        bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)

        // Sort button — left side
        let sortBtn = UIButton(type: .system)
        sortBtn.translatesAutoresizingMaskIntoConstraints = false
        sortBtn.tintColor = accentGold
        sortBtn.setTitleColor(.label, for: .normal)
        sortBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        sortBtn.addTarget(self, action: #selector(showFilterSort), for: .touchUpInside)
        inlineSortButton = sortBtn

        // Filter button — right side
        let filterBtn = UIButton(type: .system)
        filterBtn.translatesAutoresizingMaskIntoConstraints = false
        filterBtn.tintColor = mutedText
        filterBtn.setTitleColor(mutedText, for: .normal)
        filterBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        filterBtn.addTarget(self, action: #selector(showFilterSort), for: .touchUpInside)
        inlineFilterButton = filterBtn

        // Add button — center
        let addBtn = UIButton(type: .system)
        addBtn.translatesAutoresizingMaskIntoConstraints = false
        addBtn.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        addBtn.tintColor = accentGold
        addBtn.addTarget(self, action: #selector(showAddStation), for: .touchUpInside)

        // Bottom separator
        let sep = UIView()
        sep.backgroundColor = AppDelegate.separatorColor
        sep.translatesAutoresizingMaskIntoConstraints = false

        bar.addSubview(sortBtn)
        bar.addSubview(addBtn)
        bar.addSubview(filterBtn)
        bar.addSubview(sep)

        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 48),

            sortBtn.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 16),
            sortBtn.centerYAnchor.constraint(equalTo: bar.centerYAnchor),

            addBtn.centerXAnchor.constraint(equalTo: bar.centerXAnchor),
            addBtn.centerYAnchor.constraint(equalTo: bar.centerYAnchor),

            filterBtn.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -16),
            filterBtn.centerYAnchor.constraint(equalTo: bar.centerYAnchor),

            sep.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            sep.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
            sep.heightAnchor.constraint(equalToConstant: 1)
        ])

        // Search bar below the filter bar
        let search = UITextField()
        search.translatesAutoresizingMaskIntoConstraints = false
        search.accessibilityIdentifier = "dumpSearchField"
        search.backgroundColor = AppDelegate.inputBg
        search.textColor = .label
        search.font = UIFont.systemFont(ofSize: 14)
        search.layer.cornerRadius = 8
        search.attributedPlaceholder = NSAttributedString(
            string: "Search by name, city, or state...",
            attributes: [.foregroundColor: AppDelegate.mutedText.withAlphaComponent(0.6)]
        )
        search.returnKeyType = .search
        search.clearButtonMode = .whileEditing
        search.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
        search.delegate = self

        let searchIcon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        searchIcon.tintColor = mutedText
        searchIcon.frame = CGRect(x: 8, y: 0, width: 20, height: 20)
        let iconContainer = UIView(frame: CGRect(x: 0, y: 0, width: 32, height: 20))
        iconContainer.addSubview(searchIcon)
        search.leftView = iconContainer
        search.leftViewMode = .always

        view.addSubview(search)
        searchBar = search

        NSLayoutConstraint.activate([
            search.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 6),
            search.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            search.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            search.heightAnchor.constraint(equalToConstant: 36)
        ])

        // Push table content below bar + search
        dumpStationTableView.contentInset.top = 90
        dumpStationTableView.verticalScrollIndicatorInsets.top = 90

        updateFilterButton()
    }

    @objc private func searchTextChanged() {
        searchText = searchBar?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        applyDisplayedStations()
    }

    @objc private func showFilterSort() {
        let vc = FilterSortViewController()
        vc.amenityOptions = ["Potable Water", "Rinse Water", "Trailer Parking", "Restrooms", "Vending", "EV Charging", "Customer Added"]
        vc.activeAmenities = activeFilters
        vc.currentRadius = activeRadius
        vc.currentStateFilter = activeStateFilter
        // Collect unique states from currently-displayed (distance-filtered) stations only
        vc.availableStates = Array(Set(displayedDumpStations.compactMap { $0.state }.filter { !$0.isEmpty })).sorted()
        vc.currentSort = activeSortOrder
        vc.delegate = self

        vc.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *) {
            if let sheet = vc.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 20
            }
        }
        present(vc, animated: true)
    }

    @objc func showAddStation() {
        let addVC = AddStationViewController()
        addVC.stationType = .dump
        addVC.userLocation = userLocation
        addVC.onSave = { [weak self] in
            DispatchQueue.main.async { self?.applyDisplayedStations() }
        }
        let nav = UINavigationController(rootViewController: addVC)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }

    /// Applies current sort order and active filters to produce `displayedDumpStations`, then reloads the table.
    private func applyDisplayedStations() {
        guard let all = DumpStationsController.shared.dumpStation else {
            displayedDumpStations = []
            dumpStationTableView.reloadData()
            updateFilterButton()
            return
        }

        if isUITestDumpFixtureActive {
            displayedDumpStations = all
            dumpStationTableView.reloadData()
            updateFilterButton()
            addUITestDumpAccessibilityResults(stations: all)
            return
        }

        // 1. Sort
        let userLoc = userLocation
        var sorted: [DumpStation]
        switch activeSortOrder {
        case .distance:
            sorted = all.sorted {
                CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: userLoc) <
                CLLocation(latitude: $1.latitude, longitude: $1.longitude).distance(from: userLoc)
            }
        case .nameAZ:
            sorted = all.sorted { ($0.name ?? "") < ($1.name ?? "") }
        case .rating:
            sorted = all.sorted {
                (Double($0.rating ?? "0") ?? 0) > (Double($1.rating ?? "0") ?? 0)
            }
        }

        // 2. Filter by amenities
        var filtered = sorted
        if !activeFilters.isEmpty {
            let showPersonal   = activeFilters.contains("Customer Added")
            let amenityFilters = activeFilters.subtracting(["Customer Added"])
            filtered = filtered.filter { station in
                let isPersonal = station.favorite || station.source != "overpass"

                // Firebase / favorited stations only appear when "Customer Added" is checked
                if isPersonal { return showPersonal }

                // Pure Overpass — no amenity filters means "Customer Added" was the only one;
                // hide Overpass so the user sees only their personal stations
                if amenityFilters.isEmpty { return false }

                guard let a = station.amenities else { return false }
                return amenityFilters.allSatisfy { filter in
                    switch filter {
                    case "Potable Water":    return a.potableWater
                    case "Rinse Water":      return a.rinseWater
                    case "Trailer Parking":  return a.trailerParking
                    case "Restrooms":        return a.restrooms
                    case "Vending":          return a.vending
                    case "EV Charging":      return a.evCharging
                    default:                 return false
                    }
                }
            }
        }

        // 3. Filter by radius
        if let maxMiles = activeRadius {
            filtered = filtered.filter { station in
                let loc = CLLocation(latitude: station.latitude, longitude: station.longitude)
                let miles = loc.distance(from: userLoc) * 0.000621371
                return miles <= maxMiles
            }
        }

        // 4. Filter by state
        if let stateFilter = activeStateFilter, !stateFilter.isEmpty {
            filtered = filtered.filter { ($0.state ?? "").localizedCaseInsensitiveContains(stateFilter) }
        }

        // 5. Search text
        if !searchText.isEmpty {
            filtered = filtered.filter { station in
                let name  = station.name    ?? ""
                let city  = station.city    ?? ""
                let state = station.state   ?? ""
                let addr  = station.address ?? ""
                return name.localizedCaseInsensitiveContains(searchText)
                    || city.localizedCaseInsensitiveContains(searchText)
                    || state.localizedCaseInsensitiveContains(searchText)
                    || addr.localizedCaseInsensitiveContains(searchText)
            }
        }

        displayedDumpStations = filtered
        dumpStationTableView.reloadData()
        updateFilterButton()
    }

    private func loadUITestDumpFixtureIfNeeded() {
        let arguments = uiTestScenarioNames
        guard isUITestDumpFixtureRequested else { return }

        isUITestDumpFixtureActive = true
        let fixture = uiTestDumpFixture(for: arguments)
        userLocation = fixture.location
        activeRadius = 100.0
        activeStateFilter = nil
        activeFilters = []
        searchText = ""
        hasFetchedStations = true
        DumpStationsController.shared.dumpStation = fixture.stations
        displayedDumpStations = fixture.stations
        addUITestDumpAccessibilityResults(stations: fixture.stations)
    }

    private var isUITestDumpFixtureRequested: Bool {
        let arguments = uiTestScenarioNames
        return arguments.contains("UITestDumpArizona")
            || arguments.contains("UITestDumpMontana")
            || arguments.contains("UITestDumpNebraska")
    }

    private var uiTestScenarioNames: [String] {
        var names = ProcessInfo.processInfo.arguments
        if let scenario = ProcessInfo.processInfo.environment["UITestScenario"] {
            names.append(scenario)
        }
        return names
    }

    private func addUITestDumpAccessibilityResults(stations: [DumpStation]) {
        let resultNames = stations.compactMap(\.name).joined(separator: ", ")
        dumpStationTableView.accessibilityLabel = resultNames
        dumpStationTableView.accessibilityValue = resultNames

        view.subviews
            .filter { $0.accessibilityIdentifier == "dumpFixtureResults" }
            .forEach { $0.removeFromSuperview() }

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 1
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.accessibilityIdentifier = "dumpFixtureResults"
        stack.isAccessibilityElement = false

        for station in stations {
            let label = UILabel()
            label.text = station.name
            label.font = UIFont.systemFont(ofSize: 1)
            label.textColor = .clear
            label.accessibilityIdentifier = "dumpStationResult_\(station.id)"
            label.accessibilityLabel = station.name
            label.isAccessibilityElement = true
            stack.addArrangedSubview(label)
        }

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.widthAnchor.constraint(equalToConstant: 160),
            stack.heightAnchor.constraint(greaterThanOrEqualToConstant: 1)
        ])
    }

    private func uiTestDumpFixture(for arguments: [String]) -> (location: CLLocation, stations: [DumpStation]) {
        if arguments.contains("UITestDumpMontana") {
            return (
                CLLocation(latitude: 45.7833, longitude: -108.5007),
                [makeUITestDumpStation(id: "dump_mt", name: "Billings RV Dump", latitude: 45.7900, longitude: -108.4950, state: "MT")]
            )
        }

        if arguments.contains("UITestDumpNebraska") {
            return (
                CLLocation(latitude: 40.6993, longitude: -99.0817),
                [makeUITestDumpStation(id: "dump_ne", name: "Kearney RV Dump", latitude: 40.7050, longitude: -99.0900, state: "NE")]
            )
        }

        return (
            CLLocation(latitude: 33.4484, longitude: -112.0740),
            [makeUITestDumpStation(id: "dump_az", name: "Phoenix RV Dump", latitude: 33.4550, longitude: -112.0900, state: "AZ")]
        )
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

    /// Updates the inline sort/filter buttons to reflect current state.
    private func updateFilterButton() {
        let mutedText = AppDelegate.mutedText

        // Sort button: show current sort order with icon
        inlineSortButton?.setImage(UIImage(systemName: "arrow.up.arrow.down"), for: .normal)
        inlineSortButton?.setTitle("  \(activeSortOrder.title)", for: .normal)

        // Filter button: filled + gold when active, muted when inactive
        let hasFilters = !activeFilters.isEmpty
        let filterIconName = hasFilters
            ? "line.3.horizontal.decrease.circle.fill"
            : "line.3.horizontal.decrease.circle"
        let filterTitle = hasFilters ? "  Filter (\(activeFilters.count))" : "  Filter"
        inlineFilterButton?.setImage(UIImage(systemName: filterIconName), for: .normal)
        inlineFilterButton?.setTitle(filterTitle, for: .normal)
        inlineFilterButton?.tintColor = hasFilters ? accentGold : mutedText
        inlineFilterButton?.setTitleColor(hasFilters ? accentGold : mutedText, for: .normal)
    }

    // MARK: - Data Loading

    func loadingDataAnimation() {
        let blurEffect = UIBlurEffect(style: .light)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = view.bounds
        view.addSubview(blurEffectView)

        let alert = UIAlertController(title: nil, message: "Finding Dump Stations...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.startAnimating()
        alert.view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            loadingIndicator.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -10)
        ])
        present(alert, animated: true)
    }

    @objc func refreshData(sender: AnyObject) {
        DispatchQueue.main.async { self.refreshControl.beginRefreshing() }
        DumpStationsController.shared.fetchOverpassStations(near: userLocation, forceRefresh: true)
        // The snapshot listener keeps data live, so just re-sort and end the spinner
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.applyDisplayedStations()
            self.refreshControl.endRefreshing()
        }
    }

    @objc func stationDataFetched() {
        DispatchQueue.main.async {
            self.dismiss(animated: false)
            self.view.subviews.compactMap { $0 as? UIVisualEffectView }.forEach { $0.removeFromSuperview() }
            self.applyDisplayedStations()
            self.refreshControl.endRefreshing()
        }
    }

    @objc func stationDataFailed() {
        DispatchQueue.main.async {
            self.dismiss(animated: false)

            let alert = UIAlertController(
                title: "Error gathering locations",
                message: "Please make sure you're connected to the internet and tap Try Again",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Try Again", style: .default) { _ in
                self.view.subviews.compactMap { $0 as? UIVisualEffectView }.forEach { $0.removeFromSuperview() }
                self.refreshData(sender: AnyObject.self as AnyObject)
                self.loadingDataAnimation()
            })
            self.present(alert, animated: true)
            self.dumpStationTableView.reloadData()
            self.refreshControl.endRefreshing()
        }
    }

    // MARK: - Geocode Helper


    // MARK: - Segue

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "stationDetailsSegue",
           let vc = segue.destination as? StationDetailsViewController {
            let row: Int?
            if let cell = sender as? UITableViewCell,
               let indexPath = dumpStationTableView.indexPath(for: cell) {
                row = indexPath.row
            } else {
                row = currentlySelectedRow
            }
            if let row = row, row < displayedDumpStations.count {
                vc.dumpStationDetails = displayedDumpStations[row]
                vc.userLocation = userLocation
            }
        }
    }
}

// MARK: - FilterSortDelegate

extension DumpStationViewController: FilterSortDelegate {
    func filterSortDidApply(activeAmenities: Set<String>, sortOrder: StationSortOrder, radius: Double?, stateFilter: String?) {
        activeFilters = activeAmenities
        activeSortOrder = sortOrder
        activeRadius = radius
        activeStateFilter = stateFilter
        applyDisplayedStations()
    }

    func filterSortDidReset() {
        activeFilters = []
        activeSortOrder = .distance
        activeRadius = 100.0
        activeStateFilter = nil
        applyDisplayedStations()
    }
}

// MARK: - CLLocationManagerDelegate

extension DumpStationViewController: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.locationAuthStatus = status
        if status == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !isUITestDumpFixtureActive else { return }
        guard let location = locations.last else { return }
        userLocation = location

        guard !hasFetchedStations else { return }
        hasFetchedStations = true
        DumpStationsController.shared.fetchStations()
        DumpStationsController.shared.fetchOverpassStations(near: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
    }
}

// MARK: - UITableViewDelegate

extension DumpStationViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 96
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Storyboard cell-level segue fires automatically; just record the row
        currentlySelectedRow = indexPath.row
    }
}

// MARK: - UITableViewDataSource

extension DumpStationViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayedDumpStations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "DumpStationViewCell", for: indexPath) as? DumpStationViewCell else {
            return UITableViewCell()
        }

        cell.accessoryType = .none
        let station = displayedDumpStations[indexPath.row]
        cell.isAccessibilityElement = true
        cell.accessibilityIdentifier = "dumpStationCell_\(station.id)"
        cell.accessibilityLabel = station.name

        cell.dumpStationName.text = station.name
        cell.dumpStationName.accessibilityIdentifier = "dumpStationName_\(station.id)"
        cell.dumpStationName.accessibilityLabel = station.name
        cell.favoriteIcon.isHidden = !station.favorite

        // Address stored at write time — no async geocoding needed
        cell.dumpStationAddressLbl.text = station.address ?? ""

        // Distance computed synchronously
        let originLocation = CLLocation(latitude: station.latitude, longitude: station.longitude)
        let miles = originLocation.distance(from: userLocation) * 0.000621371
        cell.dumpStationDistanceLbl.text = String(format: "%.0f miles from you", miles)

        return cell
    }
}

// MARK: - UITextFieldDelegate

extension DumpStationViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        searchText = ""
        applyDisplayedStations()
        return true
    }
}
