//
//  MessagesViewController.swift
//  Meetup MessagesExtension
//
//  Created by Akhil Chamarthy on 2/28/26.
//

import UIKit
import Messages

class MessagesViewController: MSMessagesAppViewController {

    // MARK: - State

    private var currentViewController: UIViewController?
    private var activeMeetup: Meetup?
    /// Retained so all sends for the same meetup update the same bubble.
    private var activeSession: MSSession?
    /// True when the user opened the extension by tapping an existing meetup bubble.
    private var isJoiningExistingMeetup = false

    // Accumulated while stepping through the creation flow
    private var pendingMeetupTitle: String = ""
    private var pendingMeetupType: MeetupType = .hangout

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(handleGoBack),
                                               name: .meetupGoBack, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleCancelCreation),
                                               name: .meetupCancelCreation, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNightModeChanged),
                                               name: .meetupNightModeChanged, object: nil)
        applyAppearance()
    }

    @objc private func handleNightModeChanged() {
        applyAppearance()
    }

    private func applyAppearance() {
        let isNight = UserDefaults.standard.bool(forKey: "meetup_night_mode")
        overrideUserInterfaceStyle = isNight ? .dark : .light
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Conversation Handling

    override func willBecomeActive(with conversation: MSConversation) {
        if let selected = conversation.selectedMessage,
           let meetup = decodeMeetup(from: selected) {
            // Keep the original session so future sends update the same bubble.
            activeSession = selected.session
            activeMeetup = meetup
            isJoiningExistingMeetup = true
            // Expand so the full UI is visible — tapping a bubble can open in compact.
            requestPresentationStyle(.expanded)
            let userId = getCurrentUserId()
            if meetup.isFinalized || meetup.availabilities.contains(where: { $0.userId == userId }) {
                presentResultsView(for: meetup)
            } else {
                presentAvailabilityInputPromptingNameIfNeeded(for: meetup)
            }
        } else {
            isJoiningExistingMeetup = false
            presentWelcomeScreen()
        }
    }

    override func didResignActive(with conversation: MSConversation) {}

    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        guard let meetup = decodeMeetup(from: message) else { return }
        activeMeetup = meetup
        if currentViewController is ResultsViewController {
            presentResultsView(for: meetup)
        }
    }

    override func didStartSending(_ message: MSMessage, conversation: MSConversation) {}
    override func didCancelSending(_ message: MSMessage, conversation: MSConversation) {}
    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {}
    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {}

    // MARK: - Navigation

    private func presentWelcomeScreen() {
        let vc = WelcomeViewController()
        vc.delegate = self
        transition(to: vc, direction: .left)
    }

    private func presentTypeSelection(meetupTitle: String) {
        let vc = MeetupTypeViewController(meetupTitle: meetupTitle)
        vc.delegate = self
        transition(to: vc, direction: .right)
    }

    private func presentDateTimeSelection(meetupTitle: String, meetupType: MeetupType) {
        let vc = DateTimeSelectionViewController(meetupTitle: meetupTitle, meetupType: meetupType)
        vc.delegate = self
        transition(to: vc, direction: .right)
    }

    private func presentAvailabilityInput(for meetup: Meetup) {
        let vc = AvailabilityViewController(
            meetup: meetup,
            currentUserId: getCurrentUserId(),
            currentUserName: getCurrentUserName()
        )
        vc.delegate = self
        transition(to: vc, direction: .right)
    }

    /// Shows the availability screen, but first prompts for a display name on first use.
    private func presentAvailabilityInputPromptingNameIfNeeded(for meetup: Meetup) {
        if !isUserNameConfigured() {
            promptForUserName { [weak self] name in
                self?.setCurrentUserName(name)
                self?.presentAvailabilityInput(for: meetup)
            }
        } else {
            presentAvailabilityInput(for: meetup)
        }
    }

    private func presentResultsView(for meetup: Meetup) {
        let vc = ResultsViewController(meetup: meetup, currentUserId: getCurrentUserId())
        vc.delegate = self
        transition(to: vc, direction: .right)
    }

    // MARK: - Back navigation

    @objc private func handleCancelCreation() {
        activeMeetup = nil
        activeSession = nil
        pendingMeetupTitle = ""
        isJoiningExistingMeetup = false
        presentWelcomeScreen()
    }

    @objc private func handleGoBack() {
        switch currentViewController {
        case is MeetupTypeViewController:
            presentWelcomeScreen()
        case is DateTimeSelectionViewController:
            presentTypeSelection(meetupTitle: pendingMeetupTitle)
        case is AvailabilityViewController:
            // Joiner backing out → show results rather than the creation flow.
            if isJoiningExistingMeetup, let meetup = activeMeetup {
                presentResultsView(for: meetup)
            } else {
                presentWelcomeScreen()
            }
        default:
            presentWelcomeScreen()
        }
    }

    // MARK: - Animated transitions

    private enum SlideDirection { case left, right }

    private func transition(to newVC: UIViewController, direction: SlideDirection) {
        let oldVC = currentViewController
        let width = view.bounds.width
        let inOffset  = direction == .right ?  width : -width
        let outOffset = direction == .right ? -width :  width

        addChild(newVC)
        view.addSubview(newVC.view)
        newVC.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            newVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            newVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            newVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            newVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        newVC.view.transform = CGAffineTransform(translationX: inOffset, y: 0)

        UIView.animate(
            withDuration: 0.36,
            delay: 0,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0.2,
            options: .curveEaseInOut
        ) {
            newVC.view.transform = .identity
            oldVC?.view.transform = CGAffineTransform(translationX: outOffset, y: 0)
        } completion: { _ in
            oldVC?.view.removeFromSuperview()
            oldVC?.removeFromParent()
            newVC.didMove(toParent: self)
            self.currentViewController = newVC
        }
    }

    // MARK: - Message Encoding / Decoding

    /// Encodes `meetup` as base64 JSON in the message URL so the full state travels with the bubble.
    private func createMeetupMessage(with meetup: Meetup) -> MSMessage? {
        guard let data = try? JSONEncoder().encode(meetup) else { return nil }

        // Reuse the existing session so each send updates the same bubble.
        let session = activeSession ?? MSSession()
        activeSession = session
        let message = MSMessage(session: session)

        var components = URLComponents()
        components.scheme = "meetup"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "data", value: data.base64EncodedString())]
        message.url = components.url

        let layout = MSMessageTemplateLayout()
        layout.image = createBubbleImage(for: meetup)

        if meetup.isFinalized {
            message.summaryText = "\(meetup.title) has been finalized!"
        } else {
            let n = meetup.availabilities.count
            message.summaryText = n == 0
                ? "\(meetup.creatorName) created a \(meetup.type.rawValue.lowercased()) meetup"
                : "\(meetup.availabilities.last?.userName ?? meetup.creatorName) added their availability"
        }

        message.layout = layout
        return message
    }

    /// Decodes a `Meetup` from the base64 JSON embedded in a message's URL query params.
    private func decodeMeetup(from message: MSMessage) -> Meetup? {
        guard let url = message.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let base64 = components.queryItems?.first(where: { $0.name == "data" })?.value,
              let data = Data(base64Encoded: base64),
              let meetup = try? JSONDecoder().decode(Meetup.self, from: data)
        else { return nil }
        return meetup
    }

    private func sendMeetupMessage(_ meetup: Meetup) {
        guard let message = createMeetupMessage(with: meetup),
              let conversation = activeConversation else { return }
        conversation.insert(message) { error in
            if let error = error { print("Error sending meetup message: \(error)") }
        }
    }

    // MARK: - User Identity

    private func getCurrentUserId() -> String {
        if let stored = UserDefaults.standard.string(forKey: "meetup_user_id") {
            return stored
        }
        let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(id, forKey: "meetup_user_id")
        return id
    }

    private func getCurrentUserName() -> String {
        UserDefaults.standard.string(forKey: "meetup_user_name") ?? "User"
    }

    private func setCurrentUserName(_ name: String) {
        UserDefaults.standard.set(name, forKey: "meetup_user_name")
        UserDefaults.standard.set(true, forKey: "meetup_name_configured")
    }

    private func isUserNameConfigured() -> Bool {
        UserDefaults.standard.bool(forKey: "meetup_name_configured")
    }

    private func promptForUserName(completion: @escaping (String) -> Void) {
        let alert = UIAlertController(title: "What's your name?",
                                      message: "This helps others know whose availability is whose.",
                                      preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "Your name"
            tf.autocapitalizationType = .words
            tf.returnKeyType = .done
        }
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
            let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces)
            completion(name?.isEmpty == false ? name! : "User")
        })
        present(alert, animated: true)
    }

    // MARK: - Bubble image

    private func createBubbleImage(for meetup: Meetup) -> UIImage {
        let size = CGSize(width: 320, height: 130)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext

            // ── Background ─────────────────────────────────────────
            UIColor(red: 0.97, green: 0.97, blue: 1.00, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let blue     = UIColor(red: 0.22, green: 0.58, blue: 1.0, alpha: 1)
            let ink      = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1)
            let secondary = UIColor(red: 0.45, green: 0.45, blue: 0.50, alpha: 1)

            // ── Logo (app-icon style, rounded rect) ────────────────
            let logoSide: CGFloat = 66
            let logoX: CGFloat    = 14
            let logoY: CGFloat    = (96 - logoSide) / 2   // centred in content zone
            let logoRect  = CGRect(x: logoX, y: logoY, width: logoSide, height: logoSide)
            let logoImage = MeetupLogoView.image(size: CGSize(width: logoSide, height: logoSide),
                                                 style: .onBlue)

            // Clip to iOS-style rounded rect before drawing
            cg.saveGState()
            UIBezierPath(roundedRect: logoRect, cornerRadius: logoSide * 0.22).addClip()
            logoImage.draw(in: logoRect)
            cg.restoreGState()

            // ── Meetup title ───────────────────────────────────────
            let textX: CGFloat = logoX + logoSide + 14
            let textW: CGFloat = size.width - textX - 12
            let titlePara = NSMutableParagraphStyle()
            titlePara.lineBreakMode = .byTruncatingTail
            meetup.title.draw(
                in: CGRect(x: textX, y: 22, width: textW, height: 24),
                withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 16),
                    .foregroundColor: ink,
                    .paragraphStyle: titlePara,
                ]
            )

            // ── Type label ─────────────────────────────────────────
            let typeStr = "\(meetup.type.icon)  \(meetup.type.rawValue)"
            typeStr.draw(
                at: CGPoint(x: textX, y: 50),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 13),
                    .foregroundColor: secondary,
                ]
            )

            // ── Separator ──────────────────────────────────────────
            UIColor(red: 0.88, green: 0.88, blue: 0.90, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 96, width: size.width, height: 1))

            // ── Status bar ─────────────────────────────────────────
            let n = meetup.availabilities.count
            let statusText: String
            let statusColor: UIColor
            if meetup.isFinalized {
                statusText  = "✓  Meetup finalized"
                statusColor = .systemGreen
            } else if n == 0 {
                statusText  = "Tap to add your availability"
                statusColor = blue
            } else {
                statusText  = "\(n) \(n == 1 ? "person" : "people") responded  ·  Tap to join"
                statusColor = blue
            }
            statusText.draw(
                at: CGPoint(x: 14, y: 105),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: statusColor,
                ]
            )

            _ = cg
        }
    }

    // MARK: - Icon helper

    private func createMeetupIcon() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let ctx = UIGraphicsGetCurrentContext()!
        ctx.setFillColor(UIColor.systemBlue.cgColor)
        ctx.fillEllipse(in: CGRect(origin: .zero, size: size))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 40),
            .foregroundColor: UIColor.white
        ]
        let text = "📅"
        let ts = text.size(withAttributes: attrs)
        text.draw(in: CGRect(x: (size.width - ts.width) / 2,
                             y: (size.height - ts.height) / 2,
                             width: ts.width, height: ts.height),
                  withAttributes: attrs)
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }
}

// MARK: - WelcomeViewControllerDelegate

extension MessagesViewController: WelcomeViewControllerDelegate {
    func didEnterMeetupName(_ name: String) {
        pendingMeetupTitle = name
        presentTypeSelection(meetupTitle: name)
    }
}

// MARK: - MeetupTypeViewControllerDelegate

extension MessagesViewController: MeetupTypeViewControllerDelegate {
    func didSelectMeetupType(_ type: MeetupType) {
        pendingMeetupType = type
        presentDateTimeSelection(meetupTitle: pendingMeetupTitle, meetupType: type)
    }
}

// MARK: - DateTimeSelectionViewControllerDelegate

extension MessagesViewController: DateTimeSelectionViewControllerDelegate {
    func didSelectDateTime(startDate: Date, endDate: Date, duration: TimeInterval?, deadline: Date, settings: MeetupSettings) {
        let createAndSend = { [weak self] in
            guard let self else { return }
            let meetup = Meetup(
                title: self.pendingMeetupTitle,
                type: self.pendingMeetupType,
                creatorId: self.getCurrentUserId(),
                creatorName: self.getCurrentUserName(),
                startDateRange: startDate,
                endDateRange: endDate,
                duration: duration,
                deadline: deadline,
                settings: settings
            )
            self.activeMeetup = meetup
            self.activeSession = nil  // fresh session for a brand-new meetup
            self.sendMeetupMessage(meetup)
            self.presentAvailabilityInput(for: meetup)
        }

        if !isUserNameConfigured() {
            promptForUserName { [weak self] name in
                self?.setCurrentUserName(name)
                createAndSend()
            }
        } else {
            createAndSend()
        }
    }
}

// MARK: - AvailabilityViewControllerDelegate

extension MessagesViewController: AvailabilityViewControllerDelegate {
    func didSubmitAvailability(_ availability: UserAvailability) {
        guard var meetup = activeMeetup else { return }
        meetup.addAvailability(availability)
        activeMeetup = meetup
        sendMeetupMessage(meetup)
        presentResultsView(for: meetup)
    }
}

// MARK: - ResultsViewControllerDelegate

extension MessagesViewController: ResultsViewControllerDelegate {
    func didFinalizeMeetup(_ meetup: Meetup) {
        activeMeetup = meetup
        sendMeetupMessage(meetup)
    }
}
