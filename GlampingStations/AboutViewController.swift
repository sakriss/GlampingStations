//
//  AboutViewController.swift
//  GlampingStations
//
//  Created by Scott Kriss on 9/6/18.
//  Copyright © 2018 Scott Kriss. All rights reserved.
//

import UIKit

class AboutViewController: UIViewController {

    // Keep IBOutlets wired but hide them — layout is done programmatically
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var buildLabel: UILabel!

    private var primaryBg:  UIColor { AppDelegate.primaryBg }
    private var cardColor:  UIColor { AppDelegate.cardColor }
    private let accentGold = UIColor(red: 212/255, green: 175/255, blue: 55/255, alpha: 1)
    private var mutedText:  UIColor { AppDelegate.mutedText }

    private var demoBadgeLabel: UILabel?
    private var appearanceSegment: UISegmentedControl?

    // MARK: - Appearance Preference

    static let appearanceKey = "AppAppearanceMode"  // 0=Dark, 1=Light, 2=System

    static func applyStoredAppearance(to window: UIWindow?) {
        let stored = UserDefaults.standard.integer(forKey: appearanceKey)
        switch stored {
        case 1:  window?.overrideUserInterfaceStyle = .light
        case 2:  window?.overrideUserInterfaceStyle = .unspecified
        default: window?.overrideUserInterfaceStyle = .dark
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Hide storyboard outlets
        versionLabel?.isHidden = true
        buildLabel?.isHidden = true

        view.backgroundColor = primaryBg

        setupUI()
    }

    private func setupUI() {
        // App icon / logo circle
        let logoContainer = UIView()
        logoContainer.backgroundColor = accentGold
        logoContainer.layer.cornerRadius = 44
        logoContainer.translatesAutoresizingMaskIntoConstraints = false
        logoContainer.isUserInteractionEnabled = true

        let logoEmoji = UILabel()
        logoEmoji.text = "⛺"
        logoEmoji.font = UIFont.systemFont(ofSize: 44)
        logoEmoji.textAlignment = .center
        logoEmoji.translatesAutoresizingMaskIntoConstraints = false
        logoContainer.addSubview(logoEmoji)

        // Long-press gesture (5 seconds) to toggle demo mode
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLogoPressGesture(_:)))
        longPress.minimumPressDuration = 5.0
        logoContainer.addGestureRecognizer(longPress)

        // DEMO badge (shown below logo when demo mode is active)
        let demoBadge = UILabel()
        demoBadge.text = "DEMO MODE"
        demoBadge.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        demoBadge.textColor = accentGold
        demoBadge.textAlignment = .center
        demoBadge.isHidden = !PremiumManager.shared.isDemoModeEnabled
        demoBadgeLabel = demoBadge

        // App name
        let appNameLabel = UILabel()
        appNameLabel.text = "Glamping Gas/Dump Stations"
        appNameLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        appNameLabel.textColor = .label
        appNameLabel.textAlignment = .center

        // Tagline
        let taglineLabel = UILabel()
        taglineLabel.text = "Find easy in/out gas stations and dump sites"
        taglineLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        taglineLabel.textColor = mutedText
        taglineLabel.textAlignment = .center

        // Header stack
        let headerStack = UIStackView(arrangedSubviews: [logoContainer, demoBadge, appNameLabel, taglineLabel])
        headerStack.axis = .vertical
        headerStack.alignment = .center
        headerStack.spacing = 12

        // Info cards
        let versionText = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let buildText   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"

        let versionCard = makeInfoCard(icon: "sparkles",       title: "App Version",   value: versionText)
        let buildCard   = makeInfoCard(icon: "hammer.fill",    title: "Build Number",   value: "#\(buildText)")
        let stationsCard = makeInfoCard(icon: "mappin.circle.fill", title: "Station Types", value: "Gas · Dump")

        // Appearance card
        let appearanceCard = makeAppearanceCard()

        // Divider
        let divider = UIView()
        divider.backgroundColor = AppDelegate.separatorColor
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true

        // Footer credit
        let footerLabel = UILabel()
        footerLabel.text = "Made with ♥ for adventurers"
        footerLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        footerLabel.textColor = mutedText
        footerLabel.textAlignment = .center

        // Cards container
        let cardsStack = UIStackView(arrangedSubviews: [versionCard, buildCard, stationsCard, appearanceCard, divider, footerLabel])
        cardsStack.axis = .vertical
        cardsStack.spacing = 12
        cardsStack.alignment = .fill

        // Main vertical stack
        let mainStack = UIStackView(arrangedSubviews: [headerStack, cardsStack])
        mainStack.axis = .vertical
        mainStack.spacing = 36
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(mainStack)

        NSLayoutConstraint.activate([
            logoContainer.widthAnchor.constraint(equalToConstant: 88),
            logoContainer.heightAnchor.constraint(equalToConstant: 88),

            logoEmoji.centerXAnchor.constraint(equalTo: logoContainer.centerXAnchor),
            logoEmoji.centerYAnchor.constraint(equalTo: logoContainer.centerYAnchor),

            mainStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    // MARK: - Demo Mode Toggle

    @objc private func handleLogoPressGesture(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }

        let isCurrentlyEnabled = PremiumManager.shared.isDemoModeEnabled
        PremiumManager.shared.isDemoModeEnabled = !isCurrentlyEnabled

        let newState = PremiumManager.shared.isDemoModeEnabled
        demoBadgeLabel?.isHidden = !newState

        let stateText = newState ? "ON" : "OFF"
        let message = newState
            ? "Premium features are now unlocked for testing."
            : "Premium Demo Mode has been disabled."

        let alert = UIAlertController(
            title: "Premium Demo Mode \(stateText)",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func makeAppearanceCard() -> UIView {
        let card = UIView()
        card.backgroundColor = cardColor
        card.layer.cornerRadius = 14
        card.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: "circle.lefthalf.filled"))
        iconView.tintColor = accentGold
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22)
        ])

        let titleLbl = UILabel()
        titleLbl.text = "Appearance"
        titleLbl.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        titleLbl.textColor = mutedText

        let stored = UserDefaults.standard.integer(forKey: AboutViewController.appearanceKey)
        let segment = UISegmentedControl(items: ["Dark", "Light", "System"])
        segment.selectedSegmentIndex = stored
        segment.backgroundColor = AppDelegate.primaryBg
        segment.setTitleTextAttributes([.foregroundColor: AppDelegate.mutedText], for: .normal)
        segment.setTitleTextAttributes(
            [.foregroundColor: UIColor(red: 10/255, green: 25/255, blue: 47/255, alpha: 1)],
            for: .selected
        )
        segment.selectedSegmentTintColor = accentGold
        segment.addTarget(self, action: #selector(appearanceChanged(_:)), for: .valueChanged)
        appearanceSegment = segment

        let textStack = UIStackView(arrangedSubviews: [titleLbl, segment])
        textStack.axis = .vertical
        textStack.spacing = 10

        let rowStack = UIStackView(arrangedSubviews: [iconView, textStack])
        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = 14
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(rowStack)
        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            rowStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            rowStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            rowStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18)
        ])

        return card
    }

    @objc private func appearanceChanged(_ sender: UISegmentedControl) {
        UserDefaults.standard.set(sender.selectedSegmentIndex, forKey: AboutViewController.appearanceKey)
        guard let window = view.window else { return }
        switch sender.selectedSegmentIndex {
        case 1:  window.overrideUserInterfaceStyle = .light
        case 2:  window.overrideUserInterfaceStyle = .unspecified
        default: window.overrideUserInterfaceStyle = .dark
        }
        // Re-apply nav/tab bar appearances so they pick up the updated dynamic colors
        UINavigationBar.appearance().standardAppearance   = AppDelegate.navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = AppDelegate.navBarAppearance
        UINavigationBar.appearance().compactAppearance    = AppDelegate.navBarAppearance
        UITabBar.appearance().standardAppearance    = AppDelegate.tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance  = AppDelegate.tabBarAppearance
        // Force each visible nav/tab bar to refresh
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for w in scene.windows {
                for sub in w.subviews { sub.removeFromSuperview(); w.addSubview(sub) }
            }
        }
    }

    private func makeInfoCard(icon: String, title: String, value: String) -> UIView {
        let card = UIView()
        card.backgroundColor = cardColor
        card.layer.cornerRadius = 14
        card.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = accentGold
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22)
        ])

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        titleLbl.textColor = mutedText

        let valueLbl = UILabel()
        valueLbl.text = value
        valueLbl.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        valueLbl.textColor = .label

        let textStack = UIStackView(arrangedSubviews: [titleLbl, valueLbl])
        textStack.axis = .vertical
        textStack.spacing = 2

        let rowStack = UIStackView(arrangedSubviews: [iconView, textStack])
        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = 14
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(rowStack)
        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            rowStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            rowStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            rowStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18)
        ])

        return card
    }
}
