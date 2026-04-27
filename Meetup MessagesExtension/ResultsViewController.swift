//
//  ResultsViewController.swift
//  Meetup MessagesExtension
//
//  Created by Akhil Chamarthy on 2/28/26.
//

import UIKit

class ResultsViewController: UIViewController {

    private let meetup: Meetup

    // MARK: - Palette

    private static let blue    = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
    private static let bg      = UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1)
    private static let ink     = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1)

    // MARK: - Header

    private let headlineLabel: UILabel = {
        let l = UILabel()
        l.text = "Results"
        l.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        l.textColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subheadLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 14)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let statusBadge: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        l.textAlignment = .center
        l.layer.cornerRadius = 10
        l.clipsToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Scroll

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 12
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // MARK: - Participants card

    private let participantsCard = ResultsViewController.makeCard()

    private lazy var participantsTableView: UITableView = {
        let tv = UITableView()
        tv.delegate   = self
        tv.dataSource = self
        tv.register(ParticipantCell.self, forCellReuseIdentifier: "ParticipantCell")
        tv.isScrollEnabled   = false
        tv.backgroundColor   = .clear
        tv.separatorInset    = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private var participantsHeightConstraint: NSLayoutConstraint!

    // MARK: - Common times card

    private let commonCard = ResultsViewController.makeCard()

    private let commonCardTitle: UILabel = ResultsViewController.makeCardTitle("")

    private lazy var commonTableView: UITableView = {
        let tv = UITableView()
        tv.delegate   = self
        tv.dataSource = self
        tv.register(CommonDayCell.self,      forCellReuseIdentifier: "CommonDayCell")
        tv.register(AvailableSlotCell.self,  forCellReuseIdentifier: "AvailableSlotCell")
        tv.isScrollEnabled  = false
        tv.backgroundColor  = .clear
        tv.separatorInset   = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private var commonHeightConstraint: NSLayoutConstraint!

    private let noCommonLabel: UILabel = {
        let l = UILabel()
        l.text = "No common availability yet"
        l.font = UIFont.systemFont(ofSize: 15)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Finalize button

    private let finalizeButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Finalize Meetup", for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        b.backgroundColor  = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 14
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(finalizeTapped), for: .touchUpInside)
        return b
    }()

    // MARK: - Data

    private var commonDays:  [Date]     = []
    private var commonSlots: [TimeSlot] = []
    private var isFullDay: Bool { meetup.type.isFullDay }

    // MARK: - Init

    init(meetup: Meetup) {
        self.meetup = meetup
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Self.bg
        calculateCommon()
        setupUI()
        updateDynamicUI()
    }

    // MARK: - Calculation

    private func calculateCommon() {
        if isFullDay {
            commonDays = meetup.findCommonAvailableDays()
        } else {
            commonSlots = meetup.findCommonAvailableSlots()
        }
    }

    // MARK: - Layout

    private func setupUI() {
        subheadLabel.text = "\(meetup.type.icon)  \(meetup.title)"
        commonCardTitle.text = isFullDay ? "Common available days" : "Common available times"

        // Status badge
        let fmt = DateFormatter()
        fmt.dateStyle = .medium; fmt.timeStyle = .short
        if meetup.isFinalized, let slot = meetup.finalizedTimeSlot {
            statusBadge.text            = "  Finalized for \(fmt.string(from: slot.start))  "
            statusBadge.textColor       = .white
            statusBadge.backgroundColor = .systemGreen
        } else if meetup.isActive {
            statusBadge.text            = "  Responses due \(fmt.string(from: meetup.deadline))  "
            statusBadge.textColor       = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
            statusBadge.backgroundColor = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 0.10)
        } else {
            statusBadge.text            = "  Response period ended  "
            statusBadge.textColor       = .white
            statusBadge.backgroundColor = UIColor.systemOrange
        }

        // Participants card
        let participantsTitle = Self.makeCardTitle("Participants")
        participantsCard.addSubview(participantsTitle)
        participantsCard.addSubview(participantsTableView)
        participantsTitle.translatesAutoresizingMaskIntoConstraints = false
        participantsHeightConstraint = participantsTableView.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            participantsTitle.topAnchor.constraint(equalTo: participantsCard.topAnchor, constant: 16),
            participantsTitle.leadingAnchor.constraint(equalTo: participantsCard.leadingAnchor, constant: 16),
            participantsTitle.trailingAnchor.constraint(equalTo: participantsCard.trailingAnchor, constant: -16),

            participantsTableView.topAnchor.constraint(equalTo: participantsTitle.bottomAnchor, constant: 8),
            participantsTableView.leadingAnchor.constraint(equalTo: participantsCard.leadingAnchor),
            participantsTableView.trailingAnchor.constraint(equalTo: participantsCard.trailingAnchor),
            participantsHeightConstraint,
            participantsTableView.bottomAnchor.constraint(equalTo: participantsCard.bottomAnchor, constant: -8),
        ])

        // Common card
        commonCard.addSubview(commonCardTitle)
        commonCard.addSubview(commonTableView)
        commonCard.addSubview(noCommonLabel)
        commonCardTitle.translatesAutoresizingMaskIntoConstraints = false
        commonHeightConstraint = commonTableView.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            commonCardTitle.topAnchor.constraint(equalTo: commonCard.topAnchor, constant: 16),
            commonCardTitle.leadingAnchor.constraint(equalTo: commonCard.leadingAnchor, constant: 16),
            commonCardTitle.trailingAnchor.constraint(equalTo: commonCard.trailingAnchor, constant: -16),

            commonTableView.topAnchor.constraint(equalTo: commonCardTitle.bottomAnchor, constant: 8),
            commonTableView.leadingAnchor.constraint(equalTo: commonCard.leadingAnchor),
            commonTableView.trailingAnchor.constraint(equalTo: commonCard.trailingAnchor),
            commonHeightConstraint,
            commonTableView.bottomAnchor.constraint(equalTo: commonCard.bottomAnchor, constant: -8),

            noCommonLabel.topAnchor.constraint(equalTo: commonCardTitle.bottomAnchor, constant: 12),
            noCommonLabel.leadingAnchor.constraint(equalTo: commonCard.leadingAnchor, constant: 16),
            noCommonLabel.trailingAnchor.constraint(equalTo: commonCard.trailingAnchor, constant: -16),
            noCommonLabel.bottomAnchor.constraint(equalTo: commonCard.bottomAnchor, constant: -16),
        ])

        // Add cards to stack
        [participantsCard, commonCard].forEach { contentStack.addArrangedSubview($0) }

        scrollView.addSubview(contentStack)
        view.addSubview(headlineLabel)
        view.addSubview(subheadLabel)
        view.addSubview(statusBadge)
        view.addSubview(scrollView)
        view.addSubview(finalizeButton)

        NSLayoutConstraint.activate([
            headlineLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 28),
            headlineLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headlineLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            subheadLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 4),
            subheadLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subheadLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            statusBadge.topAnchor.constraint(equalTo: subheadLabel.bottomAnchor, constant: 10),
            statusBadge.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusBadge.heightAnchor.constraint(equalToConstant: 28),

            scrollView.topAnchor.constraint(equalTo: statusBadge.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: finalizeButton.topAnchor, constant: -12),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 4),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),

            finalizeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            finalizeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            finalizeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            finalizeButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    private func updateDynamicUI() {
        let rowCount    = isFullDay ? commonDays.count : commonSlots.count
        let hasCommon   = rowCount > 0
        let canFinalize = hasCommon && !meetup.isFinalized

        participantsHeightConstraint.constant = CGFloat(max(1, meetup.availabilities.count) * 50)
        commonTableView.isHidden = !hasCommon
        noCommonLabel.isHidden   = hasCommon
        finalizeButton.isHidden  = !canFinalize

        if hasCommon {
            commonHeightConstraint.constant = CGFloat(min(rowCount, 5) * 60)
        }
        view.layoutIfNeeded()
    }

    // MARK: - Finalize

    @objc private func finalizeTapped() {
        isFullDay ? finalizeFullDay() : finalizeTimed()
    }

    private func finalizeFullDay() {
        guard !commonDays.isEmpty else { return }
        let fmt = DateFormatter(); fmt.dateStyle = .full
        let alert = UIAlertController(title: "Finalize Meetup", message: "Pick the best day",
                                      preferredStyle: .actionSheet)
        for day in commonDays {
            alert.addAction(UIAlertAction(title: fmt.string(from: day), style: .default) { [weak self] _ in
                self?.showFinalizedAlert(fmt.string(from: day))
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        popoverIfNeeded(alert, sourceView: finalizeButton)
        present(alert, animated: true)
    }

    private func finalizeTimed() {
        guard !commonSlots.isEmpty else { return }
        let fmt = DateFormatter(); fmt.dateStyle = .medium; fmt.timeStyle = .short
        let alert = UIAlertController(title: "Finalize Meetup", message: "Pick the best time",
                                      preferredStyle: .actionSheet)
        for slot in commonSlots {
            alert.addAction(UIAlertAction(title: fmt.string(from: slot.start), style: .default) { [weak self] _ in
                self?.showFinalizedAlert(fmt.string(from: slot.start))
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        popoverIfNeeded(alert, sourceView: finalizeButton)
        present(alert, animated: true)
    }

    private func showFinalizedAlert(_ dateString: String) {
        let alert = UIAlertController(title: "Meetup Finalized! \u{1F389}",
                                      message: "Scheduled for \(dateString)",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Done", style: .default) { _ in self.dismiss(animated: true) })
        present(alert, animated: true)
    }

    private func popoverIfNeeded(_ alert: UIAlertController, sourceView: UIView) {
        if let pop = alert.popoverPresentationController {
            pop.sourceView = sourceView; pop.sourceRect = sourceView.bounds
        }
    }

    // MARK: - Factory helpers

    private static func makeCard() -> UIView {
        let v = UIView()
        v.backgroundColor = .white
        v.layer.cornerRadius = 16
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.06
        v.layer.shadowRadius = 8
        v.layer.shadowOffset = CGSize(width: 0, height: 2)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    private static func makeCardTitle(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        l.textColor = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }
}

// MARK: - UITableView

extension ResultsViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == participantsTableView { return meetup.availabilities.count }
        return isFullDay ? commonDays.count : commonSlots.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == participantsTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ParticipantCell",
                                                     for: indexPath) as! ParticipantCell
            cell.configure(with: meetup.availabilities[indexPath.row])
            return cell
        }
        if isFullDay {
            let cell = tableView.dequeueReusableCell(withIdentifier: "CommonDayCell",
                                                     for: indexPath) as! CommonDayCell
            cell.configure(with: commonDays[indexPath.row])
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "AvailableSlotCell",
                                                     for: indexPath) as! AvailableSlotCell
            cell.configure(with: commonSlots[indexPath.row])
            return cell
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        tableView == participantsTableView ? 50 : 60
    }
}

// MARK: - Cells

class ParticipantCell: UITableViewCell {

    private let avatarView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 0.12)
        v.layer.cornerRadius = 16
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let avatarLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        l.textColor = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        l.textColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let slotsLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 12)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle  = .none
        avatarView.addSubview(avatarLabel)
        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(slotsLabel)

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 32),
            avatarView.heightAnchor.constraint(equalToConstant: 32),

            avatarLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),

            slotsLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 10),
            slotsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            slotsLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with a: UserAvailability) {
        nameLabel.text  = a.userName
        slotsLabel.text = "\(a.availableSlots.count) day(s) available"
        avatarLabel.text = String(a.userName.prefix(1)).uppercased()
    }
}

class CommonDayCell: UITableViewCell {

    private let dotView: UIView = {
        let v = UIView()
        v.backgroundColor = .systemGreen
        v.layer.cornerRadius = 5
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let label: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        l.textColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear; selectionStyle = .none
        contentView.addSubview(dotView); contentView.addSubview(label)
        NSLayoutConstraint.activate([
            dotView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            dotView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            dotView.widthAnchor.constraint(equalToConstant: 10),
            dotView.heightAnchor.constraint(equalToConstant: 10),
            label.leadingAnchor.constraint(equalTo: dotView.trailingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with date: Date) {
        let fmt = DateFormatter(); fmt.dateStyle = .full
        label.text = fmt.string(from: date)
    }
}

class AvailableSlotCell: UITableViewCell {

    private let dotView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
        v.layer.cornerRadius = 5
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let timeLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        l.textColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let durationLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 12)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear; selectionStyle = .none
        contentView.addSubview(dotView); contentView.addSubview(timeLabel); contentView.addSubview(durationLabel)
        NSLayoutConstraint.activate([
            dotView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            dotView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            dotView.widthAnchor.constraint(equalToConstant: 10),
            dotView.heightAnchor.constraint(equalToConstant: 10),
            timeLabel.leadingAnchor.constraint(equalTo: dotView.trailingAnchor, constant: 10),
            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            timeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            durationLabel.leadingAnchor.constraint(equalTo: dotView.trailingAnchor, constant: 10),
            durationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            durationLabel.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 2),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with slot: TimeSlot) {
        let fmt = DateFormatter(); fmt.dateStyle = .medium; fmt.timeStyle = .short
        timeLabel.text = fmt.string(from: slot.start)
        let h = Int(slot.duration / 3600)
        let m = Int(slot.duration.truncatingRemainder(dividingBy: 3600) / 60)
        durationLabel.text = h > 0 ? "\(h)h \(m)m available" : "\(m)m available"
    }
}
