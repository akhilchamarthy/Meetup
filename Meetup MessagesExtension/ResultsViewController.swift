//
//  ResultsViewController.swift
//  Meetup MessagesExtension
//
//  Created by Akhil Chamarthy on 2/28/26.
//

import UIKit

protocol ResultsViewControllerDelegate: AnyObject {
    func didFinalizeMeetup(_ meetup: Meetup)
}

class ResultsViewController: UIViewController {

    weak var delegate: ResultsViewControllerDelegate?

    private let meetup: Meetup
    private let currentUserId: String

    // MARK: - Palette

    private static let blue = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
    private static let bg   = UIColor { tc in tc.userInterfaceStyle == .dark ? .systemGroupedBackground : UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1) }
    private static let ink  = UIColor.label

    // MARK: - Header

    private let headlineLabel: UILabel = {
        let l = UILabel()
        l.text          = "Results"
        l.font          = UIFont.systemFont(ofSize: 22, weight: .bold)
        l.textColor     = .label
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subheadLabel: UILabel = {
        let l = UILabel()
        l.font          = UIFont.systemFont(ofSize: 14)
        l.textColor     = .secondaryLabel
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let statusBadge: UILabel = {
        let l = UILabel()
        l.font              = UIFont.systemFont(ofSize: 13, weight: .semibold)
        l.textAlignment     = .center
        l.layer.cornerRadius = 10
        l.clipsToBounds     = true
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
        sv.axis    = .vertical
        sv.spacing = 12
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // MARK: - Participants card

    private let participantsCard = ResultsViewController.makeCard()

    private lazy var participantsTableView: UITableView = {
        let tv = UITableView()
        tv.delegate        = self
        tv.dataSource      = self
        tv.register(ParticipantCell.self, forCellReuseIdentifier: "ParticipantCell")
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.separatorInset  = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private var participantsHeightConstraint: NSLayoutConstraint!

    // MARK: - Heat map card

    private let heatMapCard = ResultsViewController.makeCard()

    private let heatMapCardTitle = ResultsViewController.makeCardTitle("Availability")

    private let calendarHeatMapView: CalendarHeatMapView = {
        let v = CalendarHeatMapView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let noResponsesLabel: UILabel = {
        let l = UILabel()
        l.text          = "Waiting for responses…"
        l.font          = UIFont.systemFont(ofSize: 14)
        l.textColor     = .secondaryLabel
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Finalize button

    private let finalizeButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Finalize Meetup", for: .normal)
        b.titleLabel?.font   = UIFont.systemFont(ofSize: 17, weight: .semibold)
        b.backgroundColor    = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 14
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(finalizeTapped), for: .touchUpInside)
        return b
    }()

    // MARK: - Data

    private var commonDays:  [Date]     = []
    private var commonSlots: [TimeSlot] = []
    private var dayHeat:     [Date: Int] = [:]
    private var isFullDay: Bool { meetup.type.isFullDay }

    // MARK: - Init

    init(meetup: Meetup, currentUserId: String) {
        self.meetup        = meetup
        self.currentUserId = currentUserId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Self.bg
        calculateData()
        setupUI()
        updateDynamicUI()
    }

    // MARK: - Calculation

    private func calculateData() {
        if isFullDay {
            commonDays = meetup.findCommonAvailableDays()
        } else {
            commonSlots = meetup.findCommonAvailableSlots()
        }
        dayHeat = computeDayHeat()
    }

    /// For each day in the meetup range, count how many participants are available.
    private func computeDayHeat() -> [Date: Int] {
        let cal = Calendar.current
        var heat: [Date: Int] = [:]
        for a in meetup.availabilities {
            if isFullDay {
                for day in a.availableDays {
                    heat[day, default: 0] += 1
                }
            } else {
                var covered = Set<Date>()
                for slot in a.availableSlots {
                    var d = cal.startOfDay(for: slot.start)
                    let end = cal.startOfDay(for: slot.end)
                    while d <= end {
                        covered.insert(d)
                        guard let next = cal.date(byAdding: .day, value: 1, to: d) else { break }
                        d = next
                    }
                }
                covered.forEach { heat[$0, default: 0] += 1 }
            }
        }
        return heat
    }

    private func allDaysInRange() -> [Date] {
        let cal = Calendar.current
        var days: [Date] = []
        var d   = cal.startOfDay(for: meetup.startDateRange)
        let end = cal.startOfDay(for: meetup.endDateRange)
        while d <= end {
            days.append(d)
            guard let next = cal.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        return days
    }

    // MARK: - Layout

    private func setupUI() {
        subheadLabel.text = "\(meetup.type.icon)  \(meetup.title)"

        // Status badge
        let fmt = DateFormatter(); fmt.dateStyle = .medium; fmt.timeStyle = .short
        if meetup.isFinalized, let slot = meetup.finalizedTimeSlot {
            statusBadge.text            = "  Finalized: \(fmt.string(from: slot.start))  "
            statusBadge.textColor       = .white
            statusBadge.backgroundColor = .systemGreen
        } else if meetup.isActive {
            statusBadge.text            = "  Due \(fmt.string(from: meetup.deadline))  "
            statusBadge.textColor       = Self.blue
            statusBadge.backgroundColor = Self.blue.withAlphaComponent(0.10)
        } else {
            statusBadge.text            = "  Response period ended  "
            statusBadge.textColor       = .white
            statusBadge.backgroundColor = .systemOrange
        }

        buildParticipantsCard()
        buildHeatMapCard()

        [participantsCard, heatMapCard].forEach { contentStack.addArrangedSubview($0) }

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

    private func buildParticipantsCard() {
        let title = Self.makeCardTitle("Participants")
        participantsCard.addSubview(title)
        participantsCard.addSubview(participantsTableView)
        title.translatesAutoresizingMaskIntoConstraints = false
        participantsHeightConstraint = participantsTableView.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: participantsCard.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: participantsCard.leadingAnchor, constant: 16),
            title.trailingAnchor.constraint(equalTo: participantsCard.trailingAnchor, constant: -16),

            participantsTableView.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            participantsTableView.leadingAnchor.constraint(equalTo: participantsCard.leadingAnchor),
            participantsTableView.trailingAnchor.constraint(equalTo: participantsCard.trailingAnchor),
            participantsHeightConstraint,
            participantsTableView.bottomAnchor.constraint(equalTo: participantsCard.bottomAnchor, constant: -8),
        ])
    }

    private func buildHeatMapCard() {
        let legend = buildLegend()

        heatMapCard.addSubview(heatMapCardTitle)
        heatMapCard.addSubview(noResponsesLabel)
        heatMapCard.addSubview(calendarHeatMapView)
        heatMapCard.addSubview(legend)

        heatMapCardTitle.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            heatMapCardTitle.topAnchor.constraint(equalTo: heatMapCard.topAnchor, constant: 16),
            heatMapCardTitle.leadingAnchor.constraint(equalTo: heatMapCard.leadingAnchor, constant: 16),
            heatMapCardTitle.trailingAnchor.constraint(equalTo: heatMapCard.trailingAnchor, constant: -16),

            // "Waiting" label — shown when no responses yet
            noResponsesLabel.topAnchor.constraint(equalTo: heatMapCardTitle.bottomAnchor, constant: 24),
            noResponsesLabel.leadingAnchor.constraint(equalTo: heatMapCard.leadingAnchor, constant: 16),
            noResponsesLabel.trailingAnchor.constraint(equalTo: heatMapCard.trailingAnchor, constant: -16),
            noResponsesLabel.bottomAnchor.constraint(equalTo: heatMapCard.bottomAnchor, constant: -24),

            // Heat map calendar
            calendarHeatMapView.topAnchor.constraint(equalTo: heatMapCardTitle.bottomAnchor, constant: 12),
            calendarHeatMapView.leadingAnchor.constraint(equalTo: heatMapCard.leadingAnchor, constant: 16),
            calendarHeatMapView.trailingAnchor.constraint(equalTo: heatMapCard.trailingAnchor, constant: -16),

            // Legend below the calendar
            legend.topAnchor.constraint(equalTo: calendarHeatMapView.bottomAnchor, constant: 12),
            legend.leadingAnchor.constraint(equalTo: heatMapCard.leadingAnchor, constant: 16),
            legend.trailingAnchor.constraint(equalTo: heatMapCard.trailingAnchor, constant: -16),
            legend.bottomAnchor.constraint(equalTo: heatMapCard.bottomAnchor, constant: -16),
        ])
    }

    /// Three color-dot + label pairs showing the heat map scale.
    private func buildLegend() -> UIView {
        let stack = UIStackView()
        stack.axis         = .horizontal
        stack.spacing      = 14
        stack.alignment    = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let items: [(UIColor, String)] = [
            (CalendarHeatMapView.heatColor(count: 0, total: 1), "None"),
            (CalendarHeatMapView.heatColor(count: 1, total: 3), "Some"),
            (CalendarHeatMapView.heatColor(count: 1, total: 1), "All"),
        ]

        for (color, label) in items {
            let dot = UIView()
            dot.backgroundColor    = color
            dot.layer.cornerRadius = 6
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 12).isActive  = true
            dot.heightAnchor.constraint(equalToConstant: 12).isActive = true

            let lbl = UILabel()
            lbl.text      = label
            lbl.font      = UIFont.systemFont(ofSize: 11)
            lbl.textColor = .secondaryLabel

            let item = UIStackView(arrangedSubviews: [dot, lbl])
            item.axis      = .horizontal
            item.spacing   = 5
            item.alignment = .center
            stack.addArrangedSubview(item)
        }

        // Spacer pushes items to the left
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(spacer)

        return stack
    }

    // MARK: - Dynamic updates

    private func updateDynamicUI() {
        let hasResponses = !meetup.availabilities.isEmpty
        let isCreator    = meetup.creatorId == currentUserId
        let hasCommon    = !commonDays.isEmpty || !commonSlots.isEmpty
        let canFinalize  = hasCommon && !meetup.isFinalized && isCreator

        participantsHeightConstraint.constant = CGFloat(max(1, meetup.availabilities.count) * 50)
        participantsTableView.reloadData()

        noResponsesLabel.isHidden    = hasResponses
        calendarHeatMapView.isHidden = !hasResponses

        finalizeButton.isHidden = !canFinalize

        if hasResponses {
            calendarHeatMapView.configure(
                daysInRange: allDaysInRange(),
                heat: dayHeat,
                totalParticipants: meetup.availabilities.count
            )
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
                guard let self else { return }
                let cal   = Calendar.current
                let start = cal.startOfDay(for: day)
                let end   = cal.date(byAdding: .day, value: 1, to: start)!
                self.commitFinalization(slot: TimeSlot(start: start, end: end), label: fmt.string(from: day))
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
            let label = "\(fmt.string(from: slot.start)) – \(fmt.string(from: slot.end))"
            alert.addAction(UIAlertAction(title: label, style: .default) { [weak self] _ in
                self?.commitFinalization(slot: slot, label: fmt.string(from: slot.start))
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        popoverIfNeeded(alert, sourceView: finalizeButton)
        present(alert, animated: true)
    }

    private func commitFinalization(slot: TimeSlot, label: String) {
        var finalized = meetup
        finalized.isFinalized      = true
        finalized.finalizedTimeSlot = slot
        delegate?.didFinalizeMeetup(finalized)

        finalizeButton.isHidden = true
        statusBadge.text            = "  Finalized: \(label)  "
        statusBadge.textColor       = .white
        statusBadge.backgroundColor = .systemGreen
    }

    private func popoverIfNeeded(_ alert: UIAlertController, sourceView: UIView) {
        if let pop = alert.popoverPresentationController {
            pop.sourceView = sourceView; pop.sourceRect = sourceView.bounds
        }
    }

    // MARK: - Factory helpers

    private static func makeCard() -> UIView {
        let v = UIView()
        v.backgroundColor        = UIColor { tc in tc.userInterfaceStyle == .dark ? .secondarySystemGroupedBackground : .white }
        v.layer.cornerRadius     = 16
        v.layer.shadowColor      = UIColor.black.cgColor
        v.layer.shadowOpacity    = 0.06
        v.layer.shadowRadius     = 8
        v.layer.shadowOffset     = CGSize(width: 0, height: 2)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    private static func makeCardTitle(_ text: String) -> UILabel {
        let l = UILabel()
        l.text      = text
        l.font      = UIFont.systemFont(ofSize: 13, weight: .semibold)
        l.textColor = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }
}

// MARK: - UITableView (participants only)

extension ResultsViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        meetup.availabilities.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ParticipantCell",
                                                 for: indexPath) as! ParticipantCell
        cell.configure(with: meetup.availabilities[indexPath.row],
                       total: meetup.availabilities.count)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 50 }
}

// MARK: - ParticipantCell

class ParticipantCell: UITableViewCell {

    private let avatarView: UIView = {
        let v = UIView()
        v.backgroundColor    = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 0.12)
        v.layer.cornerRadius = 16
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let avatarLabel: UILabel = {
        let l = UILabel()
        l.font          = UIFont.systemFont(ofSize: 14, weight: .semibold)
        l.textColor     = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font      = UIFont.systemFont(ofSize: 15, weight: .medium)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let slotsLabel: UILabel = {
        let l = UILabel()
        l.font      = UIFont.systemFont(ofSize: 12)
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

    func configure(with a: UserAvailability, total: Int) {
        nameLabel.text   = a.userName
        avatarLabel.text = String(a.userName.prefix(1)).uppercased()

        let n = a.availableSlots.count
        if total > 0 {
            let pct = Int((Double(n) / Double(total)) * 100)
            slotsLabel.text = "\(n) day\(n == 1 ? "" : "s") available · \(pct)%"
        } else {
            slotsLabel.text = "\(n) day\(n == 1 ? "" : "s") available"
        }
    }
}
