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

    private var primaryBg:  UIColor { AppDelegate.primaryBg }
    private var cardColor:  UIColor { AppDelegate.cardColor }
    private var accentGold: UIColor { AppDelegate.accentGold }
    private var routeTeal: UIColor { AppDelegate.routeTeal }
    private var dumpCopper: UIColor { AppDelegate.dumpCopper }
    private var mutedText:  UIColor { AppDelegate.mutedText }

    // MARK: - Views

    private let scrollView = UIScrollView()
    private let stackView  = UIStackView()

    // Favorite collection views
    private var gasCollectionView: UICollectionView!
    private var dumpCollectionView: UICollectionView!

    // Premium upsell
    private var premiumBannerContainer: UIView?

    // Data
    private var favoriteGasStations: [Station] = []
    private var favoriteDumpStations: [DumpStation] = []

    private let locationManager = CLLocationManager()
    private var userLocation = CLLocation(latitude: 0, longitude: 0)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Home"
        tabBarItem.image = AppDelegate.travelTrailerImage
        view.backgroundColor = primaryBg

        setupLocationManager()
        setupScrollView()
        buildHomeScreen()

        // Listen for data updates
        NotificationCenter.default.addObserver(self, selector: #selector(dataUpdated),
                                               name: StationsController.stationsDataParseComplete, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dataUpdated),
                                               name: DumpStationsController.dumpStationsDataParseComplete, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(premiumStatusChanged),
                                               name: PremiumManager.premiumStatusChanged, object: nil)

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

        // Premium upsell banner (only visible for free users)
        let banner = buildPremiumBanner()
        premiumBannerContainer = banner
        stackView.addArrangedSubview(banner)
        banner.isHidden = PremiumManager.shared.isPremium

        // Trip Planner card
        let tripCard = buildTripPlannerCard()
        stackView.addArrangedSubview(tripCard)

        // Favorite Gas Stations section
        let gasSection = buildFavoritesSection(
            title: "Favorite Gas Stations",
            icon: "fuelpump.fill",
            tintColor: accentGold,
            tag: 0
        )
        stackView.addArrangedSubview(gasSection)

        // Favorite Dump Stations section
        let dumpSection = buildFavoritesSection(
            title: "Favorite Dump Stations",
            image: AppDelegate.dumpStationImage,
            tintColor: dumpCopper,
            tag: 1
        )
        stackView.addArrangedSubview(dumpSection)
    }

    // MARK: - Header Card

    private func buildHeaderCard() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let card = TrailGradientView()
        card.colors = [
            UIColor(red: 28/255, green: 68/255, blue: 67/255, alpha: 1),
            UIColor(red: 11/255, green: 35/255, blue: 48/255, alpha: 1)
        ]
        card.layer.cornerRadius = 24
        card.layer.cornerCurve = .continuous
        card.layer.masksToBounds = true
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
        inner.spacing = 10
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)

        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 22),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -22),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -22)
        ])

        let eyebrow = UILabel()
        eyebrow.text = "RV ROAD COMPANION"
        eyebrow.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        eyebrow.textColor = routeTeal

        let titleRow = UIStackView()
        titleRow.axis = .horizontal
        titleRow.spacing = 14
        titleRow.alignment = .center

        let iconBadge = UIView()
        iconBadge.backgroundColor = accentGold.withAlphaComponent(0.16)
        iconBadge.layer.cornerRadius = 18
        iconBadge.layer.cornerCurve = .continuous
        iconBadge.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: AppDelegate.travelTrailerImage)
        iconView.tintColor = accentGold
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBadge.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconBadge.widthAnchor.constraint(equalToConstant: 58),
            iconBadge.heightAnchor.constraint(equalToConstant: 58),
            iconView.leadingAnchor.constraint(equalTo: iconBadge.leadingAnchor, constant: 10),
            iconView.trailingAnchor.constraint(equalTo: iconBadge.trailingAnchor, constant: -10),
            iconView.topAnchor.constraint(equalTo: iconBadge.topAnchor, constant: 10),
            iconView.bottomAnchor.constraint(equalTo: iconBadge.bottomAnchor, constant: -10)
        ])

        let titleLabel = UILabel()
        titleLabel.text = "Know the next\ngood stop."
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2

        titleRow.addArrangedSubview(iconBadge)
        titleRow.addArrangedSubview(titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Fuel, dump stations, and route confidence for the road ahead."
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        subtitleLabel.numberOfLines = 0

        inner.addArrangedSubview(eyebrow)
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
        card.layer.cornerRadius = 20
        card.layer.cornerCurve = .continuous
        card.layer.borderWidth = 1
        card.layer.borderColor = AppDelegate.separatorColor.cgColor
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

        statsStack.addArrangedSubview(buildStatItem(
            image: UIImage(systemName: "fuelpump.fill"),
            tintColor: accentGold,
            valueLabel: gasCountLabel,
            title: "Fuel"
        ))
        statsStack.addArrangedSubview(buildStatItem(
            image: AppDelegate.dumpStationImage,
            tintColor: dumpCopper,
            valueLabel: dumpCountLabel,
            title: "Dump"
        ))
        statsStack.addArrangedSubview(buildStatItem(
            image: UIImage(systemName: "star.fill"),
            tintColor: routeTeal,
            valueLabel: favCountLabel,
            title: "Saved"
        ))

        updateStats()

        return container
    }

    private func buildStatItem(image: UIImage?, tintColor: UIColor, valueLabel: UILabel, title: String) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 6

        let iconBadge = UIView()
        iconBadge.backgroundColor = tintColor.withAlphaComponent(0.13)
        iconBadge.layer.cornerRadius = 13
        iconBadge.layer.cornerCurve = .continuous
        iconBadge.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: image)
        iconView.tintColor = tintColor
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBadge.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconBadge.widthAnchor.constraint(equalToConstant: 36),
            iconBadge.heightAnchor.constraint(equalToConstant: 30),
            iconView.centerXAnchor.constraint(equalTo: iconBadge.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBadge.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 19),
            iconView.heightAnchor.constraint(equalToConstant: 19)
        ])

        valueLabel.text = "0"
        valueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .bold)
        valueLabel.textColor = .label
        valueLabel.textAlignment = .center

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        titleLbl.textColor = mutedText
        titleLbl.textAlignment = .center

        stack.addArrangedSubview(iconBadge)
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

    // MARK: - Premium Banner

    private func buildPremiumBanner() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor = UIColor(red: 35/255, green: 28/255, blue: 10/255, alpha: 1)
        card.layer.cornerRadius = 20
        card.layer.cornerCurve = .continuous
        card.layer.borderWidth = 1
        card.layer.borderColor = accentGold.withAlphaComponent(0.4).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        card.isUserInteractionEnabled = true
        container.addSubview(card)

        let crownIcon = UIImageView(image: UIImage(systemName: "crown.fill"))
        crownIcon.tintColor = accentGold
        crownIcon.contentMode = .scaleAspectFit
        crownIcon.translatesAutoresizingMaskIntoConstraints = false

        let titleLbl = UILabel()
        titleLbl.text = "Unlock Premium"
        titleLbl.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLbl.textColor = accentGold

        let subtitleLbl = UILabel()
        subtitleLbl.text = "Unlimited favorites, offline mode & trip planner — one-time $4.99"
        subtitleLbl.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        subtitleLbl.textColor = mutedText
        subtitleLbl.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [titleLbl, subtitleLbl])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = accentGold.withAlphaComponent(0.7)
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        card.addSubview(crownIcon)
        card.addSubview(textStack)
        card.addSubview(chevron)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            crownIcon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            crownIcon.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            crownIcon.widthAnchor.constraint(equalToConstant: 28),
            crownIcon.heightAnchor.constraint(equalToConstant: 28),

            textStack.leadingAnchor.constraint(equalTo: crownIcon.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
            textStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            textStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),

            chevron.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 14),
            chevron.heightAnchor.constraint(equalToConstant: 14)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(premiumBannerTapped))
        card.addGestureRecognizer(tap)

        return container
    }

    @objc private func premiumBannerTapped() {
        let paywall = PaywallViewController()
        paywall.modalPresentationStyle = .formSheet
        present(paywall, animated: true)
    }

    @objc private func premiumStatusChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.premiumBannerContainer?.isHidden = PremiumManager.shared.isPremium
        }
    }

    // MARK: - Trip Planner Card

    private func buildTripPlannerCard() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let card = TrailGradientView()
        card.colors = [
            routeTeal.withAlphaComponent(0.32),
            cardColor
        ]
        card.layer.cornerRadius = 20
        card.layer.cornerCurve = .continuous
        card.layer.borderWidth = 1
        card.layer.borderColor = routeTeal.withAlphaComponent(0.28).cgColor
        card.layer.masksToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        card.isUserInteractionEnabled = true
        container.addSubview(card)

        let mapIcon = UIImageView(image: AppDelegate.routeJourneyImage)
        mapIcon.tintColor = routeTeal
        mapIcon.contentMode = .scaleAspectFit
        mapIcon.translatesAutoresizingMaskIntoConstraints = false

        let titleLbl = UILabel()
        titleLbl.text = "Plan a Trip"
        titleLbl.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLbl.textColor = .label

        let subtitleLbl = UILabel()
        subtitleLbl.text = "Find fuel and dump stations along your route"
        subtitleLbl.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        subtitleLbl.textColor = mutedText
        subtitleLbl.numberOfLines = 0

        let lockIcon = UIImageView(image: UIImage(systemName: "crown.fill"))
        lockIcon.tintColor = accentGold
        lockIcon.contentMode = .scaleAspectFit
        lockIcon.translatesAutoresizingMaskIntoConstraints = false
        lockIcon.isHidden = PremiumManager.shared.isPremium

        let premiumLabel = UILabel()
        premiumLabel.text = "Premium"
        premiumLabel.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        premiumLabel.textColor = accentGold
        premiumLabel.isHidden = PremiumManager.shared.isPremium

        let badgeStack = UIStackView(arrangedSubviews: [lockIcon, premiumLabel])
        badgeStack.axis = .horizontal
        badgeStack.spacing = 4
        badgeStack.alignment = .center
        badgeStack.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLbl, subtitleLbl, badgeStack])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = routeTeal
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        card.addSubview(mapIcon)
        card.addSubview(textStack)
        card.addSubview(chevron)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            mapIcon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            mapIcon.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            mapIcon.widthAnchor.constraint(equalToConstant: 30),
            mapIcon.heightAnchor.constraint(equalToConstant: 30),

            textStack.leadingAnchor.constraint(equalTo: mapIcon.trailingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
            textStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            textStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),

            lockIcon.widthAnchor.constraint(equalToConstant: 14),
            lockIcon.heightAnchor.constraint(equalToConstant: 14),

            chevron.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 14),
            chevron.heightAnchor.constraint(equalToConstant: 14)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(tripPlannerTapped))
        card.addGestureRecognizer(tap)

        return container
    }

    @objc private func tripPlannerTapped() {
        guard let tabBarController else { return }
        if let routesIndex = tabBarController.viewControllers?.firstIndex(where: { vc in
            vc is TripPlannerViewController || vc.tabBarItem.title == "Routes"
        }) {
            if let routesVC = tabBarController.viewControllers?[routesIndex] as? TripPlannerViewController {
                routesVC.userLocation = userLocation
            }
            tabBarController.selectedIndex = routesIndex
        }
    }

    // MARK: - Favorites Section

    private func buildFavoritesSection(
        title: String,
        image: UIImage? = nil,
        icon: String? = nil,
        tintColor: UIColor,
        tag: Int
    ) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Section header
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.spacing = 8
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(headerStack)

        let iconView = UIImageView(image: image ?? icon.flatMap { UIImage(systemName: $0) })
        iconView.tintColor = tintColor
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .label

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
                image: UIImage(systemName: "fuelpump.fill"),
                tintColor: AppDelegate.accentGold
            )
        } else {
            let station = favoriteDumpStations[indexPath.item]
            let miles = CLLocation(latitude: station.latitude, longitude: station.longitude)
                .distance(from: userLocation) * 0.000621371
            cell.configure(
                name: station.name ?? "Unknown",
                rating: station.rating ?? "",
                distance: String(format: "%.0f mi", miles),
                image: AppDelegate.dumpStationImage,
                tintColor: AppDelegate.dumpCopper
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

    private var cardColor:  UIColor { AppDelegate.cardColor }
    private var accentGold: UIColor { AppDelegate.accentGold }
    private var mutedText:  UIColor { AppDelegate.mutedText }

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
        contentView.layer.cornerRadius = 18
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = AppDelegate.separatorColor.cgColor
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
        nameLabel.textColor = .label
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

    func configure(name: String, rating: String, distance: String, image: UIImage?, tintColor: UIColor) {
        nameLabel.text = name
        ratingLabel.text = rating
        distanceLabel.text = distance
        iconView.image = image
        iconView.tintColor = tintColor
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.text = nil
        ratingLabel.text = nil
        distanceLabel.text = nil
        iconView.image = nil
    }
}

private final class TrailGradientView: UIView {
    var colors: [UIColor] = [] {
        didSet { gradientLayer.colors = colors.map(\.cgColor) }
    }

    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradientLayer, at: 0)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}
