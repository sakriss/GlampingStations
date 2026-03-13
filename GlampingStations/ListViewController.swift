//
//  ListViewController.swift
//  GlampingStations
//
//  Created by Scott Kriss on 7/23/18.
//  Copyright © 2018 Scott Kriss. All rights reserved.
//

import UIKit
import CoreLocation
import Firebase
//import FirebaseFirestore

class ListViewController: UIViewController {
    
    static let shared = ListViewController()
    
    private let refreshControl = UIRefreshControl()
    
    @IBOutlet weak var stationsTableView: UITableView!
    var userLocation = CLLocation()
    var currentlySelectedRow:Int?
    
    let locationManager = CLLocationManager()
    var locationAuthStatus: CLAuthorizationStatus = .notDetermined
    
    private func sortStationsByDistance() {
        guard let stations = StationsController.shared.stations else { return }
        let userLoc = self.userLocation
        StationsController.shared.stations = stations.sorted { a, b in
            let alat = a.latitude
            let along = a.longitude
            let blat = b.latitude
            let blong = b.longitude

            let aLoc = CLLocation(latitude: alat, longitude: along)
            let bLoc = CLLocation(latitude: blat, longitude: blong)
            return aLoc.distance(from: userLoc) < bLoc.distance(from: userLoc)
        }
    }
    
//    override var preferredStatusBarStyle: UIStatusBarStyle {
//        return .lightContent
//    }
//    
//    override func viewDidAppear(_ animated: Bool) {
//        navigationController?.navigationBar.barStyle = .black
//    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark ? .black : .white
            }
            appearance.largeTitleTextAttributes = [
                .foregroundColor: UIColor { traitCollection in
                    return traitCollection.userInterfaceStyle == .dark ? .white : .black
                }
            ]
            appearance.titleTextAttributes = [
                .foregroundColor: UIColor { traitCollection in
                    return traitCollection.userInterfaceStyle == .dark ? .white : .black
                }
            ]

            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
            navigationController?.navigationBar.compactAppearance = appearance
        } else {
            // Fallback for earlier versions (light mode only)
            navigationController?.navigationBar.barTintColor = .white
            navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.black]
            navigationController?.navigationBar.largeTitleTextAttributes = [.foregroundColor: UIColor.black]
        }
        
        if #available(iOS 13.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark ? .black : .white
            }

            // Normal state (unselected icons)
//            appearance.stackedLayoutAppearance.normal.iconColor = .orange.withAlphaComponent(0.5)
//            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
//                .foregroundColor: UIColor.black.withAlphaComponent(0.5)
//            ]

            // Selected state
            appearance.stackedLayoutAppearance.selected.iconColor = .orange
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor.orange
            ]

            tabBarController?.tabBar.standardAppearance = appearance
            if #available(iOS 15.0, *) {
                tabBarController?.tabBar.scrollEdgeAppearance = appearance
            }
        }
        
        self.stationsTableView.rowHeight = UITableView.automaticDimension
        self.stationsTableView.estimatedRowHeight = 110
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        //        locationManager.requestWhenInUseAuthorization()
        
        let authStatus = CLLocationManager.authorizationStatus()
        
        if authStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            locationManager.requestLocation()
        }
        
        loadingDataAnimation()
        
        // Define alternating colors for light/dark modes
        let refreshControlTextColor: UIColor
        let refreshControlTintColor: UIColor
        let refreshControlBackgroundColor: UIColor

        if #available(iOS 13.0, *) {
            // Light Mode and Dark Mode Color Logic
            refreshControlTextColor = UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 1.0, green: 0.7, blue: 0.4, alpha: 1.0) // Lighter orange
                    : UIColor(red: 0.9, green: 0.5, blue: 0.1, alpha: 1.0) // Soft orange
            }
            
            refreshControlTintColor = UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 1.0, green: 0.6, blue: 0.3, alpha: 1.0) // Vibrant orange
                    : UIColor(red: 1.0, green: 0.5, blue: 0.2, alpha: 1.0) // Bright orange
            }
            
            refreshControlBackgroundColor = UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1.0) // Darker muted orange
                    : UIColor(red: 1.0, green: 0.9, blue: 0.8, alpha: 1.0) // Light peach background
            }
        } else {
            // Fallback colors for earlier versions
            refreshControlTextColor = UIColor.orange // Soft orange text color
            refreshControlTintColor = UIColor.orange // Bright orange
            refreshControlBackgroundColor = UIColor(red: 1.0, green: 0.9, blue: 0.8, alpha: 1.0) // Light peach background
        }

        // Set up pull-to-refresh
        let attributes = [NSAttributedString.Key.foregroundColor: refreshControlTextColor]
        refreshControl.tintColor = refreshControlTintColor
        refreshControl.backgroundColor = refreshControlBackgroundColor
        refreshControl.attributedTitle = NSAttributedString(string: "Refreshing Stations...", attributes: attributes)
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        self.stationsTableView.addSubview(refreshControl)
        
        // StationsController.shared.fetchStations()
        NotificationCenter.default.addObserver(self, selector: #selector(stationDataFetched) , name: StationsController.stationsDataParseComplete, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stationDataFailed) , name: StationsController.stationsDataParseFailed, object: nil)
    }
    
    func loadingDataAnimation() {
        // Create blur background
        let blurEffect = UIBlurEffect(style: .light)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = view.bounds
        view.addSubview(blurEffectView)
        
        // Create alert
        let alert = UIAlertController(title: nil, message: "Finding Stations...", preferredStyle: .alert)
        
        // Create and configure spinner
        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.startAnimating()
        
        alert.view.addSubview(loadingIndicator)
        
        // Center spinner in alert
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            loadingIndicator.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -10)
        ])
        
        present(alert, animated: true)
    }
    
    @objc func refreshData(sender:AnyObject) {
        DispatchQueue.main.async {
            self.refreshControl.beginRefreshing()
        }
        locationManager.requestLocation()
    }
    
    
    @objc func stationDataFetched () {
        
        //now that data is parsed, we can display it
        DispatchQueue.main.async {
            
            self.dismiss(animated: false, completion: nil)
            self.view.subviews.compactMap {  $0 as? UIVisualEffectView }.forEach {
                $0.removeFromSuperview()
            }
            self.sortStationsByDistance()
            self.stationsTableView.reloadData()
            self.refreshControl.endRefreshing()
            
        }
    }
    
    @objc func stationDataFailed () {
        //now that data fetch failed, do something about it
        DispatchQueue.main.async {
            //dismiss the alert
            self.dismiss(animated: false, completion: nil)
            
            //display the alert
            let alert = UIAlertController(title: "Error gathering locations", message: "Please make sure you're connected to the internet and tap Try Again", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Try Again", style: .default, handler: { action in
                                            switch action.style{
                                            case .default:
                                                
                                                //remove the UIViews
                                                self.view.subviews.compactMap {  $0 as? UIVisualEffectView }.forEach {
                                                    $0.removeFromSuperview()
                                                }
                                                
                                                //initiate the refreshdata call and start the animation
                                                self.refreshData(sender: AnyObject.self as AnyObject)
                                                self.loadingDataAnimation()
                                                
                                                print("default")
                                                
                                            case .cancel:
                                                print("cancel")
                                                
                                            case .destructive:
                                                print("destructive")
                                                
                                                
                                            }}))
            self.present(alert, animated: true, completion: nil)
            //            self.view.subviews.compactMap {  $0 as? UIVisualEffectView }.forEach {
            //                $0.removeFromSuperview()
            //            }
            
            self.stationsTableView.reloadData()
            
            self.refreshControl.endRefreshing()
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "stationDetailsSegue", let vc = segue.destination as? StationDetailsViewController {
            if let row = currentlySelectedRow {
                vc.stationDetails = StationsController.shared.stationArray[row]
                vc.userLocation = userLocation
            }
        }
    }
}

extension ListViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.locationAuthStatus = status
        if status == .authorizedWhenInUse {
            print("We can now get your location")
            manager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        for location in locations {
            print("\(location.coordinate.latitude), \(location.coordinate.longitude)")
            userLocation = location
            
            self.sortStationsByDistance()
            self.stationsTableView.reloadData()
            
            StationsController.shared.fetchStations()
//            fetchStationsFromFirestore()
            
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { (placemarks:[CLPlacemark]?, error: Error?) in
                if let error = error {
                    print(error)
                    return
                }
                if let placemarks = placemarks {
                    for placemark in placemarks {
                        var addressString = placemark.subThoroughfare ?? ""
                        addressString.append(" ")
                        addressString.append(placemark.thoroughfare ?? "")
                        addressString.append(", ")
                        addressString.append(placemark.locality ?? "")
                        
                    }
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
    }
}

extension ListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 110
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        self.currentlySelectedRow = indexPath.row
        self.performSegue(withIdentifier: "stationDetailsSegue", sender: self)
    }
}

extension ListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return StationsController.shared.stationArray.count
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ListTableViewCell", for: indexPath) as? ListTableViewCell else {
            return UITableViewCell()
        }
        
        // Define alternating colors
        let evenRowColor: UIColor
        let oddRowColor: UIColor

        if #available(iOS 13.0, *) {
            evenRowColor = UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 0.5, green: 0.3, blue: 0.2, alpha: 1.0) // Darker muted orange
                    : UIColor(red: 1.0, green: 0.9, blue: 0.8, alpha: 1.0) // Light peach
            }
            oddRowColor = UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1.0) // Dark orange
                    : UIColor(red: 1.0, green: 0.8, blue: 0.6, alpha: 1.0) // Soft orange
            }
        } else {
            // Fallback colors for earlier versions
            evenRowColor = UIColor(red: 1.0, green: 0.9, blue: 0.8, alpha: 1.0) // Light peach
            oddRowColor = UIColor(red: 1.0, green: 0.8, blue: 0.6, alpha: 1.0) // Soft orange
        }

        // Apply alternating colors
        cell.backgroundColor = indexPath.row % 2 == 0 ? evenRowColor : oddRowColor
        
        cell.accessoryType = .disclosureIndicator
        let data = StationsController.shared.stations
        
        if let stationName = data?[indexPath.row].name {
            cell.stationNameLabel.text = stationName
        }
        
        if let lat = data?[indexPath.row].latitude, let long = data?[indexPath.row].longitude {
            let originLocation = CLLocation(latitude: lat, longitude: long)
            
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
                    cell.stationAddressLabel.text = addressString
                    let distanceFrom = (originLocation.distance(from: self.userLocation) * 0.000621371)
                    cell.stationDistanceLabel.text = String(format: "%.0f", distanceFrom) + " miles from you"
                    
                }
            }
        }
        return cell
    }
}

