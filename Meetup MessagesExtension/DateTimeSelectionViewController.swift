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

    // MARK: - UI

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
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

    // Start date
    private let startDateLabel = DateTimeSelectionViewController.sectionLabel("Start Date Range")
    private let startDatePicker: UIDatePicker = {
        let p = UIDatePicker()
        p.datePickerMode = .date
        p.minimumDate = Date()
        p.translatesAutoresizingMaskIntoConstraints = false
        return p
    }()

    // End date
    private let endDateLabel = DateTimeSelectionViewController.sectionLabel("End Date Range")
    private let endDatePicker: UIDatePicker = {
        let p = UIDatePicker()
        p.datePickerMode = .date
        p.minimumDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        p.translatesAutoresizingMaskIntoConstraints = false
        return p
    }()

    // Duration (hidden for full-day types)
    private lazy var durationSectionView: UIStackView = {
        let sv = UIStackView(arrangedSubviews: [durationLabel, durationSegmentedControl, customDurationTextField])
        sv.axis = .vertical
        sv.spacing = 10
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    private let durationLabel = DateTimeSelectionViewController.sectionLabel("Meetup Duration")
    private lazy var durationSegmentedControl: UISegmentedControl = {
        let c = UISegmentedControl(items: ["30 min", "1 hr", "2 hr", "3 hr", "Custom"])
        c.selectedSegmentIndex = 1
        c.addTarget(self, action: #selector(durationChanged), for: .valueChanged)
        c.translatesAutoresizingMaskIntoConstraints = false
        return c
    }()
    private let customDurationTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Enter minutes"
        tf.borderStyle = .roundedRect
        tf.keyboardType = .numberPad
        tf.isHidden = true
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    // Deadline
    private let deadlineLabel = DateTimeSelectionViewController.sectionLabel("Response Deadline")
    private lazy var deadlinePicker: UIDatePicker = {
        let p = UIDatePicker()
        p.datePickerMode = .dateAndTime
        p.minimumDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
        p.translatesAutoresizingMaskIntoConstraints = false
        return p
    }()

    private let createButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Create Meetup", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        b.backgroundColor = .systemBlue
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 25
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
        setupUI()
        setupDefaultDates()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground
        titleLabel.text = "\(meetupType.icon) \(meetupTitle)"

        // Hide duration section for full-day meetup types
        durationSectionView.isHidden = meetupType.isFullDay

        // Build content stack
        [startDateLabel, startDatePicker,
         endDateLabel, endDatePicker,
         durationSectionView,
         deadlineLabel, deadlinePicker].forEach { contentStack.addArrangedSubview($0) }

        scrollView.addSubview(contentStack)
        view.addSubview(titleLabel)
        view.addSubview(scrollView)
        view.addSubview(createButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: createButton.topAnchor, constant: -16),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),

            startDatePicker.heightAnchor.constraint(equalToConstant: 120),
            endDatePicker.heightAnchor.constraint(equalToConstant: 120),
            deadlinePicker.heightAnchor.constraint(equalToConstant: 120),
            customDurationTextField.heightAnchor.constraint(equalToConstant: 44),

            createButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            createButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            createButton.widthAnchor.constraint(equalToConstant: 160),
            createButton.heightAnchor.constraint(equalToConstant: 50)
        ])

        startDatePicker.addTarget(self, action: #selector(startDateChanged), for: .valueChanged)
    }

    private func setupDefaultDates() {
        let cal = Calendar.current
        startDatePicker.date = cal.date(byAdding: .day, value: 1, to: Date())!
        endDatePicker.date   = cal.date(byAdding: .day, value: 7, to: Date())!
        deadlinePicker.date  = cal.date(byAdding: .hour, value: 24, to: Date())!
    }

    // MARK: - Actions

    @objc private func startDateChanged() {
        endDatePicker.minimumDate = Calendar.current.date(byAdding: .day, value: 1, to: startDatePicker.date)
    }

    @objc private func durationChanged() {
        let isCustom = durationSegmentedControl.selectedSegmentIndex == 4
        customDurationTextField.isHidden = !isCustom
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

        delegate?.didSelectDateTime(startDate: startDate, endDate: endDate,
                                    duration: selectedDuration, deadline: deadline)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Helpers

    private static func sectionLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 16, weight: .medium)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }
}

// MARK: - UITextFieldDelegate

extension DateTimeSelectionViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: string))
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder(); return true
    }
}
