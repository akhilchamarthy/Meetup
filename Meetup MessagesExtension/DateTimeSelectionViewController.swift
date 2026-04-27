//
//  DateTimeSelectionViewController.swift
//  Meetup MessagesExtension
//
//  Created by Akhil Chamarthy on 2/28/26.
//

import UIKit

protocol DateTimeSelectionViewControllerDelegate: AnyObject {
    func didSelectDateTime(startDate: Date, endDate: Date, duration: TimeInterval?, deadline: Date)
}

class DateTimeSelectionViewController: UIViewController {

    weak var delegate: DateTimeSelectionViewControllerDelegate?

    private let meetupTitle: String
    private let meetupType: MeetupType

    // MARK: - Palette

    private static let blue = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
    private static let blueTint = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 0.10)
    private static let bg = UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1)
    private static let ink = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1)

    // MARK: - Nav bar

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
        let dots = [makeDot(filled: true), makeDot(filled: true), makeDot(filled: true)]
        let sv = UIStackView(arrangedSubviews: dots)
        sv.axis = .horizontal; sv.spacing = 6; sv.alignment = .center
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // MARK: - Header

    private let headlineLabel: UILabel = {
        let l = UILabel()
        l.text = "When is the meetup?"
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

    // MARK: - Scroll + content

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

    // MARK: - Date range card

    private let dateRangeCard = DateTimeSelectionViewController.makeCard()

    private let startDatePrompt = DateTimeSelectionViewController.makePromptLabel("Start date")
    private let startDatePicker: UIDatePicker = {
        let p = UIDatePicker()
        p.datePickerMode = .date
        p.minimumDate = Date()
        p.preferredDatePickerStyle = .compact
        p.tintColor = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
        p.translatesAutoresizingMaskIntoConstraints = false
        return p
    }()

    private let dateRangeDivider = DateTimeSelectionViewController.makeDivider()

    private let endDatePrompt = DateTimeSelectionViewController.makePromptLabel("End date")
    private let endDatePicker: UIDatePicker = {
        let p = UIDatePicker()
        p.datePickerMode = .date
        p.minimumDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        p.preferredDatePickerStyle = .compact
        p.tintColor = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
        p.translatesAutoresizingMaskIntoConstraints = false
        return p
    }()

    // MARK: - Duration card (hidden for full-day)

    private let durationCard = DateTimeSelectionViewController.makeCard()

    private let durationCardTitle = DateTimeSelectionViewController.makeCardTitle("Meetup duration")

    private lazy var durationSegmentedControl: UISegmentedControl = {
        let c = UISegmentedControl(items: ["30m", "1h", "2h", "3h", "Custom"])
        c.selectedSegmentIndex = 1
        c.selectedSegmentTintColor = Self.blue
        c.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        c.setTitleTextAttributes([.foregroundColor: Self.ink], for: .normal)
        c.addTarget(self, action: #selector(durationChanged), for: .valueChanged)
        c.translatesAutoresizingMaskIntoConstraints = false
        return c
    }()

    private let customDurationTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Enter minutes"
        tf.borderStyle = .none
        tf.keyboardType = .numberPad
        tf.font = UIFont.systemFont(ofSize: 16)
        tf.isHidden = true
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let customDurationUnderline: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.systemGray4
        v.isHidden = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - Deadline card

    private let deadlineCard = DateTimeSelectionViewController.makeCard()

    private let deadlineCardTitle = DateTimeSelectionViewController.makeCardTitle("Response deadline")

    private lazy var deadlinePicker: UIDatePicker = {
        let p = UIDatePicker()
        p.datePickerMode = .dateAndTime
        p.minimumDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
        p.preferredDatePickerStyle = .compact
        p.tintColor = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
        p.translatesAutoresizingMaskIntoConstraints = false
        return p
    }()

    // MARK: - CTA button

    private let createButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Create Meetup", for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        b.backgroundColor = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 14
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(createButtonTapped), for: .touchUpInside)
        return b
    }()

    // MARK: - Computed duration

    private var selectedDuration: TimeInterval? {
        guard !meetupType.isFullDay else { return nil }
        switch durationSegmentedControl.selectedSegmentIndex {
        case 0: return 30 * 60
        case 1: return 60 * 60
        case 2: return 2 * 60 * 60
        case 3: return 3 * 60 * 60
        case 4:
            if let text = customDurationTextField.text, let mins = Double(text) { return mins * 60 }
            return 60 * 60
        default: return 60 * 60
        }
    }

    // MARK: - Init

    init(meetupTitle: String, meetupType: MeetupType) {
        self.meetupTitle = meetupTitle
        self.meetupType = meetupType
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Self.bg
        subheadLabel.text = "\(meetupType.icon)  \(meetupTitle)"
        customDurationTextField.delegate = self
        setupUI()
        setupDefaultDates()
        startDatePicker.addTarget(self, action: #selector(startDateChanged), for: .valueChanged)
    }

    // MARK: - Layout

    private func setupUI() {
        // Hide duration for full-day types
        durationCard.isHidden = meetupType.isFullDay

        // --- Date range card internals ---
        buildDateRangeCard()

        // --- Duration card internals ---
        buildDurationCard()

        // --- Deadline card internals ---
        buildDeadlineCard()

        // Add cards to scroll stack
        [dateRangeCard, durationCard, deadlineCard].forEach { contentStack.addArrangedSubview($0) }

        scrollView.addSubview(contentStack)
        view.addSubview(backButton)
        view.addSubview(progressStack)
        view.addSubview(headlineLabel)
        view.addSubview(subheadLabel)
        view.addSubview(scrollView)
        view.addSubview(createButton)

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

            scrollView.topAnchor.constraint(equalTo: subheadLabel.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: createButton.topAnchor, constant: -12),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 4),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),

            createButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            createButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            createButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            createButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    private func buildDateRangeCard() {
        let startRow = makePickerRow(prompt: startDatePrompt, picker: startDatePicker)
        let endRow   = makePickerRow(prompt: endDatePrompt,   picker: endDatePicker)

        [DateTimeSelectionViewController.makeCardTitle("Date range"), startRow, dateRangeDivider, endRow].forEach {
            dateRangeCard.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        let cardTitle = dateRangeCard.subviews.first!
        NSLayoutConstraint.activate([
            cardTitle.topAnchor.constraint(equalTo: dateRangeCard.topAnchor, constant: 16),
            cardTitle.leadingAnchor.constraint(equalTo: dateRangeCard.leadingAnchor, constant: 16),
            cardTitle.trailingAnchor.constraint(equalTo: dateRangeCard.trailingAnchor, constant: -16),

            startRow.topAnchor.constraint(equalTo: cardTitle.bottomAnchor, constant: 12),
            startRow.leadingAnchor.constraint(equalTo: dateRangeCard.leadingAnchor, constant: 16),
            startRow.trailingAnchor.constraint(equalTo: dateRangeCard.trailingAnchor, constant: -16),

            dateRangeDivider.topAnchor.constraint(equalTo: startRow.bottomAnchor, constant: 12),
            dateRangeDivider.leadingAnchor.constraint(equalTo: dateRangeCard.leadingAnchor, constant: 16),
            dateRangeDivider.trailingAnchor.constraint(equalTo: dateRangeCard.trailingAnchor, constant: -16),
            dateRangeDivider.heightAnchor.constraint(equalToConstant: 1),

            endRow.topAnchor.constraint(equalTo: dateRangeDivider.bottomAnchor, constant: 12),
            endRow.leadingAnchor.constraint(equalTo: dateRangeCard.leadingAnchor, constant: 16),
            endRow.trailingAnchor.constraint(equalTo: dateRangeCard.trailingAnchor, constant: -16),
            endRow.bottomAnchor.constraint(equalTo: dateRangeCard.bottomAnchor, constant: -16),
        ])
    }

    private func buildDurationCard() {
        let title = Self.makeCardTitle("Meetup duration")
        [title, durationSegmentedControl, customDurationTextField, customDurationUnderline].forEach {
            durationCard.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: durationCard.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: durationCard.leadingAnchor, constant: 16),
            title.trailingAnchor.constraint(equalTo: durationCard.trailingAnchor, constant: -16),

            durationSegmentedControl.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 12),
            durationSegmentedControl.leadingAnchor.constraint(equalTo: durationCard.leadingAnchor, constant: 16),
            durationSegmentedControl.trailingAnchor.constraint(equalTo: durationCard.trailingAnchor, constant: -16),

            customDurationTextField.topAnchor.constraint(equalTo: durationSegmentedControl.bottomAnchor, constant: 12),
            customDurationTextField.leadingAnchor.constraint(equalTo: durationCard.leadingAnchor, constant: 16),
            customDurationTextField.trailingAnchor.constraint(equalTo: durationCard.trailingAnchor, constant: -16),
            customDurationTextField.heightAnchor.constraint(equalToConstant: 36),

            customDurationUnderline.topAnchor.constraint(equalTo: customDurationTextField.bottomAnchor, constant: 2),
            customDurationUnderline.leadingAnchor.constraint(equalTo: durationCard.leadingAnchor, constant: 16),
            customDurationUnderline.trailingAnchor.constraint(equalTo: durationCard.trailingAnchor, constant: -16),
            customDurationUnderline.heightAnchor.constraint(equalToConstant: 1),
            customDurationUnderline.bottomAnchor.constraint(equalTo: durationCard.bottomAnchor, constant: -16),
        ])
    }

    private func buildDeadlineCard() {
        let title = Self.makeCardTitle("Response deadline")
        let row   = makePickerRow(prompt: Self.makePromptLabel("Deadline"), picker: deadlinePicker)
        [title, row].forEach {
            deadlineCard.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: deadlineCard.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: deadlineCard.leadingAnchor, constant: 16),
            title.trailingAnchor.constraint(equalTo: deadlineCard.trailingAnchor, constant: -16),

            row.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: deadlineCard.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: deadlineCard.trailingAnchor, constant: -16),
            row.bottomAnchor.constraint(equalTo: deadlineCard.bottomAnchor, constant: -16),
        ])
    }

    // MARK: - Actions

    @objc private func backTapped() {
        NotificationCenter.default.post(name: .meetupGoBack, object: nil)
    }

    @objc private func startDateChanged() {
        endDatePicker.minimumDate = Calendar.current.date(byAdding: .day, value: 1, to: startDatePicker.date)
    }

    @objc private func durationChanged() {
        let isCustom = durationSegmentedControl.selectedSegmentIndex == 4
        customDurationTextField.isHidden   = !isCustom
        customDurationUnderline.isHidden   = !isCustom
        if isCustom { customDurationTextField.becomeFirstResponder() }
    }

    @objc private func createButtonTapped() {
        let startDate = startDatePicker.date
        let endDate   = endDatePicker.date
        let deadline  = deadlinePicker.date

        guard startDate < endDate else {
            showAlert(title: "Invalid Dates", message: "End date must be after start date.")
            return
        }
        guard deadline > Date() else {
            showAlert(title: "Invalid Deadline", message: "Deadline must be in the future.")
            return
        }

        UIView.animate(withDuration: 0.1, animations: {
            self.createButton.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
        }) { _ in
            UIView.animate(withDuration: 0.1) { self.createButton.transform = .identity }
            self.delegate?.didSelectDateTime(startDate: startDate, endDate: endDate,
                                             duration: self.selectedDuration, deadline: deadline)
        }
    }

    // MARK: - Defaults

    private func setupDefaultDates() {
        let cal = Calendar.current
        startDatePicker.date = cal.date(byAdding: .day, value: 1, to: Date())!
        endDatePicker.date   = cal.date(byAdding: .day, value: 7, to: Date())!
        deadlinePicker.date  = cal.date(byAdding: .hour, value: 24, to: Date())!
    }

    // MARK: - Helpers

    /// A horizontal row with a label on the left and a picker on the right
    private func makePickerRow(prompt: UILabel, picker: UIDatePicker) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(prompt)
        row.addSubview(picker)
        prompt.translatesAutoresizingMaskIntoConstraints = false
        picker.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            prompt.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            prompt.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            prompt.trailingAnchor.constraint(lessThanOrEqualTo: picker.leadingAnchor, constant: -8),

            picker.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            picker.topAnchor.constraint(equalTo: row.topAnchor),
            picker.bottomAnchor.constraint(equalTo: row.bottomAnchor),
        ])
        return row
    }

    private func showAlert(title: String, message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
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

    // MARK: - Factory helpers (static)

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

    private static func makePromptLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        l.textColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    private static func makeDivider() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.systemGray5
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }
}

// MARK: - UITextFieldDelegate

extension DateTimeSelectionViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: string))
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
