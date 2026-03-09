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
    var currentlySelectedRow:Int?
    
    let locationManager = CLLocationManager()
    var locationAuthStatus: CLAuthorizationStatus = .notDetermined
//    override var preferredStatusBarStyle: UIStatusBarStyle {
//        return .lightContent
//    }
//
//    override func viewDidAppear(_ animated: Bool) {
//        navigationController?.navigationBar.barStyle = .black
//    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.dumpStationTableView.rowHeight = UITableView.automaticDimension
        self.dumpStationTableView.estimatedRowHeight = 110
        
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
        
        //pull to refresh
        let attributes = [NSAttributedString.Key.foregroundColor: UIColor(red: 213/255, green: 220/255, blue: 232/255, alpha: 1)]
        refreshControl.tintColor = UIColor(red: 213/255, green: 220/255, blue: 232/255, alpha: 1)
        refreshControl.backgroundColor = UIColor(red: 120/255, green: 135/255, blue: 171/255, alpha: 1)
        refreshControl.attributedTitle = NSAttributedString(string: "Refreshing Dump Stations...", attributes: attributes)
        refreshControl.addTarget(self, action: #selector(refreshData), for: UIControl.Event.valueChanged)
        self.dumpStationTableView.addSubview(refreshControl)
        
        //DumpStationsController.shared.fetchStations()
        NotificationCenter.default.addObserver(self, selector: #selector(stationDataFetched) , name: DumpStationsController.dumpStationsDataParseComplete, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stationDataFailed) , name: DumpStationsController.dumpStationsDataParseFailed, object: nil)
    }
    
    func loadingDataAnimation() {
        // Create blur background
        let blurEffect = UIBlurEffect(style: .light)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = view.bounds
        view.addSubview(blurEffectView)
        
        // Create alert
        let alert = UIAlertController(title: nil, message: "Finding Dump Stations...", preferredStyle: .alert)
        
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
            self.dumpStationTableView.reloadData()
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
            
            self.dumpStationTableView.reloadData()
            
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

extension DumpStationViewController: CLLocationManagerDelegate {
    
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
            
            DumpStationsController.shared.fetchStations()
            
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

extension DumpStationViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 110
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        self.currentlySelectedRow = indexPath.row
        self.performSegue(withIdentifier: "stationDetailsSegue", sender: self)
    }
}

extension DumpStationViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 10
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "DumpStationViewCell", for: indexPath) as? DumpStationViewCell else {
            return UITableViewCell()
        }
        
        if indexPath.row % 2 == 0 {
            cell.backgroundColor = UIColor(red: 100/255, green: 119/255, blue: 163/255, alpha: 1)

        } else {
            cell.backgroundColor = UIColor(red: 120/255, green: 135/255, blue: 171/255, alpha: 1)
        }
        
        cell.accessoryType = .disclosureIndicator
        let dataPoint = DumpStationsController.shared.dumpStation
        
        if let stationName = dataPoint?[indexPath.row].name {
            cell.dumpStationName.text = stationName
        }
        
        if let lat = dataPoint?[indexPath.row].latitude, let long = dataPoint?[indexPath.row].longitude {
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
                    cell.dumpStationAddressLbl.text = addressString
                    let distanceFrom = (originLocation.distance(from: self.userLocation) * 0.000621371)
                    cell.dumpStationDistanceLbl.text = String(format: "%.0f", distanceFrom) + " miles from you"
                    
                }
            }
        }
        return cell
    }
}
