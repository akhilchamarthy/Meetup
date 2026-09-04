//
//  MeetupTypeViewController.swift
//  Meetup MessagesExtension
//
//  Created by Akhil Chamarthy on 2/28/26.
//

import UIKit

protocol MeetupTypeViewControllerDelegate: AnyObject {
    func didSelectMeetupType(_ type: MeetupType)
}

class MeetupTypeViewController: UIViewController {

    weak var delegate: MeetupTypeViewControllerDelegate?

    private let meetupTitle: String

    // MARK: - UI

    private let backButton: UIButton = {
        let b = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        b.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
        b.tintColor = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        return b
    }()

    private let progressDot1 = MeetupTypeViewController.progressDot(filled: true)
    private let progressDot2 = MeetupTypeViewController.progressDot(filled: true)
    private let progressDot3 = MeetupTypeViewController.progressDot(filled: false)

    private lazy var progressStack: UIStackView = {
        let sv = UIStackView(arrangedSubviews: [progressDot1, progressDot2, progressDot3])
        sv.axis = .horizontal
        sv.spacing = 6
        sv.alignment = .center
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let headlineLabel: UILabel = {
        let l = UILabel()
        l.text = "What kind of meetup?"
        l.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        l.textColor = .label
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subheadLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 20)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.delegate = self
        cv.dataSource = self
        cv.register(MeetupTypeCell.self, forCellWithReuseIdentifier: "MeetupTypeCell")
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private let nextButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Next", for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        b.backgroundColor = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 14
        b.isEnabled = false
        b.alpha = 0.45
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
        return b
    }()

    private lazy var trashButton: UIButton = {
        let b = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        b.setImage(UIImage(systemName: "trash", withConfiguration: cfg), for: .normal)
        b.tintColor = .systemRed
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(trashTapped), for: .touchUpInside)
        return b
    }()

    private lazy var settingsButton: UIButton = {
        let b = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        b.setImage(UIImage(systemName: "gearshape", withConfiguration: cfg), for: .normal)
        b.tintColor = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        return b
    }()

    private var selectedType: MeetupType?

    // MARK: - Init

    init(meetupTitle: String) {
        self.meetupTitle = meetupTitle
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor { tc in tc.userInterfaceStyle == .dark ? .systemGroupedBackground : UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1) }
        subheadLabel.text = "\"\(meetupTitle)\""
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Slide-in from right
        collectionView.transform = CGAffineTransform(translationX: 40, y: 0)
        collectionView.alpha = 0
        UIView.animate(withDuration: 0.38, delay: 0.05, usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 0.2, options: .curveEaseOut) {
            self.collectionView.transform = .identity
            self.collectionView.alpha = 1
        }
    }

    // MARK: - Layout

    private func setupUI() {
        view.addSubview(backButton)
        view.addSubview(progressStack)
        view.addSubview(headlineLabel)
        view.addSubview(subheadLabel)
        view.addSubview(collectionView)
        view.addSubview(trashButton)
        view.addSubview(nextButton)
        view.addSubview(settingsButton)

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

            collectionView.topAnchor.constraint(equalTo: subheadLabel.bottomAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: nextButton.topAnchor, constant: -12),

            // Bottom bar: [trash 44] [8] [Next flex] [8] [settings 44]
            trashButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            trashButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            trashButton.widthAnchor.constraint(equalToConstant: 44),
            trashButton.heightAnchor.constraint(equalToConstant: 50),

            nextButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            nextButton.leadingAnchor.constraint(equalTo: trashButton.trailingAnchor, constant: 8),
            nextButton.trailingAnchor.constraint(equalTo: settingsButton.leadingAnchor, constant: -8),
            nextButton.heightAnchor.constraint(equalToConstant: 50),

            settingsButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            settingsButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            settingsButton.widthAnchor.constraint(equalToConstant: 44),
            settingsButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    // MARK: - Actions

    @objc private func backTapped() {
        NotificationCenter.default.post(name: .meetupGoBack, object: nil)
    }

    @objc private func trashTapped() {
        let alert = UIAlertController(title: "Discard Meetup?",
                                      message: "This will cancel the current meetup creation.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { _ in
            NotificationCenter.default.post(name: .meetupCancelCreation, object: nil)
        })
        alert.addAction(UIAlertAction(title: "Keep", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func settingsTapped() {
        // Profile-only — meetup type not yet chosen, so no meetup-specific settings yet.
        present(SettingsViewController(showMeetupSettings: false), animated: true)
    }

    @objc private func nextButtonTapped() {
        guard let selectedType = selectedType else { return }
        UIView.animate(withDuration: 0.1, animations: {
            self.nextButton.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
        }) { _ in
            UIView.animate(withDuration: 0.1) { self.nextButton.transform = .identity }
            self.delegate?.didSelectMeetupType(selectedType)
        }
    }

    private func updateNextButton() {
        UIView.animate(withDuration: 0.2) {
            self.nextButton.isEnabled = self.selectedType != nil
            self.nextButton.alpha = self.selectedType != nil ? 1.0 : 0.45
        }
    }

    // MARK: - Helpers

    private static func progressDot(filled: Bool) -> UIView {
        let v = UIView()
        v.backgroundColor = filled
            ? UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
            : UIColor.systemGray4
        v.layer.cornerRadius = filled ? 4 : 3
        v.translatesAutoresizingMaskIntoConstraints = false
        let size: CGFloat = filled ? 8 : 6
        v.widthAnchor.constraint(equalToConstant: size).isActive = true
        v.heightAnchor.constraint(equalToConstant: size).isActive = true
        return v
    }
}

// MARK: - Collection View

extension MeetupTypeViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        MeetupType.allCases.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "MeetupTypeCell", for: indexPath) as! MeetupTypeCell
        let type = MeetupType.allCases[indexPath.item]
        cell.configure(with: type, isSelected: selectedType == type)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let availableWidth = collectionView.frame.width - 20 * 2 - 12 // insets + 1 gap
        let itemWidth = availableWidth / 2
        return CGSize(width: itemWidth, height: 90)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedType = MeetupType.allCases[indexPath.item]
        collectionView.reloadData()
        updateNextButton()
    }
}

// MARK: - MeetupTypeCell

class MeetupTypeCell: UICollectionViewCell {

    private let iconLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 28)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = UIColor { tc in tc.userInterfaceStyle == .dark ? .secondarySystemGroupedBackground : .white }
        contentView.layer.cornerRadius = 16
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOpacity = 0.06
        contentView.layer.shadowRadius = 8
        contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
        contentView.layer.borderWidth = 2
        contentView.layer.borderColor = UIColor.clear.cgColor
        contentView.clipsToBounds = false

        contentView.addSubview(iconLabel)
        contentView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            iconLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -10),

            titleLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    func configure(with type: MeetupType, isSelected: Bool) {
        iconLabel.text = type.icon
        titleLabel.text = type.rawValue

        if isSelected {
            contentView.backgroundColor = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
            contentView.layer.borderColor = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1).cgColor
            titleLabel.textColor = .white
        } else {
            contentView.backgroundColor = UIColor { tc in tc.userInterfaceStyle == .dark ? .secondarySystemGroupedBackground : .white }
            contentView.layer.borderColor = UIColor.clear.cgColor
            titleLabel.textColor = .label
        }
    }
}

// MARK: - Notification name

extension Notification.Name {
    static let meetupGoBack         = Notification.Name("meetupGoBack")
    static let meetupCancelCreation = Notification.Name("meetupCancelCreation")
    static let meetupNightModeChanged = Notification.Name("meetupNightModeChanged")
}
