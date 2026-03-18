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

    private let primaryBg   = UIColor(red: 10/255,  green: 25/255,  blue: 47/255,  alpha: 1)
    private let cardColor   = UIColor(red: 22/255,  green: 38/255,  blue: 62/255,  alpha: 1)
    private let accentGold  = UIColor(red: 212/255, green: 175/255, blue: 55/255,  alpha: 1)
    private let mutedText   = UIColor(red: 150/255, green: 165/255, blue: 190/255, alpha: 1)

    override func viewDidLoad() {
        super.viewDidLoad()

        // Hide storyboard outlets
        versionLabel?.isHidden = true
        buildLabel?.isHidden = true

        view.backgroundColor = primaryBg

        // Navigation bar styling
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = primaryBg
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.navigationBar.standardAppearance = navAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = navAppearance
        navigationController?.navigationBar.tintColor = accentGold

        setupUI()
    }

    private func setupUI() {
        // App icon / logo circle
        let logoContainer = UIView()
        logoContainer.backgroundColor = accentGold
        logoContainer.layer.cornerRadius = 44
        logoContainer.translatesAutoresizingMaskIntoConstraints = false

        let logoEmoji = UILabel()
        logoEmoji.text = "⛺"
        logoEmoji.font = UIFont.systemFont(ofSize: 44)
        logoEmoji.textAlignment = .center
        logoEmoji.translatesAutoresizingMaskIntoConstraints = false
        logoContainer.addSubview(logoEmoji)

        // App name
        let appNameLabel = UILabel()
        appNameLabel.text = "Glamping Gas/Dump Stations"
        appNameLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        appNameLabel.textColor = .white
        appNameLabel.textAlignment = .center

        // Tagline
        let taglineLabel = UILabel()
        taglineLabel.text = "Find easy in/out gas stations and dump sites"
        taglineLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        taglineLabel.textColor = mutedText
        taglineLabel.textAlignment = .center

        // Header stack
        let headerStack = UIStackView(arrangedSubviews: [logoContainer, appNameLabel, taglineLabel])
        headerStack.axis = .vertical
        headerStack.alignment = .center
        headerStack.spacing = 12

        // Info cards
        let versionText = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let buildText   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"

        let versionCard = makeInfoCard(icon: "sparkles",       title: "App Version",   value: versionText)
        let buildCard   = makeInfoCard(icon: "hammer.fill",    title: "Build Number",   value: "#\(buildText)")
        let stationsCard = makeInfoCard(icon: "mappin.circle.fill", title: "Station Types", value: "Gas · Dump")

        // Divider
        let divider = UIView()
        divider.backgroundColor = UIColor(red: 40/255, green: 60/255, blue: 90/255, alpha: 1)
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true

        // Footer credit
        let footerLabel = UILabel()
        footerLabel.text = "Made with ♥ for adventurers"
        footerLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        footerLabel.textColor = mutedText
        footerLabel.textAlignment = .center

        // Cards container
        let cardsStack = UIStackView(arrangedSubviews: [versionCard, buildCard, stationsCard, divider, footerLabel])
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
        valueLbl.textColor = .white

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
