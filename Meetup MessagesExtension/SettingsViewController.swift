//
//  SettingsViewController.swift
//  Meetup MessagesExtension
//
//  Created by Akhil Chamarthy on 2/28/26.
//

import UIKit

class SettingsViewController: UIViewController {

    // Set to true when opened from a meetup creation screen (DateTimeSelection).
    let showMeetupSettings: Bool

    private var currentSettings: MeetupSettings

    // MARK: - Palette

    private static let blue = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
    private static let bg   = UIColor { tc in tc.userInterfaceStyle == .dark ? .systemGroupedBackground : UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1) }
    private static let ink  = UIColor.label

    // MARK: - UI

    private let grabber: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.systemGray4
        v.layer.cornerRadius = 2.5
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Settings"
        l.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 16
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let doneButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Done", for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        b.backgroundColor = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 14
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        return b
    }()

    private let nameTextField: UITextField = {
        let tf = UITextField()
        tf.font = UIFont.systemFont(ofSize: 16)
        tf.textColor = .label
        tf.borderStyle = .none
        tf.autocapitalizationType = .words
        tf.returnKeyType = .done
        tf.clearButtonMode = .whileEditing
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private lazy var showAvailabilitySwitch = makeSwitch(isOn: currentSettings.showParticipantAvailability)
    private lazy var anonymousSwitch        = makeSwitch(isOn: currentSettings.isAnonymous)
    private lazy var allowUpdatesSwitch     = makeSwitch(isOn: currentSettings.allowAvailabilityUpdates)
    private lazy var nightModeSwitch        = makeSwitch(isOn: UserDefaults.standard.bool(forKey: "meetup_night_mode"))

    // MARK: - Init

    init(showMeetupSettings: Bool) {
        self.showMeetupSettings = showMeetupSettings
        self.currentSettings = MeetupSettings.load()
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if #available(iOS 15, *) {
            sheetPresentationController?.detents = [.medium(), .large()]
            sheetPresentationController?.preferredCornerRadius = 24
            // Using our own grabber view instead of the system one.
            sheetPresentationController?.prefersGrabberVisible = false
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Self.bg

        nameTextField.text = UserDefaults.standard.string(forKey: "meetup_user_name") ?? ""
        nameTextField.placeholder = "Your name"
        nameTextField.delegate = self
        nameTextField.addTarget(self, action: #selector(nameChanged), for: .editingChanged)

        setupSwitchTargets()
        setupUI()
    }

    // MARK: - Layout

    private func setupUI() {
        view.addSubview(grabber)
        view.addSubview(titleLabel)
        view.addSubview(scrollView)
        view.addSubview(doneButton)
        scrollView.addSubview(contentStack)

        contentStack.addArrangedSubview(buildProfileCard())
        contentStack.addArrangedSubview(buildAppearanceCard())
        if showMeetupSettings {
            contentStack.addArrangedSubview(buildMeetupSettingsCard())
        }

        NSLayoutConstraint.activate([
            grabber.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            grabber.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            grabber.widthAnchor.constraint(equalToConstant: 36),
            grabber.heightAnchor.constraint(equalToConstant: 5),

            titleLabel.topAnchor.constraint(equalTo: grabber.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: doneButton.topAnchor, constant: -16),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -8),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),

            doneButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            doneButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            doneButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    private func buildProfileCard() -> UIView {
        let card = makeCard()
        let sectionTitle = makeSectionTitle("Your Profile")
        let rowLabel     = makeSubtitleLabel("How others see you in meetups")
        let underline    = makeHairline()

        [sectionTitle, rowLabel, nameTextField, underline].forEach {
            card.addSubview($0)
            ($0 as? UIView)?.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            sectionTitle.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            sectionTitle.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            sectionTitle.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            rowLabel.topAnchor.constraint(equalTo: sectionTitle.bottomAnchor, constant: 14),
            rowLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            rowLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            nameTextField.topAnchor.constraint(equalTo: rowLabel.bottomAnchor, constant: 8),
            nameTextField.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            nameTextField.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            nameTextField.heightAnchor.constraint(equalToConstant: 36),

            underline.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 2),
            underline.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            underline.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            underline.heightAnchor.constraint(equalToConstant: 1),
            underline.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return card
    }

    private func buildAppearanceCard() -> UIView {
        let card  = makeCard()
        let title = makeSectionTitle("Appearance")
        let row   = buildToggleRow(
            title: "Night Mode",
            subtitle: "Switch to a dark theme",
            toggle: nightModeSwitch
        )

        [title, row].forEach {
            card.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            title.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            row.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 14),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return card
    }

    private func buildMeetupSettingsCard() -> UIView {
        let card  = makeCard()
        let title = makeSectionTitle("Meetup Settings")
        let row1  = buildToggleRow(
            title: "Show everyone's availability",
            subtitle: "Participants can see each other's calendars",
            toggle: showAvailabilitySwitch
        )
        let div1 = makeHairline()
        let row2 = buildToggleRow(
            title: "Anonymous responses",
            subtitle: "Names are hidden; only the organizer sees who said what",
            toggle: anonymousSwitch
        )
        let div2 = makeHairline()
        let row3 = buildToggleRow(
            title: "Allow availability updates",
            subtitle: "Participants can change their response before the deadline",
            toggle: allowUpdatesSwitch
        )

        [title, row1, div1, row2, div2, row3].forEach {
            card.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            title.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            row1.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 14),
            row1.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            row1.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            div1.topAnchor.constraint(equalTo: row1.bottomAnchor, constant: 14),
            div1.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            div1.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            div1.heightAnchor.constraint(equalToConstant: 1),

            row2.topAnchor.constraint(equalTo: div1.bottomAnchor, constant: 14),
            row2.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            row2.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            div2.topAnchor.constraint(equalTo: row2.bottomAnchor, constant: 14),
            div2.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            div2.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            div2.heightAnchor.constraint(equalToConstant: 1),

            row3.topAnchor.constraint(equalTo: div2.bottomAnchor, constant: 14),
            row3.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            row3.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            row3.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return card
    }

    private func buildToggleRow(title: String, subtitle: String, toggle: UISwitch) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        titleLbl.textColor = Self.ink
        titleLbl.translatesAutoresizingMaskIntoConstraints = false

        let subLbl = UILabel()
        subLbl.text = subtitle
        subLbl.font = UIFont.systemFont(ofSize: 12)
        subLbl.textColor = .secondaryLabel
        subLbl.numberOfLines = 2
        subLbl.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(toggle)
        container.addSubview(titleLbl)
        container.addSubview(subLbl)

        NSLayoutConstraint.activate([
            // Pin toggle to the right with an explicit 4pt gap so it sits 20pt from the card edge.
            toggle.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            // Align every toggle to the title baseline so all three line up across different-height rows.
            toggle.centerYAnchor.constraint(equalTo: titleLbl.centerYAnchor),

            titleLbl.topAnchor.constraint(equalTo: container.topAnchor),
            titleLbl.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLbl.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12),

            subLbl.topAnchor.constraint(equalTo: titleLbl.bottomAnchor, constant: 3),
            subLbl.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            subLbl.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12),
            subLbl.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    // MARK: - Actions

    @objc private func nameChanged() {
        let raw = nameTextField.text ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        UserDefaults.standard.set(trimmed.isEmpty ? "User" : trimmed, forKey: "meetup_user_name")
        if !trimmed.isEmpty {
            UserDefaults.standard.set(true, forKey: "meetup_name_configured")
        }
    }

    @objc private func doneTapped() {
        nameChanged()   // commit any in-flight text
        currentSettings.save()
        dismiss(animated: true)
    }

    @objc private func showAvailabilityToggled(_ s: UISwitch) { currentSettings.showParticipantAvailability = s.isOn }
    @objc private func anonymousToggled(_ s: UISwitch)        { currentSettings.isAnonymous = s.isOn }
    @objc private func allowUpdatesToggled(_ s: UISwitch)     { currentSettings.allowAvailabilityUpdates = s.isOn }

    @objc private func nightModeToggled(_ s: UISwitch) {
        UserDefaults.standard.set(s.isOn, forKey: "meetup_night_mode")
        NotificationCenter.default.post(name: .meetupNightModeChanged, object: nil)
    }

    private func setupSwitchTargets() {
        showAvailabilitySwitch.addTarget(self, action: #selector(showAvailabilityToggled(_:)), for: .valueChanged)
        anonymousSwitch.addTarget(self,        action: #selector(anonymousToggled(_:)),        for: .valueChanged)
        allowUpdatesSwitch.addTarget(self,     action: #selector(allowUpdatesToggled(_:)),     for: .valueChanged)
        nightModeSwitch.addTarget(self,        action: #selector(nightModeToggled(_:)),        for: .valueChanged)
    }

    // MARK: - Factory helpers

    private func makeCard() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor { tc in tc.userInterfaceStyle == .dark ? .secondarySystemGroupedBackground : .white }
        v.layer.cornerRadius = 16
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.06
        v.layer.shadowRadius = 8
        v.layer.shadowOffset = CGSize(width: 0, height: 2)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    private func makeSectionTitle(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        l.textColor = Self.blue
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    private func makeSubtitleLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = UIFont.systemFont(ofSize: 12)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    private func makeHairline() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.systemGray5
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    private func makeSwitch(isOn: Bool) -> UISwitch {
        let s = UISwitch()
        s.isOn = isOn
        s.onTintColor = Self.blue
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }
}

// MARK: - UITextFieldDelegate

extension SettingsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
