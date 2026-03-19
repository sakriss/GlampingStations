//
//  AddStationViewController.swift
//  GlampingStations
//
//  Created by Scott Kriss on 3/18/26.
//  Copyright © 2026 Scott Kriss. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

// MARK: - Station Type

enum StationType { case gas, dump }

// MARK: - AddStationViewController

class AddStationViewController: UIViewController {

    // MARK: - Public API

    var stationType: StationType = .gas
    var userLocation: CLLocation?
    var onSave: (() -> Void)?

    // MARK: - Colors

    private let primaryBg  = UIColor(red: 10/255,  green: 25/255,  blue: 47/255,  alpha: 1)
    private let cardColor  = UIColor(red: 22/255,  green: 38/255,  blue: 62/255,  alpha: 1)
    private let accentGold = UIColor(red: 212/255, green: 175/255, blue: 55/255,  alpha: 1)
    private let mutedText  = UIColor(red: 150/255, green: 165/255, blue: 190/255, alpha: 1)

    // MARK: - State

    private var selectedLocation: CLLocation?
    private var mapAnnotation: MKPointAnnotation?

    // MARK: - Views

    private let scrollView = UIScrollView()
    private let stackView  = UIStackView()

    // Location card
    private let mapView = MKMapView()
    private let noLocationLabel = UILabel()

    // Details card
    private let nameField    = UITextField()
    private let ratingField  = UITextField()
    private let commentView  = UITextView()
    private let commentPlaceholder = UILabel()

    // Type-specific card
    private let typeSpecificField = UITextField()

    // Amenity toggles — indexed to match amenity name arrays
    private var amenitySwitches: [UISwitch] = []

    // MARK: - Amenity Names

    private var amenityNames: [String] {
        switch stationType {
        case .gas:  return ["Shower", "Bathroom", "Trailer Parking", "DEF at Pump", "Repair Shop", "CAT Scale"]
        case .dump: return ["Potable Water", "Rinse Water", "Trailer Parking", "Restrooms", "Vending", "EV Charging"]
        }
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = primaryBg

        setupNavigationBar()
        setupScrollView()
        buildForm()
        setupKeyboardDismiss()
    }

    // MARK: - Navigation Bar

    private func setupNavigationBar() {
        title = stationType == .gas ? "Add Gas Station" : "Add Dump Station"

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = primaryBg
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = accentGold

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )

        let saveBtn = UIBarButtonItem(
            title: "Save",
            style: .done,
            target: self,
            action: #selector(saveTapped)
        )
        saveBtn.tintColor = accentGold
        navigationItem.rightBarButtonItem = saveBtn
    }

    // MARK: - Scroll View Setup

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -32),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
    }

    // MARK: - Form Building

    private func buildForm() {
        // Required fields legend
        let legendLabel = UILabel()
        legendLabel.translatesAutoresizingMaskIntoConstraints = false
        let legend = NSMutableAttributedString(
            string: "* ",
            attributes: [.foregroundColor: accentGold, .font: UIFont.systemFont(ofSize: 13, weight: .semibold)]
        )
        legend.append(NSAttributedString(
            string: "Required field",
            attributes: [.foregroundColor: mutedText, .font: UIFont.systemFont(ofSize: 13, weight: .regular)]
        ))
        legendLabel.attributedText = legend
        stackView.addArrangedSubview(legendLabel)

        stackView.addArrangedSubview(buildLocationCard())
        stackView.addArrangedSubview(buildDetailsCard())
        stackView.addArrangedSubview(buildTypeSpecificCard())
        stackView.addArrangedSubview(buildAmenitiesCard())
    }

    // MARK: Location Card

    private func buildLocationCard() -> UIView {
        let card = makeCard()
        let inner = UIStackView()
        inner.axis = .vertical
        inner.spacing = 10
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)

        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        // Title
        let titleLabel = makeRequiredLabel("Location")

        // "Use My Location" button
        let useLocationBtn = UIButton(type: .system)
        useLocationBtn.setTitle("Use My Location", for: .normal)
        useLocationBtn.tintColor = accentGold
        useLocationBtn.setTitleColor(accentGold, for: .normal)
        useLocationBtn.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        useLocationBtn.addTarget(self, action: #selector(useMyLocationTapped), for: .touchUpInside)

        // Map view
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.layer.cornerRadius = 12
        mapView.clipsToBounds = true
        mapView.isUserInteractionEnabled = true
        mapView.isZoomEnabled     = true
        mapView.isScrollEnabled   = true
        mapView.isRotateEnabled   = true
        mapView.isPitchEnabled    = true
        mapView.showsUserLocation = true
        mapView.showsCompass      = true
        mapView.heightAnchor.constraint(equalToConstant: 250).isActive = true

        // Center on user location if available
        if let loc = userLocation {
            let region = MKCoordinateRegion(center: loc.coordinate, latitudinalMeters: 5000, longitudinalMeters: 5000)
            mapView.setRegion(region, animated: false)
        }

        // Long-press to drop pin (doesn't conflict with pinch/pan/double-tap zoom)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(mapLongPressed(_:)))
        longPress.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPress)

        // +/- zoom buttons
        let zoomStack = UIStackView()
        zoomStack.axis = .vertical
        zoomStack.spacing = 2
        zoomStack.translatesAutoresizingMaskIntoConstraints = false

        let zoomIn = makeZoomButton(systemName: "plus", action: #selector(zoomInTapped))
        let zoomOut = makeZoomButton(systemName: "minus", action: #selector(zoomOutTapped))
        zoomStack.addArrangedSubview(zoomIn)
        zoomStack.addArrangedSubview(zoomOut)
        mapView.addSubview(zoomStack)

        NSLayoutConstraint.activate([
            zoomStack.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -10),
            zoomStack.bottomAnchor.constraint(equalTo: mapView.bottomAnchor, constant: -10)
        ])

        // No-location overlay label
        noLocationLabel.text = "Long press on map to drop a pin"
        noLocationLabel.textColor = mutedText
        noLocationLabel.font = UIFont.systemFont(ofSize: 13)
        noLocationLabel.numberOfLines = 0
        noLocationLabel.textAlignment = .center
        noLocationLabel.translatesAutoresizingMaskIntoConstraints = false
        mapView.addSubview(noLocationLabel)
        NSLayoutConstraint.activate([
            noLocationLabel.centerXAnchor.constraint(equalTo: mapView.centerXAnchor),
            noLocationLabel.centerYAnchor.constraint(equalTo: mapView.centerYAnchor),
            noLocationLabel.leadingAnchor.constraint(equalTo: mapView.leadingAnchor, constant: 8),
            noLocationLabel.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -8)
        ])

        // Hint label
        let hintLabel = makeLabel("Long press on map to drop a pin", size: 12, weight: .regular, color: mutedText)

        inner.addArrangedSubview(titleLabel)
        inner.addArrangedSubview(useLocationBtn)
        inner.addArrangedSubview(mapView)
        inner.addArrangedSubview(hintLabel)

        return card
    }

    // MARK: Details Card

    private func buildDetailsCard() -> UIView {
        let card = makeCard()
        let inner = UIStackView()
        inner.axis = .vertical
        inner.spacing = 10
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)

        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        let titleLabel = makeLabel("Details", size: 16, weight: .semibold, color: .white)

        styleTextField(nameField, placeholder: "Station name *", required: true)
        nameField.returnKeyType = .next
        nameField.delegate = self

        styleTextField(ratingField, placeholder: "Rating (e.g. 4.5)")
        ratingField.keyboardType = .decimalPad

        // Comment text view
        commentView.translatesAutoresizingMaskIntoConstraints = false
        commentView.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        commentView.textColor = .white
        commentView.font = UIFont.systemFont(ofSize: 15)
        commentView.layer.cornerRadius = 8
        commentView.layer.borderWidth = 1
        commentView.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        commentView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        commentView.heightAnchor.constraint(equalToConstant: 80).isActive = true
        commentView.delegate = self

        // Placeholder for text view
        commentPlaceholder.text = "Notes..."
        commentPlaceholder.font = UIFont.systemFont(ofSize: 15)
        commentPlaceholder.textColor = UIColor.white.withAlphaComponent(0.3)
        commentPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        commentView.addSubview(commentPlaceholder)
        NSLayoutConstraint.activate([
            commentPlaceholder.topAnchor.constraint(equalTo: commentView.topAnchor, constant: 10),
            commentPlaceholder.leadingAnchor.constraint(equalTo: commentView.leadingAnchor, constant: 12)
        ])

        inner.addArrangedSubview(titleLabel)
        inner.addArrangedSubview(nameField)
        inner.addArrangedSubview(ratingField)
        inner.addArrangedSubview(commentView)

        return card
    }

    // MARK: Type-Specific Card

    private func buildTypeSpecificCard() -> UIView {
        let card = makeCard()
        let inner = UIStackView()
        inner.axis = .vertical
        inner.spacing = 10
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)

        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        let titleLabel = makeLabel("Additional Info", size: 16, weight: .semibold, color: .white)

        let placeholder: String
        switch stationType {
        case .gas:  placeholder = "Canopy height (optional)"
        case .dump: placeholder = "Cost (e.g. Free, $5)"
        }
        styleTextField(typeSpecificField, placeholder: placeholder)

        inner.addArrangedSubview(titleLabel)
        inner.addArrangedSubview(typeSpecificField)

        return card
    }

    // MARK: Amenities Card

    private func buildAmenitiesCard() -> UIView {
        let card = makeCard()
        let inner = UIStackView()
        inner.axis = .vertical
        inner.spacing = 10
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)

        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        let titleLabel = makeLabel("Amenities", size: 16, weight: .semibold, color: .white)
        inner.addArrangedSubview(titleLabel)

        amenitySwitches = []

        for name in amenityNames {
            let row = UIView()
            row.translatesAutoresizingMaskIntoConstraints = false

            let label = makeLabel(name, size: 15, weight: .regular, color: .white)
            label.translatesAutoresizingMaskIntoConstraints = false

            let toggle = UISwitch()
            toggle.translatesAutoresizingMaskIntoConstraints = false
            toggle.onTintColor = accentGold
            toggle.tintColor = accentGold
            toggle.isOn = false

            row.addSubview(label)
            row.addSubview(toggle)

            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                toggle.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                toggle.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                toggle.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 8),
                row.heightAnchor.constraint(equalToConstant: 36)
            ])

            amenitySwitches.append(toggle)
            inner.addArrangedSubview(row)
        }

        return card
    }

    // MARK: - Card / Field Helpers

    private func makeCard() -> UIView {
        let view = UIView()
        view.backgroundColor = cardColor
        view.layer.cornerRadius = 14
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    private func makeLabel(_ text: String, size: CGFloat, weight: UIFont.Weight, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func styleTextField(_ field: UITextField, placeholder: String, required: Bool = false) {
        field.translatesAutoresizingMaskIntoConstraints = false
        field.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        field.textColor = .white
        field.font = UIFont.systemFont(ofSize: 15)
        field.layer.cornerRadius = 8
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        field.leftViewMode = .always
        field.heightAnchor.constraint(equalToConstant: 44).isActive = true

        if required, placeholder.hasSuffix(" *") {
            let base = String(placeholder.dropLast(2))
            let attr = NSMutableAttributedString(
                string: base,
                attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.3), .font: UIFont.systemFont(ofSize: 15)]
            )
            attr.append(NSAttributedString(
                string: " *",
                attributes: [.foregroundColor: accentGold.withAlphaComponent(0.7), .font: UIFont.systemFont(ofSize: 15, weight: .semibold)]
            ))
            field.attributedPlaceholder = attr
        } else {
            field.attributedPlaceholder = NSAttributedString(
                string: placeholder,
                attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.3)]
            )
        }
    }

    private func makeRequiredLabel(_ text: String) -> UILabel {
        let label = UILabel()
        let attr = NSMutableAttributedString(
            string: text,
            attributes: [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 16, weight: .semibold)]
        )
        attr.append(NSAttributedString(
            string: " *",
            attributes: [.foregroundColor: accentGold, .font: UIFont.systemFont(ofSize: 16, weight: .semibold)]
        ))
        label.attributedText = attr
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    // MARK: - Keyboard Dismiss

    private func setupKeyboardDismiss() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Map Helpers

    private func updateMapPin(coordinate: CLLocationCoordinate2D) {
        if let existing = mapAnnotation {
            mapView.removeAnnotation(existing)
        }
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        mapAnnotation = annotation
        mapView.addAnnotation(annotation)

        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )
        mapView.setRegion(region, animated: true)
        noLocationLabel.isHidden = true
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func useMyLocationTapped() {
        guard let loc = userLocation else {
            showAlert(message: "Your location is not available yet. Please try again in a moment.")
            return
        }
        selectedLocation = loc
        updateMapPin(coordinate: loc.coordinate)
    }

    @objc private func mapLongPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        selectedLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        updateMapPin(coordinate: coordinate)
    }

    // MARK: - Zoom Button Helpers

    private func makeZoomButton(systemName: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setImage(UIImage(systemName: systemName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        btn.layer.cornerRadius = 8
        btn.addTarget(self, action: action, for: .touchUpInside)
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalToConstant: 40),
            btn.heightAnchor.constraint(equalToConstant: 40)
        ])
        return btn
    }

    @objc private func zoomInTapped() {
        var region = mapView.region
        region.span.latitudeDelta = max(region.span.latitudeDelta / 2.0, 0.002)
        region.span.longitudeDelta = max(region.span.longitudeDelta / 2.0, 0.002)
        mapView.setRegion(region, animated: true)
    }

    @objc private func zoomOutTapped() {
        var region = mapView.region
        region.span.latitudeDelta = min(region.span.latitudeDelta * 2.0, 180)
        region.span.longitudeDelta = min(region.span.longitudeDelta * 2.0, 360)
        mapView.setRegion(region, animated: true)
    }

    @objc private func saveTapped() {
        view.endEditing(true)

        let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var missing: [String] = []
        if selectedLocation == nil { missing.append("location (long press the map or tap Use My Location)") }
        if name.isEmpty { missing.append("station name") }

        guard missing.isEmpty else {
            // Flash red border on empty name field
            if name.isEmpty { flashFieldError(nameField) }
            showAlert(message: "Please provide the following:\n• " + missing.joined(separator: "\n• "))
            return
        }
        saveStation()
    }

    private func flashFieldError(_ field: UITextField) {
        let originalColor = field.layer.borderColor
        field.layer.borderColor = UIColor.systemRed.cgColor
        field.layer.borderWidth = 2
        UIView.animate(withDuration: 0.3, delay: 1.5, options: [], animations: {
            field.layer.borderColor = originalColor
            field.layer.borderWidth = 1
        })
    }

    // MARK: - Save Logic

    private func saveStation() {
        guard let location = selectedLocation else { return }

        // Disable save button to prevent double-tap
        navigationItem.rightBarButtonItem?.isEnabled = false

        // Reverse-geocode once to get address/city/state, then write to Firestore
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }

            let placemark = placemarks?.first
            let stateStr  = placemark?.administrativeArea
            let cityStr   = placemark?.locality

            // Build a readable address: "123 Main St, Seattle, WA"
            var addrParts = [String]()
            if let sub = placemark?.subThoroughfare, let street = placemark?.thoroughfare {
                addrParts.append("\(sub) \(street)")
            } else if let street = placemark?.thoroughfare {
                addrParts.append(street)
            }
            if let city = cityStr { addrParts.append(city) }
            if let state = stateStr { addrParts.append(state) }
            let addressStr = addrParts.isEmpty ? nil : addrParts.joined(separator: ", ")

            DispatchQueue.main.async {
                self.commitSave(location: location, state: stateStr, city: cityStr, address: addressStr)
            }
        }
    }

    private func commitSave(location: CLLocation, state: String?, city: String?, address: String?) {
        let name    = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rating  = ratingField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let comment = commentView.text ?? ""
        let extra   = typeSpecificField.text?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch stationType {
        case .gas:
            let amenity = Amenity(
                shower:         amenitySwitch(at: 0),
                bathroom:       amenitySwitch(at: 1),
                trailerParking: amenitySwitch(at: 2),
                defAtPump:      amenitySwitch(at: 3),
                repairShop:     amenitySwitch(at: 4),
                catScale:       amenitySwitch(at: 5)
            )
            let station = Station(
                id:           UUID().uuidString,
                latitude:     location.coordinate.latitude,
                longitude:    location.coordinate.longitude,
                name:         name,
                rating:       rating,
                comment:      comment,
                canopyHeight: extra?.isEmpty == false ? extra : nil,
                amenity:      amenity,
                state:        state,
                city:         city,
                address:      address
            )
            StationsController.shared.addUserStation(station)

        case .dump:
            let amenities = DumpAmenities(
                potableWater:   amenitySwitch(at: 0),
                rinseWater:     amenitySwitch(at: 1),
                trailerParking: amenitySwitch(at: 2),
                restrooms:      amenitySwitch(at: 3),
                vending:        amenitySwitch(at: 4),
                evCharging:     amenitySwitch(at: 5)
            )
            let station = DumpStation(
                id:           UUID().uuidString,
                latitude:     location.coordinate.latitude,
                longitude:    location.coordinate.longitude,
                name:         name,
                rating:       rating,
                comment:      comment,
                cost:         extra?.isEmpty == false ? extra : nil,
                canopyHeight: nil,
                amenities:    amenities,
                state:        state,
                city:         city,
                address:      address
            )
            DumpStationsController.shared.addUserDumpStation(station)
        }

        onSave?()
        dismiss(animated: true)
    }

    private func amenitySwitch(at index: Int) -> Bool {
        guard index < amenitySwitches.count else { return false }
        return amenitySwitches[index].isOn
    }

    // MARK: - Alert Helper

    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension AddStationViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == nameField {
            ratingField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
}

// MARK: - UITextViewDelegate

extension AddStationViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        commentPlaceholder.isHidden = !textView.text.isEmpty
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        commentPlaceholder.isHidden = true
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        commentPlaceholder.isHidden = !textView.text.isEmpty
    }
}
