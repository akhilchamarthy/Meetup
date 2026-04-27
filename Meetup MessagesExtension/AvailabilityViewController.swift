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
    case available
    case unavailable
}

// MARK: - AvailabilityViewController

class AvailabilityViewController: UIViewController {

    weak var delegate: AvailabilityViewControllerDelegate?

    private let meetup: Meetup
    private let currentUserId: String
    private let currentUserName: String

    // Calendar data
    private var daysInRange: [Date] = []
    private var dayStates: [Date: DayState] = [:]

    // MARK: - Palette

    private static let blue    = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
    private static let bg      = UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1)
    private static let ink     = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1)

    // MARK: - Nav

    private lazy var backButton: UIButton = {
        let b = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        b.setImage(UIImage(systemName: "chevron.left", withConfiguration: cfg), for: .normal)
        b.tintColor = Self.blue
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        return b
    }()

    private lazy var progressStack: UIStackView = {
        let dots = [makeDot(filled: true), makeDot(filled: true), makeDot(filled: true), makeDot(filled: true)]
        let sv = UIStackView(arrangedSubviews: dots)
        sv.axis = .horizontal; sv.spacing = 6; sv.alignment = .center
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // MARK: - Header

    private let headlineLabel: UILabel = {
        let l = UILabel()
        l.text = "Mark your availability"
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

    // MARK: - Calendar card

    private let calendarCard: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.layer.cornerRadius = 16
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.06
        v.layer.shadowRadius = 8
        v.layer.shadowOffset = CGSize(width: 0, height: 2)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let legendStack: UIStackView = {
        let green = AvailabilityViewController.legendItem(color: .systemGreen, text: "Available")
        let red   = AvailabilityViewController.legendItem(color: .systemRed, text: "Unavailable")
        let sv = UIStackView(arrangedSubviews: [green, red])
        sv.axis = .horizontal; sv.spacing = 20; sv.alignment = .center
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let weekdayHeaderStack: UIStackView = {
        let days = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        let labels = days.map { d -> UILabel in
            let l = UILabel()
            l.text = d
            l.font = .systemFont(ofSize: 11, weight: .semibold)
            l.textColor = .black
            l.textAlignment = .center
            return l
        }
        let sv = UIStackView(arrangedSubviews: labels)
        sv.axis = .horizontal; sv.distribution = .fillEqually; sv.spacing = 4
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
        cv.isScrollEnabled = true
        cv.register(CalendarDayCell.self, forCellWithReuseIdentifier: CalendarDayCell.reuseID)
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private var calendarHeightConstraint: NSLayoutConstraint!

    // MARK: - Submit

    private let submitButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Submit Availability", for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        b.backgroundColor = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 14
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
        view.backgroundColor = Self.bg
        buildDaysInRange()
        setupUI()

        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        subheadLabel.text = "\(meetup.type.icon)  \(fmt.string(from: meetup.startDateRange)) – \(fmt.string(from: meetup.endDateRange))"
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
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
        calendarHeightConstraint = calendarCollectionView.heightAnchor.constraint(equalToConstant: 400)

        // Assemble calendar card
        calendarCard.addSubview(legendStack)
        calendarCard.addSubview(weekdayHeaderStack)
        calendarCard.addSubview(calendarCollectionView)

        view.addSubview(backButton)
        view.addSubview(progressStack)
        view.addSubview(headlineLabel)
        view.addSubview(subheadLabel)
        view.addSubview(calendarCard)
        view.addSubview(submitButton)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),

            progressStack.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            progressStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            headlineLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 16),
            headlineLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headlineLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            subheadLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 4),
            subheadLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subheadLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Calendar card
            calendarCard.topAnchor.constraint(equalTo: subheadLabel.bottomAnchor, constant: 16),
            calendarCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            calendarCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            calendarCard.bottomAnchor.constraint(equalTo: submitButton.topAnchor, constant: -8),

            legendStack.topAnchor.constraint(equalTo: calendarCard.topAnchor, constant: 12),
            legendStack.centerXAnchor.constraint(equalTo: calendarCard.centerXAnchor),

            weekdayHeaderStack.topAnchor.constraint(equalTo: legendStack.bottomAnchor, constant: 8),
            weekdayHeaderStack.leadingAnchor.constraint(equalTo: calendarCard.leadingAnchor, constant: 12),
            weekdayHeaderStack.trailingAnchor.constraint(equalTo: calendarCard.trailingAnchor, constant: -12),
            weekdayHeaderStack.heightAnchor.constraint(equalToConstant: 20),

            calendarCollectionView.topAnchor.constraint(equalTo: weekdayHeaderStack.bottomAnchor, constant: 6),
            calendarCollectionView.leadingAnchor.constraint(equalTo: calendarCard.leadingAnchor, constant: 12),
            calendarCollectionView.trailingAnchor.constraint(equalTo: calendarCard.trailingAnchor, constant: -12),
            calendarHeightConstraint,
            calendarCollectionView.bottomAnchor.constraint(equalTo: calendarCard.bottomAnchor, constant: -16),

            submitButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            submitButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            submitButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            submitButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    // MARK: - Actions

    @objc private func backTapped() {
        NotificationCenter.default.post(name: .meetupGoBack, object: nil)
    }

    @objc private func submitTapped() {
        let available   = daysInRange.filter { dayStates[$0] == .available }
        let unavailable = daysInRange.filter { dayStates[$0] == .unavailable }

        guard !available.isEmpty else {
            showAlert(title: "No Availability",
                      message: "Please mark at least one day as available.")
            return
        }

        let cal = Calendar.current
        let availableSlots = available.map { day -> TimeSlot in
            TimeSlot(start: day, end: cal.date(byAdding: .day, value: 1, to: day)!)
        }
        let busySlots = unavailable.map { day -> TimeSlot in
            TimeSlot(start: day, end: cal.date(byAdding: .day, value: 1, to: day)!)
        }

        let availability = UserAvailability(
            userId: currentUserId,
            userName: currentUserName,
            availableSlots: availableSlots,
            busySlots: busySlots,
            responseDate: Date()
        )

        UIView.animate(withDuration: 0.1, animations: {
            self.submitButton.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
        }) { _ in
            UIView.animate(withDuration: 0.1) { self.submitButton.transform = .identity }
            self.delegate?.didSubmitAvailability(availability)
        }
    }

    // MARK: - Helpers

    private func showAlert(title: String, message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    private func weekdayIndex(for date: Date) -> Int {
        (Calendar.current.component(.weekday, from: date) - 1)
    }

    private func makeDot(filled: Bool) -> UIView {
        let v = UIView()
        v.backgroundColor = filled ? Self.blue : UIColor.systemGray4
        let size: CGFloat = filled ? 8 : 6
        v.layer.cornerRadius = size / 2
        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(equalToConstant: size).isActive = true
        v.heightAnchor.constraint(equalToConstant: size).isActive = true
        return v
    }

    private static func legendItem(color: UIColor, text: String) -> UIView {
        let dot = UIView()
        dot.backgroundColor = color
        dot.layer.cornerRadius = 5
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 10).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 10).isActive = true

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .black

        let sv = UIStackView(arrangedSubviews: [dot, label])
        sv.axis = .horizontal; sv.spacing = 6; sv.alignment = .center
        return sv
    }
}

// MARK: - UICollectionView

extension AvailabilityViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        weekdayIndex(for: daysInRange.first ?? Date()) + daysInRange.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: CalendarDayCell.reuseID, for: indexPath) as! CalendarDayCell
        let offset   = weekdayIndex(for: daysInRange.first ?? Date())
        let dayIndex = indexPath.item - offset
        if dayIndex < 0 {
            cell.configureEmpty()
        } else {
            let date = daysInRange[dayIndex]
            cell.configure(with: date, state: dayStates[date] ?? .available)
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
        let offset   = weekdayIndex(for: daysInRange.first ?? Date())
        let dayIndex = indexPath.item - offset
        guard dayIndex >= 0 else { return }
        let date = daysInRange[dayIndex]
        dayStates[date] = (dayStates[date] == .available) ? .unavailable : .available
        collectionView.reloadItems(at: [indexPath])
    }
}

// MARK: - CalendarDayCell

class CalendarDayCell: UICollectionViewCell {

    static let reuseID = "CalendarDayCell"

    private let dayLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 10, weight: .medium)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let dateLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .semibold)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 10
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
            dateLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configureEmpty() {
        dayLabel.text = nil; dateLabel.text = nil
        contentView.backgroundColor = .clear
    }

    fileprivate func configure(with date: Date, state: DayState) {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        dayLabel.text = fmt.string(from: date)
        fmt.dateFormat = "d"
        dateLabel.text = fmt.string(from: date)

        switch state {
        case .available:
            contentView.backgroundColor = .systemGreen
            dayLabel.textColor  = .white
            dateLabel.textColor = .white
        case .unavailable:
            contentView.backgroundColor = .systemRed
            dayLabel.textColor  = .black
            dateLabel.textColor = .black
        }
    }
}
