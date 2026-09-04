//
//  WelcomeViewController.swift
//  Meetup MessagesExtension
//
//  Created by Akhil Chamarthy on 2/28/26.
//

import UIKit

protocol WelcomeViewControllerDelegate: AnyObject {
    func didEnterMeetupName(_ name: String)
}

/// The initial "title slide" shown when the extension first opens.
/// Polls-app aesthetic: white background, blue accents, rounded pill button,
/// clean SF Pro typography, subtle card shadow.
class WelcomeViewController: UIViewController {

    weak var delegate: WelcomeViewControllerDelegate?

    // MARK: - UI

    /// Floating card that holds the icon + headline
    private let heroCard: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor { tc in tc.userInterfaceStyle == .dark ? .secondarySystemGroupedBackground : .white }
        v.layer.cornerRadius = 24
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.08
        v.layer.shadowRadius = 16
        v.layer.shadowOffset = CGSize(width: 0, height: 4)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let iconContainerView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 28
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let logoView: MeetupLogoView = {
        let v = MeetupLogoView()
        v.renderStyle = .onBlue
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let appNameLabel: UILabel = {
        let l = UILabel()
        l.text = "Meetup"
        l.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        l.textColor = .label
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let taglineLabel: UILabel = {
        let l = UILabel()
        l.text = "Find a time that works\nfor everyone."
        l.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        l.textColor = .label
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Divider
    private let divider: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.systemGray5
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // Name field section
    private let namePromptLabel: UILabel = {
        let l = UILabel()
        l.text = "Name your meetup"
        l.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        l.textColor = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let nameTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "e.g. Weekend Trip to Austin"
        tf.font = UIFont.systemFont(ofSize: 16)
        tf.textColor = .label
        tf.borderStyle = .none
        tf.returnKeyType = .next
        tf.autocapitalizationType = .words
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let textFieldUnderline: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.systemGray4
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let getStartedButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Get Started", for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        b.backgroundColor = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 14
        b.isEnabled = false
        b.alpha = 0.45
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(getStartedTapped), for: .touchUpInside)
        return b
    }()

    private let poweredByLabel: UILabel = {
        let l = UILabel()
        l.text = "Schedule together, effortlessly"
        l.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        l.textColor = UIColor.tertiaryLabel
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Stored so we can shift the card up when the keyboard appears
    private var cardCenterYConstraint: NSLayoutConstraint!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor { tc in tc.userInterfaceStyle == .dark ? .systemGroupedBackground : UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1) }
        setupUI()
        nameTextField.delegate = self
        nameTextField.addTarget(self, action: #selector(textChanged), for: .editingChanged)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)),
                                               name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        heroCard.transform = CGAffineTransform(translationX: 0, y: 20)
        heroCard.alpha = 0
        UIView.animate(withDuration: 0.45, delay: 0.05, usingSpringWithDamping: 0.78,
                       initialSpringVelocity: 0.4, options: .curveEaseOut) {
            self.heroCard.transform = .identity
            self.heroCard.alpha = 1
        }
    }

    // MARK: - Keyboard handling

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let info = notification.userInfo,
              let keyboardFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveRaw = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int
        else { return }

        let keyboardHeight = keyboardFrame.height
        let cardBottom = heroCard.frame.maxY
        let visibleHeight = view.bounds.height - keyboardHeight
        let overlap = cardBottom - visibleHeight + 16
        if overlap > 0 {
            let curve = UIView.AnimationOptions(rawValue: UInt(curveRaw << 16))
            cardCenterYConstraint.constant = -(12 + overlap)
            UIView.animate(withDuration: duration, delay: 0, options: curve) {
                self.view.layoutIfNeeded()
            }
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let info = notification.userInfo,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveRaw = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int
        else { return }

        let curve = UIView.AnimationOptions(rawValue: UInt(curveRaw << 16))
        cardCenterYConstraint.constant = -12
        UIView.animate(withDuration: duration, delay: 0, options: curve) {
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Layout

    private func setupUI() {
        view.addSubview(heroCard)
        view.addSubview(poweredByLabel)

        // Icon container
        heroCard.addSubview(iconContainerView)
        iconContainerView.addSubview(logoView)

        // Text hierarchy
        heroCard.addSubview(appNameLabel)
        heroCard.addSubview(taglineLabel)
        heroCard.addSubview(divider)
        heroCard.addSubview(namePromptLabel)
        heroCard.addSubview(nameTextField)
        heroCard.addSubview(textFieldUnderline)
        heroCard.addSubview(getStartedButton)

        cardCenterYConstraint = heroCard.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -12)

        NSLayoutConstraint.activate([
            // Card — centered, fills most of width, not full height
            heroCard.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardCenterYConstraint,
            heroCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            heroCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Icon container
            iconContainerView.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: 24),
            iconContainerView.centerXAnchor.constraint(equalTo: heroCard.centerXAnchor),
            iconContainerView.widthAnchor.constraint(equalToConstant: 80),
            iconContainerView.heightAnchor.constraint(equalToConstant: 80),

            logoView.topAnchor.constraint(equalTo: iconContainerView.topAnchor),
            logoView.leadingAnchor.constraint(equalTo: iconContainerView.leadingAnchor),
            logoView.trailingAnchor.constraint(equalTo: iconContainerView.trailingAnchor),
            logoView.bottomAnchor.constraint(equalTo: iconContainerView.bottomAnchor),

            // App name
            appNameLabel.topAnchor.constraint(equalTo: iconContainerView.bottomAnchor, constant: 14),
            appNameLabel.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 20),
            appNameLabel.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -20),

            // Tagline
            taglineLabel.topAnchor.constraint(equalTo: appNameLabel.bottomAnchor, constant: 6),
            taglineLabel.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 24),
            taglineLabel.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -24),

            // Divider
            divider.topAnchor.constraint(equalTo: taglineLabel.bottomAnchor, constant: 22),
            divider.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 20),
            divider.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -20),
            divider.heightAnchor.constraint(equalToConstant: 1),

            // Name prompt
            namePromptLabel.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 18),
            namePromptLabel.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 20),
            namePromptLabel.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -20),

            // Name text field
            nameTextField.topAnchor.constraint(equalTo: namePromptLabel.bottomAnchor, constant: 8),
            nameTextField.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 20),
            nameTextField.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -20),
            nameTextField.heightAnchor.constraint(equalToConstant: 36),

            // Underline
            textFieldUnderline.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 2),
            textFieldUnderline.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 20),
            textFieldUnderline.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -20),
            textFieldUnderline.heightAnchor.constraint(equalToConstant: 1),

            // Get Started button
            getStartedButton.topAnchor.constraint(equalTo: textFieldUnderline.bottomAnchor, constant: 20),
            getStartedButton.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 20),
            getStartedButton.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -20),
            getStartedButton.heightAnchor.constraint(equalToConstant: 50),
            getStartedButton.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: -24),

            // Powered by
            poweredByLabel.topAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: 14),
            poweredByLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    // MARK: - Actions

    @objc private func textChanged() {
        let hasText = !(nameTextField.text?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)

        // Animate underline color
        textFieldUnderline.backgroundColor = hasText
            ? UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
            : UIColor.systemGray4

        UIView.animate(withDuration: 0.2) {
            self.getStartedButton.isEnabled = hasText
            self.getStartedButton.alpha = hasText ? 1.0 : 0.45
        }
    }

    @objc private func getStartedTapped() {
        guard let name = nameTextField.text?.trimmingCharacters(in: .whitespaces),
              !name.isEmpty else { return }

        // Animate button press
        UIView.animate(withDuration: 0.1, animations: {
            self.getStartedButton.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.getStartedButton.transform = .identity
            }
            self.delegate?.didEnterMeetupName(name)
        }
    }
}

// MARK: - UITextFieldDelegate

extension WelcomeViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        let name = textField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        if !name.isEmpty {
            getStartedTapped()
        }
        return true
    }
}
