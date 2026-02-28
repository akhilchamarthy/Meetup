//
//  AvailabilityViewController.swift
//  Meetup MessagesExtension
//
//  Created by Akhil Chamarthy on 2/28/26.
//

import UIKit

protocol AvailabilityViewControllerDelegate: AnyObject {
    func didSubmitAvailability(_ availability: UserAvailability)
}

// MARK: - Day state

fileprivate enum DayState {
    case neutral    // not yet tapped — outside range or unset
    case available  // green
    case unavailable // red
}

// MARK: - AvailabilityViewController

class AvailabilityViewController: UIViewController {

    weak var delegate: AvailabilityViewControllerDelegate?

    private let meetup: Meetup
    private let currentUserId: String
    private let currentUserName: String

    // Calendar data
    private var daysInRange: [Date] = []          // all dates in the meetup window
    private var dayStates: [Date: DayState] = [:]  // keyed by start-of-day

    // MARK: - UI

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 20, weight: .semibold)
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let legendStack: UIStackView = {
        let green = AvailabilityViewController.legendDot(color: .systemGreen, text: "Available")
        let red   = AvailabilityViewController.legendDot(color: .systemRed,   text: "Unavailable")
        let hint  = AvailabilityViewController.legendDot(color: .systemGray4, text: "Tap to toggle")
        let sv = UIStackView(arrangedSubviews: [green, red, hint])
        sv.axis = .horizontal
        sv.spacing = 16
        sv.alignment = .center
        sv.distribution = .equalSpacing
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // Weekday header (S M T W T F S)
    private let weekdayHeaderStack: UIStackView = {
        let days = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        let labels = days.map { d -> UILabel in
            let l = UILabel()
            l.text = d
            l.font = .systemFont(ofSize: 12, weight: .semibold)
            l.textColor = .secondaryLabel
            l.textAlignment = .center
            return l
        }
        let sv = UIStackView(arrangedSubviews: labels)
        sv.axis = .horizontal
        sv.distribution = .fillEqually
        sv.spacing = 4
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private lazy var calendarCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 4
        layout.minimumLineSpacing = 6
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.delegate   = self
        cv.dataSource = self
        cv.isScrollEnabled = false
        cv.register(CalendarDayCell.self, forCellWithReuseIdentifier: CalendarDayCell.reuseID)
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    // Dynamic height constraint updated after layout
    private var calendarHeightConstraint: NSLayoutConstraint!

    private let submitButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Submit Availability", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        b.backgroundColor = .systemBlue
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 25
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        return b
    }()

    // MARK: - Init

    init(meetup: Meetup, currentUserId: String, currentUserName: String) {
        self.meetup = meetup
        self.currentUserId = currentUserId
        self.currentUserName = currentUserName
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        buildDaysInRange()
        setupUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCalendarHeight()
    }

    // MARK: - Data

    private func buildDaysInRange() {
        let cal = Calendar.current
        var current = cal.startOfDay(for: meetup.startDateRange)
        let end     = cal.startOfDay(for: meetup.endDateRange)
        while current <= end {
            daysInRange.append(current)
            dayStates[current] = .available
            current = cal.date(byAdding: .day, value: 1, to: current)!
        }
    }

    // MARK: - Layout

    private func setupUI() {
        view.backgroundColor = .systemBackground

        titleLabel.text = "\(meetup.type.icon) \(meetup.title)"

        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        subtitleLabel.text = "\(fmt.string(from: meetup.startDateRange)) – \(fmt.string(from: meetup.endDateRange))"

        calendarHeightConstraint = calendarCollectionView.heightAnchor.constraint(equalToConstant: 200)

        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(legendStack)
        view.addSubview(weekdayHeaderStack)
        view.addSubview(calendarCollectionView)
        view.addSubview(submitButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            legendStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            legendStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            legendStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            weekdayHeaderStack.topAnchor.constraint(equalTo: legendStack.bottomAnchor, constant: 14),
            weekdayHeaderStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            weekdayHeaderStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            weekdayHeaderStack.heightAnchor.constraint(equalToConstant: 20),

            calendarCollectionView.topAnchor.constraint(equalTo: weekdayHeaderStack.bottomAnchor, constant: 6),
            calendarCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            calendarCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            calendarHeightConstraint,

            submitButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            submitButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            submitButton.widthAnchor.constraint(equalToConstant: 200),
            submitButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    /// Recalculate the collection view height so it never scrolls.
    private func updateCalendarHeight() {
        guard calendarCollectionView.frame.width > 0 else { return }
        let cellWidth  = (calendarCollectionView.frame.width - 6 * 4) / 7   // 7 columns, 4pt gaps
        let cellHeight = cellWidth * 1.1
        let lineSpacing: CGFloat = 6

        let firstWeekday = weekdayIndex(for: daysInRange.first ?? Date())
        let totalCells   = firstWeekday + daysInRange.count
        let rows         = CGFloat(Int(ceil(Double(totalCells) / 7.0)))
        let newHeight    = rows * (cellHeight + lineSpacing) - lineSpacing

        if abs(calendarHeightConstraint.constant - newHeight) > 1 {
            calendarHeightConstraint.constant = newHeight
            view.layoutIfNeeded()
        }
    }

    // MARK: - Actions

    @objc private func submitTapped() {
        let available   = daysInRange.filter { dayStates[$0] == .available }
        let unavailable = daysInRange.filter { dayStates[$0] == .unavailable }

        guard !available.isEmpty else {
            showAlert(title: "No Availability",
                      message: "Please mark at least one day as available (green).")
            return
        }

        let cal = Calendar.current
        let availableSlots = available.map { day -> TimeSlot in
            let end = cal.date(byAdding: .day, value: 1, to: day)!
            return TimeSlot(start: day, end: end)
        }
        let busySlots = unavailable.map { day -> TimeSlot in
            let end = cal.date(byAdding: .day, value: 1, to: day)!
            return TimeSlot(start: day, end: end)
        }

        let availability = UserAvailability(
            userId: currentUserId,
            userName: currentUserName,
            availableSlots: availableSlots,
            busySlots: busySlots,
            responseDate: Date()
        )
        delegate?.didSubmitAvailability(availability)
    }

    // MARK: - Helpers

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    /// Returns 0-based Sunday-first weekday index for a given date.
    private func weekdayIndex(for date: Date) -> Int {
        let cal = Calendar.current
        return (cal.component(.weekday, from: date) - 1)  // 1=Sun → 0
    }

    private static func legendDot(color: UIColor, text: String) -> UIView {
        let dot = UIView()
        dot.backgroundColor = color
        dot.layer.cornerRadius = 6
        dot.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 12),
            dot.heightAnchor.constraint(equalToConstant: 12)
        ])

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [dot, label])
        stack.axis = .horizontal
        stack.spacing = 5
        stack.alignment = .center
        return stack
    }
}

// MARK: - UICollectionView

extension AvailabilityViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    /// Total items = leading empty cells (to align first day to correct weekday) + actual days
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let offset = weekdayIndex(for: daysInRange.first ?? Date())
        return offset + daysInRange.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: CalendarDayCell.reuseID, for: indexPath) as! CalendarDayCell
        let offset = weekdayIndex(for: daysInRange.first ?? Date())
        let dayIndex = indexPath.item - offset

        if dayIndex < 0 {
            cell.configureEmpty()   // blank padding cell
        } else {
            let date = daysInRange[dayIndex]
            cell.configure(with: date, state: dayStates[date] ?? .neutral)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.frame.width - 6 * 4) / 7
        return CGSize(width: width, height: width * 1.1)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let offset = weekdayIndex(for: daysInRange.first ?? Date())
        let dayIndex = indexPath.item - offset
        guard dayIndex >= 0 else { return }

        let date = daysInRange[dayIndex]
        switch dayStates[date] ?? .available {
        case .neutral, .unavailable:
            dayStates[date] = .available
        case .available:
            dayStates[date] = .unavailable
        }
        collectionView.reloadItems(at: [indexPath])
    }
}

// MARK: - CalendarDayCell

class CalendarDayCell: UICollectionViewCell {

    static let reuseID = "CalendarDayCell"

    private let dayLabel: UILabel = {          // e.g. "Mon"
        let l = UILabel()
        l.font = .systemFont(ofSize: 10, weight: .medium)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let dateLabel: UILabel = {         // e.g. "14"
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .semibold)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 8
        contentView.clipsToBounds = true
        contentView.addSubview(dayLabel)
        contentView.addSubview(dateLabel)
        NSLayoutConstraint.activate([
            dayLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            dayLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            dayLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),

            dateLabel.topAnchor.constraint(equalTo: dayLabel.bottomAnchor, constant: 2),
            dateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            dateLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configureEmpty() {
        dayLabel.text = nil
        dateLabel.text = nil
        contentView.backgroundColor = .clear
    }

    fileprivate func configure(with date: Date, state: DayState) {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        dayLabel.text = fmt.string(from: date)
        fmt.dateFormat = "d"
        dateLabel.text = fmt.string(from: date)

        switch state {
        case .neutral:
            contentView.backgroundColor = .systemGray6
            dayLabel.textColor  = .secondaryLabel
            dateLabel.textColor = .label
        case .available:
            contentView.backgroundColor = .systemGreen
            dayLabel.textColor  = .white
            dateLabel.textColor = .white
        case .unavailable:
            contentView.backgroundColor = .systemRed
            dayLabel.textColor  = .white
            dateLabel.textColor = .white
        }
    }
}