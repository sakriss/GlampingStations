//
//  HomeViewController.swift
//  GlampingStations
//
//  Created by Scott Kriss on 3/18/26.
//  Copyright © 2026 Scott Kriss. All rights reserved.
//

import UIKit
import CoreLocation

class HomeViewController: UIViewController {

    // MARK: - Colors

    private let primaryBg  = UIColor(red: 10/255,  green: 25/255,  blue: 47/255,  alpha: 1)
    private let cardColor  = UIColor(red: 22/255,  green: 38/255,  blue: 62/255,  alpha: 1)
    private let accentGold = UIColor(red: 212/255, green: 175/255, blue: 55/255,  alpha: 1)
    private let mutedText  = UIColor(red: 150/255, green: 165/255, blue: 190/255, alpha: 1)

    // MARK: - Views

    private let scrollView = UIScrollView()
    private let stackView  = UIStackView()

    // Favorite collection views
    private var gasCollectionView: UICollectionView!
    private var dumpCollectionView: UICollectionView!

    // Data
    private var favoriteGasStations: [Station] = []
    private var favoriteDumpStations: [DumpStation] = []

    private let locationManager = CLLocationManager()
    private var userLocation = CLLocation(latitude: 0, longitude: 0)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Home"
        view.backgroundColor = primaryBg

        setupLocationManager()
        setupScrollView()
        buildHomeScreen()

        // Listen for data updates
        NotificationCenter.default.addObserver(self, selector: #selector(dataUpdated),
                                               name: StationsController.stationsDataParseComplete, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dataUpdated),
                                               name: DumpStationsController.dumpStationsDataParseComplete, object: nil)

        // Kick off data fetch (will be a no-op if listeners already running)
        StationsController.shared.fetchStations()
        DumpStationsController.shared.fetchStations()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.standardAppearance = AppDelegate.tabBarAppearance
        tabBarController?.tabBar.scrollEdgeAppearance = AppDelegate.tabBarAppearance
        navigationController?.navigationBar.standardAppearance = AppDelegate.navBarAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = AppDelegate.navBarAppearance
        reloadFavorites()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Location Manager

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    // MARK: - Layout

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -32),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    // MARK: - Build Home Screen

    private func buildHomeScreen() {
        // Welcome header
        let headerCard = buildHeaderCard()
        stackView.addArrangedSubview(headerCard)

        // Quick stats card
        let statsCard = buildStatsCard()
        stackView.addArrangedSubview(statsCard)

        // Favorite Gas Stations section
        let gasSection = buildFavoritesSection(
            title: "Favorite Gas Stations",
            icon: "fuelpump.fill",
            tag: 0
        )
        stackView.addArrangedSubview(gasSection)

        // Favorite Dump Stations section
        let dumpSection = buildFavoritesSection(
            title: "Favorite Dump Stations",
            icon: "drop.fill",
            tag: 1
        )
        stackView.addArrangedSubview(dumpSection)
    }

    // MARK: - Header Card

    private func buildHeaderCard() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor = cardColor
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        let inner = UIStackView()
        inner.axis = .vertical
        inner.spacing = 8
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)

        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])

        // App icon + title row
        let titleRow = UIStackView()
        titleRow.axis = .horizontal
        titleRow.spacing = 12
        titleRow.alignment = .center

        let iconView = UIImageView()
        iconView.image = UIImage(systemName: "rv")
            ?? UIImage(systemName: "car.fill")
        iconView.tintColor = accentGold
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 36).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = "Glamping Stations"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .white

        titleRow.addArrangedSubview(iconView)
        titleRow.addArrangedSubview(titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Your guide to RV-friendly fuel and dump stops"
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = mutedText
        subtitleLabel.numberOfLines = 0

        inner.addArrangedSubview(titleRow)
        inner.addArrangedSubview(subtitleLabel)

        return container
    }

    // MARK: - Stats Card

    private var gasCountLabel: UILabel!
    private var dumpCountLabel: UILabel!
    private var favCountLabel: UILabel!

    private func buildStatsCard() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor = cardColor
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        let statsStack = UIStackView()
        statsStack.axis = .horizontal
        statsStack.distribution = .fillEqually
        statsStack.spacing = 8
        statsStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(statsStack)

        NSLayoutConstraint.activate([
            statsStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            statsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            statsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            statsStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        gasCountLabel = UILabel()
        dumpCountLabel = UILabel()
        favCountLabel = UILabel()

        statsStack.addArrangedSubview(buildStatItem(icon: "fuelpump.fill", valueLabel: gasCountLabel, title: "Gas Stations"))
        statsStack.addArrangedSubview(buildStatItem(icon: "drop.fill", valueLabel: dumpCountLabel, title: "Dump Stations"))
        statsStack.addArrangedSubview(buildStatItem(icon: "star.fill", valueLabel: favCountLabel, title: "Favorites"))

        updateStats()

        return container
    }

    private func buildStatItem(icon: String, valueLabel: UILabel, title: String) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = accentGold
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.heightAnchor.constraint(equalToConstant: 22).isActive = true

        valueLabel.text = "0"
        valueLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        valueLabel.textColor = .white
        valueLabel.textAlignment = .center

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        titleLbl.textColor = mutedText
        titleLbl.textAlignment = .center

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(valueLabel)
        stack.addArrangedSubview(titleLbl)

        return stack
    }

    private func updateStats() {
        let gasTotal = StationsController.shared.stationArray.count
        let dumpTotal = DumpStationsController.shared.dumpStationArray.count
        let favTotal = favoriteGasStations.count + favoriteDumpStations.count

        gasCountLabel?.text = "\(gasTotal)"
        dumpCountLabel?.text = "\(dumpTotal)"
        favCountLabel?.text = "\(favTotal)"
    }

    // MARK: - Favorites Section

    private func buildFavoritesSection(title: String, icon: String, tag: Int) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Section header
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.spacing = 8
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(headerStack)

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = accentGold
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .white

        headerStack.addArrangedSubview(iconView)
        headerStack.addArrangedSubview(titleLabel)

        // Collection view
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 220, height: 130)
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.tag = tag
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(FavoriteStationCell.self, forCellWithReuseIdentifier: FavoriteStationCell.reuseId)
        container.addSubview(collectionView)

        if tag == 0 {
            gasCollectionView = collectionView
        } else {
            dumpCollectionView = collectionView
        }

        // Empty state label
        let emptyLabel = UILabel()
        emptyLabel.text = "No favorites yet"
        emptyLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        emptyLabel.textColor = mutedText
        emptyLabel.textAlignment = .center
        emptyLabel.tag = 100 + tag
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: container.topAnchor),
            headerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            collectionView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 12),
            collectionView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 140),
            collectionView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor)
        ])

        return container
    }

    // MARK: - Data

    @objc private func dataUpdated() {
        DispatchQueue.main.async { [weak self] in
            self?.reloadFavorites()
        }
    }

    private func reloadFavorites() {
        favoriteGasStations = StationsController.shared.stationArray.filter { $0.favorite }
        favoriteDumpStations = DumpStationsController.shared.dumpStationArray.filter { $0.favorite }

        gasCollectionView?.reloadData()
        dumpCollectionView?.reloadData()
        updateStats()
        updateEmptyStates()
    }

    private func updateEmptyStates() {
        // Find empty labels by tag
        if let gasEmpty = view.viewWithTag(100) as? UILabel {
            gasEmpty.isHidden = !favoriteGasStations.isEmpty
        }
        if let dumpEmpty = view.viewWithTag(101) as? UILabel {
            dumpEmpty.isHidden = !favoriteDumpStations.isEmpty
        }
    }
}

// MARK: - UICollectionViewDataSource

extension HomeViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView.tag == 0 {
            return favoriteGasStations.count
        } else {
            return favoriteDumpStations.count
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FavoriteStationCell.reuseId, for: indexPath) as! FavoriteStationCell

        if collectionView.tag == 0 {
            let station = favoriteGasStations[indexPath.item]
            let miles = CLLocation(latitude: station.latitude, longitude: station.longitude)
                .distance(from: userLocation) * 0.000621371
            cell.configure(
                name: station.name ?? "Unknown",
                rating: station.rating ?? "",
                distance: String(format: "%.0f mi", miles),
                icon: "fuelpump.fill"
            )
        } else {
            let station = favoriteDumpStations[indexPath.item]
            let miles = CLLocation(latitude: station.latitude, longitude: station.longitude)
                .distance(from: userLocation) * 0.000621371
            cell.configure(
                name: station.name ?? "Unknown",
                rating: station.rating ?? "",
                distance: String(format: "%.0f mi", miles),
                icon: "drop.fill"
            )
        }

        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension HomeViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let detailsVC = storyboard?.instantiateViewController(withIdentifier: "StationDetailsViewController") as? StationDetailsViewController else { return }

        detailsVC.userLocation = userLocation

        if collectionView.tag == 0 {
            detailsVC.stationDetails = favoriteGasStations[indexPath.item]
        } else {
            detailsVC.dumpStationDetails = favoriteDumpStations[indexPath.item]
        }

        navigationController?.pushViewController(detailsVC, animated: true)
    }
}

// MARK: - CLLocationManagerDelegate

extension HomeViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last {
            userLocation = loc
            reloadFavorites()
            locationManager.stopUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Home location error: \(error)")
    }
}

// MARK: - FavoriteStationCell

class FavoriteStationCell: UICollectionViewCell {
    static let reuseId = "FavoriteStationCell"

    private let cardColor  = UIColor(red: 22/255,  green: 38/255,  blue: 62/255,  alpha: 1)
    private let accentGold = UIColor(red: 212/255, green: 175/255, blue: 55/255,  alpha: 1)
    private let mutedText  = UIColor(red: 150/255, green: 165/255, blue: 190/255, alpha: 1)

    private let nameLabel = UILabel()
    private let ratingLabel = UILabel()
    private let distanceLabel = UILabel()
    private let iconView = UIImageView()
    private let starIcon = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupCell() {
        contentView.backgroundColor = cardColor
        contentView.layer.cornerRadius = 14
        contentView.layer.masksToBounds = true

        // Star badge
        starIcon.image = UIImage(systemName: "star.fill")
        starIcon.tintColor = accentGold
        starIcon.translatesAutoresizingMaskIntoConstraints = false

        // Icon
        iconView.tintColor = accentGold
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // Name
        nameLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        // Rating
        ratingLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        ratingLabel.textColor = mutedText
        ratingLabel.translatesAutoresizingMaskIntoConstraints = false

        // Distance
        distanceLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        distanceLabel.textColor = accentGold
        distanceLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(starIcon)
        contentView.addSubview(iconView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(ratingLabel)
        contentView.addSubview(distanceLabel)

        NSLayoutConstraint.activate([
            // Star badge top-right
            starIcon.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            starIcon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            starIcon.widthAnchor.constraint(equalToConstant: 16),
            starIcon.heightAnchor.constraint(equalToConstant: 16),

            // Icon top-left
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            // Name below icon
            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 10),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),

            // Rating bottom-left
            ratingLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            ratingLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),

            // Distance bottom-right
            distanceLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            distanceLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14)
        ])
    }

    func configure(name: String, rating: String, distance: String, icon: String) {
        nameLabel.text = name
        ratingLabel.text = rating
        distanceLabel.text = distance
        iconView.image = UIImage(systemName: icon)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.text = nil
        ratingLabel.text = nil
        distanceLabel.text = nil
        iconView.image = nil
    }
}
