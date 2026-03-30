//
//  PaywallViewController.swift
//  GlampingStations
//

import UIKit
import StoreKit

class PaywallViewController: UIViewController {

    // MARK: - Colors
    private var primaryBg:  UIColor { AppDelegate.primaryBg }
    private var cardColor:  UIColor { AppDelegate.cardColor }
    private let accentGold = UIColor(red: 212/255, green: 175/255, blue: 55/255, alpha: 1)
    private var mutedText:  UIColor { AppDelegate.mutedText }

    // MARK: - Views
    private let purchaseButton = UIButton(type: .system)
    private let restoreButton  = UIButton(type: .system)
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = primaryBg
        buildUI()
    }

    // MARK: - UI

    private func buildUI() {
        // Close button
        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeBtn.tintColor = mutedText
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeBtn)

        // Crown icon
        let crownIcon = UIImageView(image: UIImage(systemName: "crown.fill"))
        crownIcon.tintColor = accentGold
        crownIcon.contentMode = .scaleAspectFit
        crownIcon.translatesAutoresizingMaskIntoConstraints = false

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Go Premium"
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center

        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.text = "One-time purchase. No subscription."
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = mutedText
        subtitleLabel.textAlignment = .center

        // Feature rows
        let features: [(icon: String, title: String, desc: String)] = [
            ("star.fill",           "Unlimited Favorites",  "Save as many stations as you want"),
            ("wifi.slash",          "Offline Mode",         "Access stations with no cell signal"),
            ("map.fill",            "Trip Planner",         "Find stations along your entire route")
        ]
        let featuresStack = UIStackView(arrangedSubviews: features.map { makeFeatureRow($0) })
        featuresStack.axis = .vertical
        featuresStack.spacing = 16

        // Price card
        let priceCard = UIView()
        priceCard.backgroundColor = cardColor
        priceCard.layer.cornerRadius = 16
        priceCard.translatesAutoresizingMaskIntoConstraints = false

        let priceLabel = UILabel()
        priceLabel.text = "$4.99"
        priceLabel.font = UIFont.systemFont(ofSize: 36, weight: .bold)
        priceLabel.textColor = accentGold
        priceLabel.textAlignment = .center

        let priceSubLabel = UILabel()
        priceSubLabel.text = "One-time · Lifetime access"
        priceSubLabel.font = UIFont.systemFont(ofSize: 13)
        priceSubLabel.textColor = mutedText
        priceSubLabel.textAlignment = .center

        let priceStack = UIStackView(arrangedSubviews: [priceLabel, priceSubLabel])
        priceStack.axis = .vertical
        priceStack.spacing = 4
        priceStack.translatesAutoresizingMaskIntoConstraints = false
        priceCard.addSubview(priceStack)

        // Purchase button
        purchaseButton.setTitle("Unlock Premium", for: .normal)
        purchaseButton.backgroundColor = accentGold
        purchaseButton.setTitleColor(.black, for: .normal)
        purchaseButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        purchaseButton.layer.cornerRadius = 14
        purchaseButton.translatesAutoresizingMaskIntoConstraints = false
        purchaseButton.addTarget(self, action: #selector(purchaseTapped), for: .touchUpInside)

        // Loading indicator
        loadingIndicator.color = .black
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.isHidden = true
        purchaseButton.addSubview(loadingIndicator)

        // Restore button
        restoreButton.setTitle("Restore Purchase", for: .normal)
        restoreButton.setTitleColor(mutedText, for: .normal)
        restoreButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        restoreButton.translatesAutoresizingMaskIntoConstraints = false
        restoreButton.addTarget(self, action: #selector(restoreTapped), for: .touchUpInside)

        // Legal note
        let legalLabel = UILabel()
        legalLabel.text = "Payment charged to your Apple ID account at confirmation of purchase."
        legalLabel.font = UIFont.systemFont(ofSize: 10)
        legalLabel.textColor = mutedText.withAlphaComponent(0.6)
        legalLabel.textAlignment = .center
        legalLabel.numberOfLines = 0

        // Main scroll stack
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        let contentStack = UIStackView(arrangedSubviews: [
            crownIcon, titleLabel, subtitleLabel,
            featuresStack, priceCard,
            purchaseButton, restoreButton, legalLabel
        ])
        contentStack.axis = .vertical
        contentStack.spacing = 24
        contentStack.alignment = .fill
        contentStack.setCustomSpacing(8,  after: titleLabel)
        contentStack.setCustomSpacing(32, after: subtitleLabel)
        contentStack.setCustomSpacing(32, after: featuresStack)
        contentStack.setCustomSpacing(20, after: priceCard)
        contentStack.setCustomSpacing(12, after: purchaseButton)
        contentStack.setCustomSpacing(16, after: restoreButton)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        view.addSubview(closeBtn)

        NSLayoutConstraint.activate([
            closeBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeBtn.widthAnchor.constraint(equalToConstant: 32),
            closeBtn.heightAnchor.constraint(equalToConstant: 32),

            scrollView.topAnchor.constraint(equalTo: closeBtn.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -48),

            crownIcon.heightAnchor.constraint(equalToConstant: 52),

            priceStack.topAnchor.constraint(equalTo: priceCard.topAnchor, constant: 20),
            priceStack.bottomAnchor.constraint(equalTo: priceCard.bottomAnchor, constant: -20),
            priceStack.centerXAnchor.constraint(equalTo: priceCard.centerXAnchor),

            purchaseButton.heightAnchor.constraint(equalToConstant: 54),

            loadingIndicator.centerXAnchor.constraint(equalTo: purchaseButton.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: purchaseButton.centerYAnchor)
        ])
    }

    private func makeFeatureRow(_ feature: (icon: String, title: String, desc: String)) -> UIView {
        let card = UIView()
        card.backgroundColor = cardColor
        card.layer.cornerRadius = 12
        card.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: feature.icon))
        icon.tintColor = accentGold
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let titleLbl = UILabel()
        titleLbl.text = feature.title
        titleLbl.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        titleLbl.textColor = .label

        let descLbl = UILabel()
        descLbl.text = feature.desc
        descLbl.font = UIFont.systemFont(ofSize: 12)
        descLbl.textColor = mutedText
        descLbl.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [titleLbl, descLbl])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(icon)
        card.addSubview(textStack)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            icon.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),

            textStack.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            textStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            textStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])

        return card
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func purchaseTapped() {
        setLoading(true)
        Task {
            do {
                let success = try await PremiumManager.shared.purchase()
                await MainActor.run {
                    setLoading(false)
                    if success { dismiss(animated: true) }
                }
            } catch {
                await MainActor.run {
                    setLoading(false)
                    showAlert("Purchase Failed", message: error.localizedDescription)
                }
            }
        }
    }

    @objc private func restoreTapped() {
        setLoading(true)
        Task {
            await PremiumManager.shared.restorePurchases()
            await MainActor.run {
                setLoading(false)
                if PremiumManager.shared.isPremium {
                    dismiss(animated: true)
                } else {
                    showAlert("Nothing to Restore", message: "No previous purchase found for this Apple ID.")
                }
            }
        }
    }

    private func setLoading(_ loading: Bool) {
        if loading {
            purchaseButton.setTitle("", for: .normal)
            loadingIndicator.isHidden = false
            loadingIndicator.startAnimating()
            purchaseButton.isEnabled = false
            restoreButton.isEnabled = false
        } else {
            purchaseButton.setTitle("Unlock Premium", for: .normal)
            loadingIndicator.isHidden = true
            loadingIndicator.stopAnimating()
            purchaseButton.isEnabled = true
            restoreButton.isEnabled = true
        }
    }

    private func showAlert(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
