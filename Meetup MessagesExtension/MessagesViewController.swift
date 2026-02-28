//
//  MessagesViewController.swift
//  Meetup MessagesExtension
//
//  Created by Akhil Chamarthy on 2/28/26.
//

import UIKit
import Messages

class MessagesViewController: MSMessagesAppViewController {

    private var currentViewController: UIViewController?
    private var activeMeetup: Meetup?
    private var pendingMeetupTitle: String = ""
    private var pendingMeetupType: MeetupType = .hangout

    override func viewDidLoad() {
        super.viewDidLoad()
        presentCreateMeetupFlow()
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

    private func presentCreateMeetupFlow() {
        let typeVC = MeetupTypeViewController()
        typeVC.delegate = self
        presentViewController(typeVC)
    }

    private func presentDateTimeSelection(meetupTitle: String, meetupType: MeetupType) {
        let vc = DateTimeSelectionViewController(meetupTitle: meetupTitle, meetupType: meetupType)
        vc.delegate = self
        presentViewController(vc)
    }

    private func presentAvailabilityInput(for meetup: Meetup) {
        let vc = AvailabilityViewController(
            meetup: meetup,
            currentUserId: getCurrentUserId(),
            currentUserName: getCurrentUserName()
        )
        vc.delegate = self
        presentViewController(vc)
    }

    private func presentResultsView(for meetup: Meetup) {
        presentViewController(ResultsViewController(meetup: meetup))
    }

    private func presentViewController(_ viewController: UIViewController) {
        currentViewController?.removeFromParent()
        currentViewController?.view.removeFromSuperview()

        addChild(viewController)
        view.addSubview(viewController.view)
        viewController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            viewController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            viewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            viewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            viewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        viewController.didMove(toParent: self)
        currentViewController = viewController
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

        // TODO: retrieve real meetup from shared UserDefaults/App Group store
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
            presentCreateMeetupFlow()
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
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 40), .foregroundColor: UIColor.white]
        let text = "📅"
        let ts = text.size(withAttributes: attrs)
        text.draw(in: CGRect(x: (size.width-ts.width)/2, y: (size.height-ts.height)/2, width: ts.width, height: ts.height), withAttributes: attrs)
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

// MARK: - MeetupTypeViewControllerDelegate

extension MessagesViewController: MeetupTypeViewControllerDelegate {
    func didSelectMeetupType(_ type: MeetupType, title: String) {
        pendingMeetupTitle = title
        pendingMeetupType  = type
        presentDateTimeSelection(meetupTitle: title, meetupType: type)
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
            duration: duration,       // nil for full-day types like Trip
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
