//
//  MeetupModels.swift
//  Meetup MessagesExtension
//
//  Created by Akhil Chamarthy on 2/28/26.
//

import Foundation

enum MeetupType: String, CaseIterable, Codable {
    case trip = "Trip"
    case hangout = "Hangout"
    case date = "Date"
    case meeting = "Meeting"
    case event = "Event"

    var icon: String {
        switch self {
        case .trip:     return "✈️"
        case .hangout:  return "🎉"
        case .date:     return "💕"
        case .meeting:  return "💼"
        case .event:    return "📅"
        }
    }

    /// Whether this type uses full days instead of timed slots.
    var isFullDay: Bool {
        switch self {
        case .trip:  return true
        default:     return false
        }
    }
}

// MARK: - TimeSlot (kept for timed meetups & model compatibility)

struct TimeSlot: Codable, Equatable {
    let start: Date
    let end: Date

    var duration: TimeInterval { end.timeIntervalSince(start) }
}

// MARK: - UserAvailability

struct UserAvailability: Codable {
    let userId: String
    let userName: String
    /// For timed meetups these represent actual start/end windows.
    /// For full-day meetups each slot spans midnight→midnight of an available day.
    let availableSlots: [TimeSlot]
    let busySlots: [TimeSlot]
    let responseDate: Date

    // MARK: Convenience helpers

    /// Returns the set of calendar days (noon of each day) that this user marked available.
    var availableDays: Set<Date> {
        let cal = Calendar.current
        return Set(availableSlots.map { cal.startOfDay(for: $0.start) })
    }
}

// MARK: - Meetup

struct Meetup: Codable {
    let id: UUID
    let title: String
    let type: MeetupType
    let creatorId: String
    let creatorName: String
    let createdDate: Date
    let startDateRange: Date
    let endDateRange: Date
    /// nil means full-day / no fixed duration (e.g. Trip).
    let duration: TimeInterval?
    let deadline: Date
    var availabilities: [UserAvailability]
    var isFinalized: Bool
    var finalizedTimeSlot: TimeSlot?

    init(title: String, type: MeetupType, creatorId: String, creatorName: String,
         startDateRange: Date, endDateRange: Date, duration: TimeInterval?, deadline: Date) {
        self.id = UUID()
        self.title = title
        self.type = type
        self.creatorId = creatorId
        self.creatorName = creatorName
        self.createdDate = Date()
        self.startDateRange = startDateRange
        self.endDateRange = endDateRange
        self.duration = duration
        self.deadline = deadline
        self.availabilities = []
        self.isFinalized = false
        self.finalizedTimeSlot = nil
    }

    var isActive: Bool { !isFinalized && Date() < deadline }

    mutating func addAvailability(_ availability: UserAvailability) {
        availabilities.removeAll { $0.userId == availability.userId }
        availabilities.append(availability)
    }

    // MARK: - Common day/slot calculation

    /// For full-day meetups: returns dates (start-of-day) available to ALL participants.
    func findCommonAvailableDays() -> [Date] {
        guard availabilities.count >= 2 else { return [] }
        var common = availabilities.first!.availableDays
        for availability in availabilities.dropFirst() {
            common = common.intersection(availability.availableDays)
        }
        return common.sorted()
    }

    /// For timed meetups: returns overlapping TimeSlots that meet the duration requirement.
    func findCommonAvailableSlots() -> [TimeSlot] {
        guard availabilities.count >= 2, let minDuration = duration else { return [] }
        var commonSlots = availabilities.first?.availableSlots ?? []
        for availability in availabilities.dropFirst() {
            commonSlots = findIntersection(slots1: commonSlots, slots2: availability.availableSlots)
        }
        return commonSlots.filter { $0.duration >= minDuration }
    }

    private func findIntersection(slots1: [TimeSlot], slots2: [TimeSlot]) -> [TimeSlot] {
        var result: [TimeSlot] = []
        for s1 in slots1 {
            for s2 in slots2 {
                let start = max(s1.start, s2.start)
                let end   = min(s1.end,   s2.end)
                if start < end { result.append(TimeSlot(start: start, end: end)) }
            }
        }
        return result
    }
}
