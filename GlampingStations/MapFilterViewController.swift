//
//  MapFilterViewController.swift
//  GlampingStations
//

import UIKit

// MARK: - MapFilterState

struct MapFilterState {
    var showFuelStations: Bool = true
    var showDumpStations: Bool = true
    var fuelAmenities: Set<String> = []
    var dumpAmenities: Set<String> = []
    var radius: Double? = nil        // nil = All
    var stateFilter: String? = nil   // nil = All states

    var isActive: Bool {
        !showFuelStations || !showDumpStations
            || !fuelAmenities.isEmpty || !dumpAmenities.isEmpty
            || radius != nil || stateFilter != nil
    }
}

// MARK: - MapFilterDelegate

protocol MapFilterDelegate: AnyObject {
    func mapFilterDidApply(_ state: MapFilterState)
    func mapFilterDidReset()
}

// MARK: - MapFilterViewController

class MapFilterViewController: UIViewController {

    // MARK: Configuration (set before presenting)
    var currentState: MapFilterState = MapFilterState()
    var availableStates: [String] = []
    weak var delegate: MapFilterDelegate?

    // MARK: Colors (match FilterSortViewController)
    private let primaryBg  = UIColor(red: 10/255,  green: 25/255,  blue: 47/255,  alpha: 1)
    private let cardColor  = UIColor(red: 22/255,  green: 38/255,  blue: 62/255,  alpha: 1)
    private let accentGold = UIColor(red: 212/255, green: 175/255, blue: 55/255,  alpha: 1)
    private let mutedText  = UIColor(red: 150/255, green: 165/255, blue: 190/255, alpha: 1)

    // MARK: Amenity options
    private let fuelAmenityOptions = ["Diesel", "Large Vehicle Access", "DEF at Pump",
                                      "Shower", "Bathroom", "Repair Shop", "CAT Scale", "Customer Added"]
    private let dumpAmenityOptions = ["Potable Water", "Rinse Water", "Trailer Parking",
                                      "Restrooms", "Vending", "EV Charging", "Customer Added"]

    // MARK: Tracked UI
    private var fuelToggleButton: UIButton!
    private var dumpToggleButton: UIButton!
    private var fuelAmenityCard: UIView!
    private var dumpAmenityCard: UIView!
    private var fuelAmenityToggles: [(button: UIButton, name: String)] = []
    private var dumpAmenityToggles: [(button: UIButton, name: String)] = []
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
        titleLabel.text = "Map Filters"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        content.addArrangedSubview(titleLabel)
        content.setCustomSpacing(24, after: titleLabel)

        // ── Show on Map Section ──
        content.addArrangedSubview(sectionHeader("SHOW ON MAP"))
        content.setCustomSpacing(10, after: content.arrangedSubviews.last!)

        let layerCard = buildCard()
        let layerStack = UIStackView()
        layerStack.axis = .vertical
        layerStack.spacing = 0
        layerStack.translatesAutoresizingMaskIntoConstraints = false
        layerCard.addSubview(layerStack)
        NSLayoutConstraint.activate([
            layerStack.topAnchor.constraint(equalTo: layerCard.topAnchor),
            layerStack.leadingAnchor.constraint(equalTo: layerCard.leadingAnchor),
            layerStack.trailingAnchor.constraint(equalTo: layerCard.trailingAnchor),
            layerStack.bottomAnchor.constraint(equalTo: layerCard.bottomAnchor)
        ])

        let fuelRow = buildLayerToggleRow(
            title: "Fuel Stations",
            icon: "fuelpump.fill",
            isOn: currentState.showFuelStations,
            tag: 0
        )
        fuelToggleButton = fuelRow.button
        layerStack.addArrangedSubview(fuelRow.container)
        layerStack.addArrangedSubview(divider())

        let dumpRow = buildLayerToggleRow(
            title: "Dump Stations",
            icon: "drop.fill",
            isOn: currentState.showDumpStations,
            tag: 1
        )
        dumpToggleButton = dumpRow.button
        layerStack.addArrangedSubview(dumpRow.container)

        content.addArrangedSubview(layerCard)
        content.setCustomSpacing(28, after: layerCard)

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
            let btn = makePillButton(title: opt.title, isSelected: currentState.radius == opt.value)
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

            let allBtn = makePillButton(title: "All", isSelected: currentState.stateFilter == nil)
            allBtn.addTarget(self, action: #selector(stateAllTapped), for: .touchUpInside)
            stateStack.addArrangedSubview(allBtn)
            stateButtons.append((button: allBtn, state: ""))

            for state in availableStates {
                let btn = makePillButton(title: state, isSelected: currentState.stateFilter == state)
                btn.addTarget(self, action: #selector(stateTapped(_:)), for: .touchUpInside)
                stateStack.addArrangedSubview(btn)
                stateButtons.append((button: btn, state: state))
            }

            content.addArrangedSubview(stateScroll)
            content.setCustomSpacing(28, after: stateScroll)
        }

        // ── Fuel Amenity Section ──
        content.addArrangedSubview(sectionHeader("FUEL STATION FILTERS"))
        content.setCustomSpacing(10, after: content.arrangedSubviews.last!)

        fuelAmenityCard = buildAmenityCard(options: fuelAmenityOptions,
                                           activeAmenities: currentState.fuelAmenities,
                                           togglesStore: &fuelAmenityToggles,
                                           tag: 0)
        fuelAmenityCard.alpha = currentState.showFuelStations ? 1.0 : 0.35
        content.addArrangedSubview(fuelAmenityCard)
        content.setCustomSpacing(28, after: fuelAmenityCard)

        // ── Dump Amenity Section ──
        content.addArrangedSubview(sectionHeader("DUMP STATION FILTERS"))
        content.setCustomSpacing(10, after: content.arrangedSubviews.last!)

        dumpAmenityCard = buildAmenityCard(options: dumpAmenityOptions,
                                           activeAmenities: currentState.dumpAmenities,
                                           togglesStore: &dumpAmenityToggles,
                                           tag: 1)
        dumpAmenityCard.alpha = currentState.showDumpStations ? 1.0 : 0.35
        content.addArrangedSubview(dumpAmenityCard)
        content.setCustomSpacing(32, after: dumpAmenityCard)

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
    }

    // MARK: - Card Builders

    private func buildAmenityCard(options: [String],
                                  activeAmenities: Set<String>,
                                  togglesStore: inout [(button: UIButton, name: String)],
                                  tag: Int) -> UIView {
        let card = buildCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])

        for (i, name) in options.enumerated() {
            let row = buildAmenityRow(name: name,
                                     isOn: activeAmenities.contains(name),
                                     cardTag: tag,
                                     togglesStore: &togglesStore)
            stack.addArrangedSubview(row)
            if i < options.count - 1 {
                stack.addArrangedSubview(divider())
            }
        }
        return card
    }

    private func buildLayerToggleRow(title: String, icon: String, isOn: Bool, tag: Int)
        -> (container: UIView, button: UIButton) {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = accentGold
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false

        let toggle = UIButton(type: .custom)
        toggle.tag = tag
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.setImage(UIImage(systemName: isOn ? "checkmark.square.fill" : "square"), for: .normal)
        toggle.tintColor = isOn ? accentGold : mutedText
        toggle.addTarget(self, action: #selector(layerToggleTapped(_:)), for: .touchUpInside)

        container.addSubview(iconView)
        container.addSubview(label)
        container.addSubview(toggle)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            toggle.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            toggle.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            toggle.widthAnchor.constraint(equalToConstant: 28),
            toggle.heightAnchor.constraint(equalToConstant: 28)
        ])

        let tap = UIButton(type: .system)
        tap.tag = tag
        tap.translatesAutoresizingMaskIntoConstraints = false
        tap.addTarget(self, action: #selector(layerToggleTapped(_:)), for: .touchUpInside)
        container.addSubview(tap)
        NSLayoutConstraint.activate([
            tap.topAnchor.constraint(equalTo: container.topAnchor),
            tap.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tap.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tap.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return (container, toggle)
    }

    private func buildAmenityRow(name: String,
                                 isOn: Bool,
                                 cardTag: Int,
                                 togglesStore: inout [(button: UIButton, name: String)]) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let label = UILabel()
        label.text = name
        label.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false

        let toggle = UIButton(type: .custom)
        toggle.tag = cardTag   // 0 = fuel, 1 = dump
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

        let tap = UIButton(type: .system)
        tap.tag = cardTag
        tap.translatesAutoresizingMaskIntoConstraints = false
        tap.addTarget(self, action: #selector(amenityRowTapped(_:)), for: .touchUpInside)
        container.addSubview(tap)
        NSLayoutConstraint.activate([
            tap.topAnchor.constraint(equalTo: container.topAnchor),
            tap.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tap.trailingAnchor.constraint(equalTo: toggle.leadingAnchor),
            tap.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        togglesStore.append((button: toggle, name: name))
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

    // MARK: - Actions

    @objc private func layerToggleTapped(_ sender: UIButton) {
        if sender.tag == 0 {
            currentState.showFuelStations.toggle()
            let isOn = currentState.showFuelStations
            fuelToggleButton.setImage(UIImage(systemName: isOn ? "checkmark.square.fill" : "square"), for: .normal)
            fuelToggleButton.tintColor = isOn ? accentGold : mutedText
            UIView.animate(withDuration: 0.2) { self.fuelAmenityCard.alpha = isOn ? 1.0 : 0.35 }
            fuelAmenityCard.isUserInteractionEnabled = isOn
        } else {
            currentState.showDumpStations.toggle()
            let isOn = currentState.showDumpStations
            dumpToggleButton.setImage(UIImage(systemName: isOn ? "checkmark.square.fill" : "square"), for: .normal)
            dumpToggleButton.tintColor = isOn ? accentGold : mutedText
            UIView.animate(withDuration: 0.2) { self.dumpAmenityCard.alpha = isOn ? 1.0 : 0.35 }
            dumpAmenityCard.isUserInteractionEnabled = isOn
        }
    }

    @objc private func amenityToggled(_ sender: UIButton) {
        if sender.tag == 0 {
            if let entry = fuelAmenityToggles.first(where: { $0.button === sender }) {
                toggleAmenity(entry.name, button: entry.button, set: &currentState.fuelAmenities)
            }
        } else {
            if let entry = dumpAmenityToggles.first(where: { $0.button === sender }) {
                toggleAmenity(entry.name, button: entry.button, set: &currentState.dumpAmenities)
            }
        }
    }

    @objc private func amenityRowTapped(_ sender: UIButton) {
        guard let container = sender.superview else { return }
        if sender.tag == 0 {
            if let entry = fuelAmenityToggles.first(where: { $0.button.superview === container }) {
                toggleAmenity(entry.name, button: entry.button, set: &currentState.fuelAmenities)
            }
        } else {
            if let entry = dumpAmenityToggles.first(where: { $0.button.superview === container }) {
                toggleAmenity(entry.name, button: entry.button, set: &currentState.dumpAmenities)
            }
        }
    }

    private func toggleAmenity(_ name: String, button: UIButton, set: inout Set<String>) {
        if set.contains(name) {
            set.remove(name)
        } else {
            set.insert(name)
        }
        let isOn = set.contains(name)
        button.setImage(UIImage(systemName: isOn ? "checkmark.square.fill" : "square"), for: .normal)
        button.tintColor = isOn ? accentGold : mutedText
    }

    @objc private func radiusTapped(_ sender: UIButton) {
        guard let entry = radiusButtons.first(where: { $0.button === sender }) else { return }
        currentState.radius = entry.value
        for rb in radiusButtons { stylePill(rb.button, selected: rb.value == currentState.radius) }
    }

    @objc private func stateAllTapped() {
        currentState.stateFilter = nil
        for sb in stateButtons { stylePill(sb.button, selected: sb.state.isEmpty) }
    }

    @objc private func stateTapped(_ sender: UIButton) {
        guard let entry = stateButtons.first(where: { $0.button === sender }) else { return }
        currentState.stateFilter = entry.state
        for sb in stateButtons { stylePill(sb.button, selected: sb.state == currentState.stateFilter) }
    }

    @objc private func applyTapped() {
        delegate?.mapFilterDidApply(currentState)
        dismiss(animated: true)
    }

    @objc private func resetTapped() {
        currentState = MapFilterState()

        // Reset layer toggles
        fuelToggleButton.setImage(UIImage(systemName: "checkmark.square.fill"), for: .normal)
        fuelToggleButton.tintColor = accentGold
        dumpToggleButton.setImage(UIImage(systemName: "checkmark.square.fill"), for: .normal)
        dumpToggleButton.tintColor = accentGold
        fuelAmenityCard.alpha = 1.0
        dumpAmenityCard.alpha = 1.0
        fuelAmenityCard.isUserInteractionEnabled = true
        dumpAmenityCard.isUserInteractionEnabled = true

        // Reset amenity toggles
        for entry in fuelAmenityToggles {
            entry.button.setImage(UIImage(systemName: "square"), for: .normal)
            entry.button.tintColor = mutedText
        }
        for entry in dumpAmenityToggles {
            entry.button.setImage(UIImage(systemName: "square"), for: .normal)
            entry.button.tintColor = mutedText
        }

        // Reset pills
        for rb in radiusButtons { stylePill(rb.button, selected: rb.value == nil) }
        for sb in stateButtons  { stylePill(sb.button, selected: sb.state.isEmpty) }

        delegate?.mapFilterDidReset()
        dismiss(animated: true)
    }
}
