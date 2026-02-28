//
//  ResultsViewController.swift
//  Meetup MessagesExtension
//
//  Created by Akhil Chamarthy on 2/28/26.
//

import UIKit

class ResultsViewController: UIViewController {

    private let meetup: Meetup

    // MARK: - UI

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 22, weight: .bold)
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let statusLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16)
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let participantsLabel: UILabel = {
        let l = UILabel()
        l.text = "Participants"
        l.font = .systemFont(ofSize: 18, weight: .semibold)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var participantsTableView: UITableView = {
        let tv = UITableView()
        tv.delegate   = self
        tv.dataSource = self
        tv.register(ParticipantCell.self, forCellReuseIdentifier: "ParticipantCell")
        tv.layer.cornerRadius  = 8
        tv.layer.borderWidth   = 1
        tv.layer.borderColor   = UIColor.systemGray4.cgColor
        tv.isScrollEnabled     = false
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let commonLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 18, weight: .semibold)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var commonTableView: UITableView = {
        let tv = UITableView()
        tv.delegate   = self
        tv.dataSource = self
        tv.register(CommonDayCell.self,  forCellReuseIdentifier: "CommonDayCell")
        tv.register(AvailableSlotCell.self, forCellReuseIdentifier: "AvailableSlotCell")
        tv.layer.cornerRadius  = 8
        tv.layer.borderWidth   = 1
        tv.layer.borderColor   = UIColor.systemGray4.cgColor
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let noCommonLabel: UILabel = {
        let l = UILabel()
        l.text = "No common availability found yet"
        l.font = .systemFont(ofSize: 16)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let finalizeButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Finalize Meetup", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        b.backgroundColor  = .systemGreen
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 25
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(finalizeTapped), for: .touchUpInside)
        return b
    }()

    // MARK: - Data

    private var commonDays:  [Date]     = []   // for full-day meetups
    private var commonSlots: [TimeSlot] = []   // for timed meetups
    private var isFullDay: Bool { meetup.type.isFullDay }

    private var participantsHeightConstraint: NSLayoutConstraint!
    private var commonHeightConstraint: NSLayoutConstraint!

    // MARK: - Init

    init(meetup: Meetup) {
        self.meetup = meetup
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
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

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground
        titleLabel.text = "\(meetup.type.icon) \(meetup.title)"
        commonLabel.text = isFullDay ? "Common Available Days" : "Common Available Times"

        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short

        if meetup.isFinalized, let slot = meetup.finalizedTimeSlot {
            statusLabel.text = "✅ Finalized for \(fmt.string(from: slot.start))"
            statusLabel.textColor = .systemGreen
        } else if meetup.isActive {
            statusLabel.text = "📊 Responses due \(fmt.string(from: meetup.deadline))"
            statusLabel.textColor = .systemOrange
        } else {
            statusLabel.text = "⏰ Response period ended"
            statusLabel.textColor = .systemRed
        }

        participantsHeightConstraint = participantsTableView.heightAnchor.constraint(equalToConstant: 0)
        commonHeightConstraint       = commonTableView.heightAnchor.constraint(equalToConstant: 0)

        view.addSubview(titleLabel)
        view.addSubview(statusLabel)
        view.addSubview(participantsLabel)
        view.addSubview(participantsTableView)
        view.addSubview(commonLabel)
        view.addSubview(commonTableView)
        view.addSubview(noCommonLabel)
        view.addSubview(finalizeButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            participantsLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            participantsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            participantsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            participantsTableView.topAnchor.constraint(equalTo: participantsLabel.bottomAnchor, constant: 8),
            participantsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            participantsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            participantsHeightConstraint,

            commonLabel.topAnchor.constraint(equalTo: participantsTableView.bottomAnchor, constant: 20),
            commonLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            commonLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            commonTableView.topAnchor.constraint(equalTo: commonLabel.bottomAnchor, constant: 8),
            commonTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            commonTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            commonHeightConstraint,

            noCommonLabel.topAnchor.constraint(equalTo: commonLabel.bottomAnchor, constant: 20),
            noCommonLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            noCommonLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            finalizeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            finalizeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            finalizeButton.widthAnchor.constraint(equalToConstant: 160),
            finalizeButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func updateDynamicUI() {
        let rowCount   = isFullDay ? commonDays.count : commonSlots.count
        let hasCommon  = rowCount > 0
        let canFinalize = hasCommon && !meetup.isFinalized

        participantsHeightConstraint.constant = CGFloat(max(1, meetup.availabilities.count) * 50)
        commonTableView.isHidden  = !hasCommon
        noCommonLabel.isHidden    = hasCommon
        finalizeButton.isHidden   = !canFinalize

        if hasCommon {
            commonHeightConstraint.constant = CGFloat(min(rowCount, 5) * 60)
        }
        view.layoutIfNeeded()
    }

    // MARK: - Finalize

    @objc private func finalizeTapped() {
        if isFullDay {
            finalizeFullDay()
        } else {
            finalizeTimed()
        }
    }

    private func finalizeFullDay() {
        guard !commonDays.isEmpty else { return }
        let fmt = DateFormatter()
        fmt.dateStyle = .full

        let alert = UIAlertController(title: "Finalize Meetup", message: "Pick the best day", preferredStyle: .actionSheet)
        for day in commonDays {
            alert.addAction(UIAlertAction(title: fmt.string(from: day), style: .default) { [weak self] _ in
                guard let self else { return }
                let cal = Calendar.current
                let slot = TimeSlot(start: day, end: cal.date(byAdding: .day, value: 1, to: day)!)
                self.showFinalizedAlert(fmt.string(from: day))
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = alert.popoverPresentationController {
            pop.sourceView = finalizeButton; pop.sourceRect = finalizeButton.bounds
        }
        present(alert, animated: true)
    }

    private func finalizeTimed() {
        guard !commonSlots.isEmpty else { return }
        let fmt = DateFormatter()
        fmt.dateStyle = .medium; fmt.timeStyle = .short

        let alert = UIAlertController(title: "Finalize Meetup", message: "Pick the best time", preferredStyle: .actionSheet)
        for slot in commonSlots {
            alert.addAction(UIAlertAction(title: fmt.string(from: slot.start), style: .default) { [weak self] _ in
                self?.showFinalizedAlert(fmt.string(from: slot.start))
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = alert.popoverPresentationController {
            pop.sourceView = finalizeButton; pop.sourceRect = finalizeButton.bounds
        }
        present(alert, animated: true)
    }

    private func showFinalizedAlert(_ dateString: String) {
        let alert = UIAlertController(
            title: "Meetup Finalized! 🎉",
            message: "Scheduled for \(dateString)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in self.dismiss(animated: true) })
        present(alert, animated: true)
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
            let cell = tableView.dequeueReusableCell(withIdentifier: "ParticipantCell", for: indexPath) as! ParticipantCell
            cell.configure(with: meetup.availabilities[indexPath.row])
            return cell
        }
        if isFullDay {
            let cell = tableView.dequeueReusableCell(withIdentifier: "CommonDayCell", for: indexPath) as! CommonDayCell
            cell.configure(with: commonDays[indexPath.row])
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "AvailableSlotCell", for: indexPath) as! AvailableSlotCell
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
    private let nameLabel  = ParticipantCell.makeLabel(size: 16, weight: .medium)
    private let slotsLabel = ParticipantCell.makeLabel(size: 14, color: .secondaryLabel)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(nameLabel); contentView.addSubview(slotsLabel)
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            slotsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            slotsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            slotsLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            slotsLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(with a: UserAvailability) {
        nameLabel.text  = a.userName
        slotsLabel.text = "\(a.availableSlots.count) day(s) available"
    }

    private static func makeLabel(size: CGFloat, weight: UIFont.Weight = .regular, color: UIColor = .label) -> UILabel {
        let l = UILabel(); l.font = .systemFont(ofSize: size, weight: weight); l.textColor = color; l.translatesAutoresizingMaskIntoConstraints = false; return l
    }
}

class CommonDayCell: UITableViewCell {
    private let label = UILabel()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    func configure(with date: Date) {
        let fmt = DateFormatter(); fmt.dateStyle = .full
        label.text = "🟢 \(fmt.string(from: date))"
    }
}

class AvailableSlotCell: UITableViewCell {
    private let timeLabel     = AvailableSlotCell.makeLabel(size: 16, weight: .medium)
    private let durationLabel = AvailableSlotCell.makeLabel(size: 14, color: .systemBlue)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(timeLabel); contentView.addSubview(durationLabel)
        NSLayoutConstraint.activate([
            timeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            timeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            durationLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            durationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            durationLabel.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 4),
            durationLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(with slot: TimeSlot) {
        let fmt = DateFormatter(); fmt.dateStyle = .medium; fmt.timeStyle = .short
        timeLabel.text = fmt.string(from: slot.start)
        let h = Int(slot.duration / 3600), m = Int(slot.duration.truncatingRemainder(dividingBy: 3600) / 60)
        durationLabel.text = h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private static func makeLabel(size: CGFloat, weight: UIFont.Weight = .regular, color: UIColor = .label) -> UILabel {
        let l = UILabel(); l.font = .systemFont(ofSize: size, weight: weight); l.textColor = color; l.translatesAutoresizingMaskIntoConstraints = false; return l
    }
}
