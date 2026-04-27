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

    // Accumulated while stepping through the creation flow
    private var pendingMeetupTitle: String = ""
    private var pendingMeetupType: MeetupType = .hangout

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        // Listen for back-navigation fired by child VCs
        NotificationCenter.default.addObserver(self, selector: #selector(handleGoBack),
                                               name: .meetupGoBack, object: nil)
        presentWelcomeScreen()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Conversation Handling

    override func willBecomeActive(with conversation: MSConversation) {
        checkForActiveMeetup(in: conversation)
    }

    override func didResignActive(with conversation: MSConversation) {}

    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        if let meetup = decodeMeetup(from: message) {
            activeMeetup = meetup
            presentAvailabilityInput(for: meetup)
        }
    }

    override func didStartSending(_ message: MSMessage, conversation: MSConversation) {}
    override func didCancelSending(_ message: MSMessage, conversation: MSConversation) {}
    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {}
    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {}

    // MARK: - Navigation

    /// Step 1 — Welcome / name entry
    private func presentWelcomeScreen() {
        let vc = WelcomeViewController()
        vc.delegate = self
        transition(to: vc, direction: .left)
    }

    /// Step 2 — Meetup type selection
    private func presentTypeSelection(meetupTitle: String) {
        let vc = MeetupTypeViewController(meetupTitle: meetupTitle)
        vc.delegate = self
        transition(to: vc, direction: .right)
    }

    /// Step 3 — Date/time range + duration
    private func presentDateTimeSelection(meetupTitle: String, meetupType: MeetupType) {
        let vc = DateTimeSelectionViewController(meetupTitle: meetupTitle, meetupType: meetupType)
        vc.delegate = self
        transition(to: vc, direction: .right)
    }

    /// After creation — availability picker
    private func presentAvailabilityInput(for meetup: Meetup) {
        let vc = AvailabilityViewController(
            meetup: meetup,
            currentUserId: getCurrentUserId(),
            currentUserName: getCurrentUserName()
        )
        vc.delegate = self
        transition(to: vc, direction: .right)
    }

    /// Final step — results
    private func presentResultsView(for meetup: Meetup) {
        transition(to: ResultsViewController(meetup: meetup), direction: .right)
    }

    // MARK: - Back navigation

    @objc private func handleGoBack() {
        // Determine where we currently are and go one step back
        switch currentViewController {
        case is MeetupTypeViewController:
            presentWelcomeScreen()   // back to name entry
        case is DateTimeSelectionViewController:
            presentTypeSelection(meetupTitle: pendingMeetupTitle)  // back to type
        default:
            presentWelcomeScreen()
        }
    }

    // MARK: - Animated transitions

    private enum SlideDirection { case left, right }

    private func transition(to newVC: UIViewController, direction: SlideDirection) {
        let oldVC = currentViewController
        let width = view.bounds.width
        let inOffset  =  direction == .right ? width : -width
        let outOffset = direction == .right ? -width : width

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

    // MARK: - Message Handling

    private func createMeetupMessage(with meetup: Meetup) -> MSMessage? {
        let session = MSSession()
        let message = MSMessage(session: session)

        if let data = try? JSONEncoder().encode(meetup) {
            let layout = MSMessageTemplateLayout()
            layout.image = UIImage(named: "meetup_icon") ?? createMeetupIcon()
            layout.caption = "\(meetup.type.icon) \(meetup.title)"
            layout.subcaption = "Tap to add your availability"
            message.layout = layout
            message.summaryText = "\(meetup.creatorName) created a \(meetup.type.rawValue.lowercased()) meetup"
            message.url = URL(string: "meetup://\(meetup.id.uuidString)")
            message.accessibilityLabel = String(data: data, encoding: .utf8)
        }

        return message
    }

    private func decodeMeetup(from message: MSMessage) -> Meetup? {
        guard let urlString = message.url?.absoluteString,
              urlString.hasPrefix("meetup://"),
              let _ = UUID(uuidString: urlString.replacingOccurrences(of: "meetup://", with: ""))
        else { return nil }

        // TODO: retrieve real meetup from shared UserDefaults / App Group store
        return createMockMeetup()
    }

    private func sendMeetupMessage(_ meetup: Meetup) {
        guard let message = createMeetupMessage(with: meetup),
              let conversation = activeConversation else { return }

        conversation.insert(message) { error in
            if let error = error { print("Error sending message: \(error)") }
        }
    }

    private func checkForActiveMeetup(in conversation: MSConversation) {
        if let meetup = activeMeetup {
            presentAvailabilityInput(for: meetup)
        } else {
            presentWelcomeScreen()
        }
    }

    // MARK: - Helpers

    private func getCurrentUserId() -> String {
        UIDevice.current.identifierForVendor?.uuidString ?? "user_\(UUID().uuidString)"
    }

    private func getCurrentUserName() -> String { "User" }

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

    private func createMockMeetup() -> Meetup {
        let cal = Calendar.current
        return Meetup(
            title: "Sample Meetup",
            type: .hangout,
            creatorId: "creator_123",
            creatorName: "Creator",
            startDateRange: cal.date(byAdding: .day, value: 1, to: Date())!,
            endDateRange:   cal.date(byAdding: .day, value: 7, to: Date())!,
            duration: 3600,
            deadline: cal.date(byAdding: .hour, value: 24, to: Date())!
        )
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
    func didSelectDateTime(startDate: Date, endDate: Date, duration: TimeInterval?, deadline: Date) {
        let meetup = Meetup(
            title: pendingMeetupTitle,
            type: pendingMeetupType,
            creatorId: getCurrentUserId(),
            creatorName: getCurrentUserName(),
            startDateRange: startDate,
            endDateRange: endDate,
            duration: duration,
            deadline: deadline
        )
        activeMeetup = meetup
        sendMeetupMessage(meetup)
        presentAvailabilityInput(for: meetup)
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
