//
//  FilterSortViewController.swift
//  GlampingStations
//

import UIKit

// MARK: - Sort Order

enum StationSortOrder {
    case distance, nameAZ, rating

    var title: String {
        switch self {
        case .distance: return "Distance"
        case .nameAZ:   return "Name A–Z"
        case .rating:   return "Rating"
        }
    }
    var icon: String {
        switch self {
        case .distance: return "location.fill"
        case .nameAZ:   return "textformat.abc"
        case .rating:   return "star.fill"
        }
    }
}

// MARK: - Delegate

protocol FilterSortDelegate: AnyObject {
    func filterSortDidApply(activeAmenities: Set<String>, sortOrder: StationSortOrder, radius: Double?, stateFilter: String?)
    func filterSortDidReset()
}

// MARK: - FilterSortViewController

class FilterSortViewController: UIViewController {

    // MARK: Configuration (set before presenting)
    var amenityOptions: [String] = []
    var activeAmenities: Set<String> = []
    var currentSort: StationSortOrder = .distance
    var currentRadius: Double? = nil           // nil = All
    var currentStateFilter: String? = nil      // nil = All
    var availableStates: [String] = []         // populated by parent VC
    weak var delegate: FilterSortDelegate?

    // MARK: Colors
    private let primaryBg  = UIColor(red: 10/255,  green: 25/255,  blue: 47/255,  alpha: 1)
    private let cardColor  = UIColor(red: 22/255,  green: 38/255,  blue: 62/255,  alpha: 1)
    private let accentGold = UIColor(red: 212/255, green: 175/255, blue: 55/255,  alpha: 1)
    private let mutedText  = UIColor(red: 150/255, green: 165/255, blue: 190/255, alpha: 1)

    // MARK: Tracked UI
    private var sortRowViews: [(container: UIView, order: StationSortOrder)] = []
    private var amenityToggles: [(button: UIButton, name: String)] = []
    private var radiusButtons: [(button: UIButton, value: Double?)] = []
    private var stateButtons: [(button: UIButton, state: String)] = []

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = primaryBg
        buildUI()
    }

    // MARK: - UI Construction

    private func buildUI() {
        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.showsVerticalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 0
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 24),
            content.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -20),
            content.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -20),
            content.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -40)
        ])

        // ── Title ──
        let titleLabel = UILabel()
        titleLabel.text = "Filter & Sort"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        content.addArrangedSubview(titleLabel)
        content.setCustomSpacing(24, after: titleLabel)

        // ── Sort Section ──
        content.addArrangedSubview(sectionHeader("SORT BY"))
        content.setCustomSpacing(10, after: content.arrangedSubviews.last!)

        let sortCard = buildCard()
        let sortStack = UIStackView()
        sortStack.axis = .vertical
        sortStack.spacing = 0
        sortStack.translatesAutoresizingMaskIntoConstraints = false
        sortCard.addSubview(sortStack)
        NSLayoutConstraint.activate([
            sortStack.topAnchor.constraint(equalTo: sortCard.topAnchor),
            sortStack.leadingAnchor.constraint(equalTo: sortCard.leadingAnchor),
            sortStack.trailingAnchor.constraint(equalTo: sortCard.trailingAnchor),
            sortStack.bottomAnchor.constraint(equalTo: sortCard.bottomAnchor)
        ])

        let sortOrders: [StationSortOrder] = [.distance, .nameAZ, .rating]
        for (i, order) in sortOrders.enumerated() {
            let row = buildSortRow(order: order)
            sortStack.addArrangedSubview(row)
            if i < sortOrders.count - 1 {
                sortStack.addArrangedSubview(divider())
            }
        }
        content.addArrangedSubview(sortCard)
        content.setCustomSpacing(28, after: sortCard)

        // ── Filter Section ──
        content.addArrangedSubview(sectionHeader("FILTER BY AMENITY"))
        content.setCustomSpacing(10, after: content.arrangedSubviews.last!)

        let filterCard = buildCard()
        let filterStack = UIStackView()
        filterStack.axis = .vertical
        filterStack.spacing = 0
        filterStack.translatesAutoresizingMaskIntoConstraints = false
        filterCard.addSubview(filterStack)
        NSLayoutConstraint.activate([
            filterStack.topAnchor.constraint(equalTo: filterCard.topAnchor),
            filterStack.leadingAnchor.constraint(equalTo: filterCard.leadingAnchor),
            filterStack.trailingAnchor.constraint(equalTo: filterCard.trailingAnchor),
            filterStack.bottomAnchor.constraint(equalTo: filterCard.bottomAnchor)
        ])

        for (i, name) in amenityOptions.enumerated() {
            let row = buildAmenityRow(name: name)
            filterStack.addArrangedSubview(row)
            if i < amenityOptions.count - 1 {
                filterStack.addArrangedSubview(divider())
            }
        }
        content.addArrangedSubview(filterCard)
        content.setCustomSpacing(28, after: filterCard)

        // ── Radius Section ──
        content.addArrangedSubview(sectionHeader("DISTANCE RADIUS"))
        content.setCustomSpacing(10, after: content.arrangedSubviews.last!)

        let radiusScroll = UIScrollView()
        radiusScroll.showsHorizontalScrollIndicator = false
        radiusScroll.translatesAutoresizingMaskIntoConstraints = false
        radiusScroll.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let radiusStack = UIStackView()
        radiusStack.axis = .horizontal
        radiusStack.spacing = 8
        radiusStack.translatesAutoresizingMaskIntoConstraints = false
        radiusScroll.addSubview(radiusStack)
        NSLayoutConstraint.activate([
            radiusStack.topAnchor.constraint(equalTo: radiusScroll.topAnchor),
            radiusStack.leadingAnchor.constraint(equalTo: radiusScroll.leadingAnchor),
            radiusStack.trailingAnchor.constraint(equalTo: radiusScroll.trailingAnchor),
            radiusStack.bottomAnchor.constraint(equalTo: radiusScroll.bottomAnchor),
            radiusStack.heightAnchor.constraint(equalTo: radiusScroll.heightAnchor)
        ])

        let radiusOptions: [(title: String, value: Double?)] = [
            ("All", nil), ("25 mi", 25), ("50 mi", 50), ("100 mi", 100), ("200 mi", 200)
        ]
        for opt in radiusOptions {
            let btn = makePillButton(title: opt.title, isSelected: currentRadius == opt.value)
            btn.addTarget(self, action: #selector(radiusTapped(_:)), for: .touchUpInside)
            radiusStack.addArrangedSubview(btn)
            radiusButtons.append((button: btn, value: opt.value))
        }

        content.addArrangedSubview(radiusScroll)
        content.setCustomSpacing(28, after: radiusScroll)

        // ── State Section ──
        if !availableStates.isEmpty {
            content.addArrangedSubview(sectionHeader("FILTER BY STATE"))
            content.setCustomSpacing(10, after: content.arrangedSubviews.last!)

            let stateScroll = UIScrollView()
            stateScroll.showsHorizontalScrollIndicator = false
            stateScroll.translatesAutoresizingMaskIntoConstraints = false
            stateScroll.heightAnchor.constraint(equalToConstant: 40).isActive = true

            let stateStack = UIStackView()
            stateStack.axis = .horizontal
            stateStack.spacing = 8
            stateStack.translatesAutoresizingMaskIntoConstraints = false
            stateScroll.addSubview(stateStack)
            NSLayoutConstraint.activate([
                stateStack.topAnchor.constraint(equalTo: stateScroll.topAnchor),
                stateStack.leadingAnchor.constraint(equalTo: stateScroll.leadingAnchor),
                stateStack.trailingAnchor.constraint(equalTo: stateScroll.trailingAnchor),
                stateStack.bottomAnchor.constraint(equalTo: stateScroll.bottomAnchor),
                stateStack.heightAnchor.constraint(equalTo: stateScroll.heightAnchor)
            ])

            // "All" pill
            let allBtn = makePillButton(title: "All", isSelected: currentStateFilter == nil)
            allBtn.addTarget(self, action: #selector(stateAllTapped), for: .touchUpInside)
            stateStack.addArrangedSubview(allBtn)
            stateButtons.append((button: allBtn, state: ""))

            for state in availableStates {
                let btn = makePillButton(title: state, isSelected: currentStateFilter == state)
                btn.addTarget(self, action: #selector(stateTapped(_:)), for: .touchUpInside)
                stateStack.addArrangedSubview(btn)
                stateButtons.append((button: btn, state: state))
            }

            content.addArrangedSubview(stateScroll)
            content.setCustomSpacing(32, after: stateScroll)
        } else {
            content.setCustomSpacing(32, after: radiusScroll)
        }

        // ── Buttons ──
        let btnStack = UIStackView()
        btnStack.axis = .horizontal
        btnStack.spacing = 12
        btnStack.distribution = .fillEqually

        let resetBtn = makeButton(title: "Reset", filled: false)
        resetBtn.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)

        let applyBtn = makeButton(title: "Apply", filled: true)
        applyBtn.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)

        btnStack.addArrangedSubview(resetBtn)
        btnStack.addArrangedSubview(applyBtn)
        content.addArrangedSubview(btnStack)

        // Initial state
        refreshSortUI()
    }

    // MARK: - Row Builders

    private func buildSortRow(order: StationSortOrder) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let icon = UIImageView(image: UIImage(systemName: order.icon))
        icon.tintColor = accentGold
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = order.title
        label.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false

        let checkmark = UIImageView(image: UIImage(systemName: "checkmark"))
        checkmark.tintColor = accentGold
        checkmark.contentMode = .scaleAspectFit
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.isHidden = (order != currentSort)

        container.addSubview(icon)
        container.addSubview(label)
        container.addSubview(checkmark)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),

            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            checkmark.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            checkmark.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            checkmark.widthAnchor.constraint(equalToConstant: 18),
            checkmark.heightAnchor.constraint(equalToConstant: 18)
        ])

        // Invisible tap button over the whole row
        let tap = UIButton(type: .system)
        tap.translatesAutoresizingMaskIntoConstraints = false
        // Store the order index so we can recover it in the action
        switch order {
        case .distance: tap.tag = 0
        case .nameAZ:   tap.tag = 1
        case .rating:   tap.tag = 2
        }
        tap.addTarget(self, action: #selector(sortRowTapped(_:)), for: .touchUpInside)
        container.addSubview(tap)
        NSLayoutConstraint.activate([
            tap.topAnchor.constraint(equalTo: container.topAnchor),
            tap.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tap.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tap.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        sortRowViews.append((container: container, order: order))
        return container
    }

    private func buildAmenityRow(name: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let label = UILabel()
        label.text = name
        label.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false

        let isOn = activeAmenities.contains(name)
        let toggle = UIButton(type: .custom)
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.setImage(UIImage(systemName: isOn ? "checkmark.square.fill" : "square"), for: .normal)
        toggle.tintColor = isOn ? accentGold : mutedText
        toggle.addTarget(self, action: #selector(amenityToggled(_:)), for: .touchUpInside)

        container.addSubview(label)
        container.addSubview(toggle)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -8),

            toggle.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            toggle.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            toggle.widthAnchor.constraint(equalToConstant: 28),
            toggle.heightAnchor.constraint(equalToConstant: 28)
        ])

        // Also make the full row tappable
        let tap = UIButton(type: .system)
        tap.translatesAutoresizingMaskIntoConstraints = false
        tap.addTarget(self, action: #selector(amenityRowTapped(_:)), for: .touchUpInside)
        container.addSubview(tap)
        NSLayoutConstraint.activate([
            tap.topAnchor.constraint(equalTo: container.topAnchor),
            tap.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tap.trailingAnchor.constraint(equalTo: toggle.leadingAnchor),
            tap.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        amenityToggles.append((button: toggle, name: name))
        return container
    }

    // MARK: - Helper Builders

    private func buildCard() -> UIView {
        let v = UIView()
        v.backgroundColor = cardColor
        v.layer.cornerRadius = 14
        v.clipsToBounds = true
        return v
    }

    private func sectionHeader(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = mutedText
        return label
    }

    private func divider() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }

    private func makeButton(title: String, filled: Bool) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.layer.cornerRadius = 12
        btn.heightAnchor.constraint(equalToConstant: 50).isActive = true
        if filled {
            btn.backgroundColor = accentGold
            btn.setTitleColor(.black, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        } else {
            btn.backgroundColor = cardColor
            btn.setTitleColor(mutedText, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        }
        return btn
    }

    // MARK: - State

    private func refreshSortUI() {
        for entry in sortRowViews {
            // Find the checkmark: it's the UIImageView in the container that's NOT the icon (icon is first)
            let imageViews = entry.container.subviews.compactMap { $0 as? UIImageView }
            // icon is at index 0, checkmark at index 1
            if imageViews.count >= 2 {
                imageViews[1].isHidden = (entry.order != currentSort)
            }
        }
    }

    private func refreshAmenityToggle(_ toggle: UIButton, name: String) {
        let isOn = activeAmenities.contains(name)
        toggle.setImage(UIImage(systemName: isOn ? "checkmark.square.fill" : "square"), for: .normal)
        toggle.tintColor = isOn ? accentGold : mutedText
    }

    // MARK: - Pill Buttons

    private func makePillButton(title: String, isSelected: Bool) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        btn.layer.cornerRadius = 16
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16)
        stylePill(btn, selected: isSelected)
        return btn
    }

    private func stylePill(_ btn: UIButton, selected: Bool) {
        if selected {
            btn.backgroundColor = accentGold
            btn.setTitleColor(.black, for: .normal)
        } else {
            btn.backgroundColor = cardColor
            btn.setTitleColor(mutedText, for: .normal)
        }
    }

    @objc private func radiusTapped(_ sender: UIButton) {
        guard let entry = radiusButtons.first(where: { $0.button === sender }) else { return }
        currentRadius = entry.value
        for rb in radiusButtons {
            stylePill(rb.button, selected: rb.value == currentRadius)
        }
    }

    @objc private func stateAllTapped() {
        currentStateFilter = nil
        for sb in stateButtons {
            stylePill(sb.button, selected: sb.state.isEmpty)
        }
    }

    @objc private func stateTapped(_ sender: UIButton) {
        guard let entry = stateButtons.first(where: { $0.button === sender }) else { return }
        currentStateFilter = entry.state
        for sb in stateButtons {
            stylePill(sb.button, selected: sb.state == currentStateFilter)
        }
    }

    // MARK: - Actions

    @objc private func sortRowTapped(_ sender: UIButton) {
        switch sender.tag {
        case 1:  currentSort = .nameAZ
        case 2:  currentSort = .rating
        default: currentSort = .distance
        }
        refreshSortUI()
    }

    @objc private func amenityToggled(_ sender: UIButton) {
        guard let entry = amenityToggles.first(where: { $0.button === sender }) else { return }
        toggleAmenity(entry.name, button: entry.button)
    }

    @objc private func amenityRowTapped(_ sender: UIButton) {
        // The row tap button sits in the same container as the toggle button
        // Find the matching amenity toggle for this container
        guard let container = sender.superview else { return }
        if let entry = amenityToggles.first(where: { $0.button.superview === container }) {
            toggleAmenity(entry.name, button: entry.button)
        }
    }

    private func toggleAmenity(_ name: String, button: UIButton) {
        if activeAmenities.contains(name) {
            activeAmenities.remove(name)
        } else {
            activeAmenities.insert(name)
        }
        refreshAmenityToggle(button, name: name)
    }

    @objc private func applyTapped() {
        delegate?.filterSortDidApply(
            activeAmenities: activeAmenities,
            sortOrder: currentSort,
            radius: currentRadius,
            stateFilter: currentStateFilter
        )
        dismiss(animated: true)
    }

    @objc private func resetTapped() {
        activeAmenities = []
        currentSort = .distance
        currentRadius = nil
        currentStateFilter = nil
        for entry in amenityToggles {
            refreshAmenityToggle(entry.button, name: entry.name)
        }
        refreshSortUI()
        for rb in radiusButtons { stylePill(rb.button, selected: rb.value == nil) }
        for sb in stateButtons { stylePill(sb.button, selected: sb.state.isEmpty) }
        delegate?.filterSortDidReset()
        dismiss(animated: true)
    }
}
