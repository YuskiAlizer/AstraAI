import Foundation
import EventKit

/// Calendar Skill — reads and creates calendar events using EventKit.
/// Requires iOS calendar permission. Never accesses calendar without user consent.
final class CalendarSkill: AgentSkill, @unchecked Sendable {

    let id = "calendar"
    let name = "Calendrier"
    let description = "Consulte et crée des événements dans le calendrier. Nécessite l'autorisation d'accès au calendrier."
    let category: SkillCategory = .calendar
    let requiredPermissions: [SkillPermission] = [.calendar]
    let requiresConfirmation = true

    private let eventStore = EKEventStore()

    var inputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "action": .object([
                    "type": .string("string"),
                    "description": .string("Action: 'list' (lister les événements), 'create' (créer un événement)"),
                    "enum": .array([.string("list"), .string("create")])
                ]),
                "startDate": .object([
                    "type": .string("string"),
                    "description": .string("Date de début (ISO 8601) pour list ou create")
                ]),
                "endDate": .object([
                    "type": .string("string"),
                    "description": .string("Date de fin (ISO 8601) pour list ou create")
                ]),
                "title": .object([
                    "type": .string("string"),
                    "description": .string("Titre de l'événement (pour create)")
                ]),
                "notes": .object([
                    "type": .string("string"),
                    "description": .string("Notes de l'événement (pour create)")
                ]),
                "location": .object([
                    "type": .string("string"),
                    "description": .string("Lieu de l'événement (pour create)")
                ])
            ]),
            "required": .array([.string("action")])
        ])
    }

    var outputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "events": .array([.object([:])]),
                "success": .bool(true)
            ])
        ])
    }

    func execute(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        guard let action = input["action"]?.stringValue else {
            throw SkillError.invalidInput("Le paramètre 'action' est requis")
        }

        // Request permission
        let granted = await requestCalendarAccess()
        guard granted else {
            throw SkillError.permissionDenied(.calendar)
        }

        switch action {
        case "list":
            return try await listEvents(input: input, context: context)
        case "create":
            return try await createEvent(input: input, context: context)
        default:
            throw SkillError.invalidInput("Action inconnue: \(action)")
        }
    }

    func requiresConfirmation(for input: JSONValue) -> Bool {
        guard let action = input["action"]?.stringValue else { return false }
        return action == "create"
    }

    func confirmationDescription(for input: JSONValue) -> String {
        let title = input["title"]?.stringValue ?? "événement"
        return "Créer l'événement « \(title) » dans le calendrier?"
    }

    // MARK: - Permission

    private func requestCalendarAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .fullAccess, .writeOnly, .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                eventStore.requestFullAccessToEvents { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - List

    private func listEvents(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        let now = Date()
        let calendar = Calendar.current

        let startDate: Date
        if let dateStr = input["startDate"]?.stringValue, let date = ISO8601DateFormatter().date(from: dateStr) {
            startDate = date
        } else {
            startDate = now
        }

        let endDate: Date
        if let dateStr = input["endDate"]?.stringValue, let date = ISO8601DateFormatter().date(from: dateStr) {
            endDate = date
        } else {
            endDate = calendar.date(byAdding: .day, value: 7, to: startDate) ?? startDate.addingTimeInterval(7 * 24 * 3600)
        }

        context.emitEvent(.statusChanged("Récupération des événements..."))

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)

        let eventsArray: [JSONValue] = events.map { event in
            .object([
                "id": .string(event.eventIdentifier ?? ""),
                "title": .string(event.title ?? ""),
                "startDate": .string(ISO8601DateFormatter().string(from: event.startDate)),
                "endDate": .string(ISO8601DateFormatter().string(from: event.endDate)),
                "location": .string(event.location ?? ""),
                "notes": .string(event.notes ?? ""),
                "calendar": .string(event.calendar.title)
            ])
        }

        let output: JSONValue = .object([
            "events": .array(eventsArray),
            "total": .number(Double(events.count)),
            "range": .object([
                "start": .string(ISO8601DateFormatter().string(from: startDate)),
                "end": .string(ISO8601DateFormatter().string(from: endDate))
            ])
        ])

        return SkillResult(
            output: output,
            summary: "\(events.count) événement(s) trouvé(s)"
        )
    }

    // MARK: - Create

    private func createEvent(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        guard let title = input["title"]?.stringValue, !title.isEmpty else {
            throw SkillError.invalidInput("Le paramètre 'title' est requis")
        }

        guard let startDateStr = input["startDate"]?.stringValue,
              let startDate = ISO8601DateFormatter().date(from: startDateStr) else {
            throw SkillError.invalidInput("Le paramètre 'startDate' (ISO 8601) est requis")
        }

        let endDate: Date
        if let endDateStr = input["endDate"]?.stringValue, let date = ISO8601DateFormatter().date(from: endDateStr) {
            endDate = date
        } else {
            endDate = startDate.addingTimeInterval(3600) // Default 1 hour
        }

        context.emitEvent(.statusChanged("Création de l'événement: \(title)..."))

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = input["notes"]?.stringValue
        event.location = input["location"]?.stringValue
        event.calendar = eventStore.defaultCalendarForNewEvents

        do {
            try eventStore.save(event, span: .thisEvent)

            let output: JSONValue = .object([
                "success": .bool(true),
                "eventId": .string(event.eventIdentifier ?? ""),
                "title": .string(title),
                "startDate": .string(ISO8601DateFormatter().string(from: startDate)),
                "endDate": .string(ISO8601DateFormatter().string(from: endDate))
            ])

            return SkillResult(
                output: output,
                summary: "Événement « \(title) » créé avec succès"
            )
        } catch {
            throw SkillError.custom("Erreur lors de la création de l'événement: \(error.localizedDescription)")
        }
    }
}

/// Reminders Skill — creates reminders using EventKit.
final class RemindersSkill: AgentSkill, @unchecked Sendable {

    let id = "reminders"
    let name = "Rappels"
    let description = "Crée et liste des rappels. Nécessite l'autorisation d'accès aux rappels."
    let category: SkillCategory = .reminders
    let requiredPermissions: [SkillPermission] = [.reminders]
    let requiresConfirmation = true

    private let eventStore = EKEventStore()

    var inputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "action": .object([
                    "type": .string("string"),
                    "description": .string("Action: 'create' (créer un rappel), 'list' (lister les rappels)"),
                    "enum": .array([.string("create"), .string("list")])
                ]),
                "title": .object([
                    "type": .string("string"),
                    "description": .string("Titre du rappel (pour create)")
                ]),
                "notes": .object([
                    "type": .string("string"),
                    "description": .string("Notes du rappel")
                ]),
                "dueDate": .object([
                    "type": .string("string"),
                    "description": .string("Date d'échéance (ISO 8601)")
                ])
            ]),
            "required": .array([.string("action")])
        ])
    }

    var outputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "success": .bool(true),
                "reminders": .array([.object([:])])
            ])
        ])
    }

    func execute(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        guard let action = input["action"]?.stringValue else {
            throw SkillError.invalidInput("Le paramètre 'action' est requis")
        }

        let granted = await requestRemindersAccess()
        guard granted else {
            throw SkillError.permissionDenied(.reminders)
        }

        switch action {
        case "create":
            return try await createReminder(input: input, context: context)
        case "list":
            return try await listReminders(context: context)
        default:
            throw SkillError.invalidInput("Action inconnue: \(action)")
        }
    }

    func requiresConfirmation(for input: JSONValue) -> Bool {
        guard let action = input["action"]?.stringValue else { return false }
        return action == "create"
    }

    func confirmationDescription(for input: JSONValue) -> String {
        let title = input["title"]?.stringValue ?? "rappel"
        return "Créer le rappel « \(title) »?"
    }

    // MARK: - Permission

    private func requestRemindersAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)

        switch status {
        case .fullAccess, .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                eventStore.requestFullAccessToReminders { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Create

    private func createReminder(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        guard let title = input["title"]?.stringValue, !title.isEmpty else {
            throw SkillError.invalidInput("Le paramètre 'title' est requis")
        }

        context.emitEvent(.statusChanged("Création du rappel: \(title)..."))

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = input["notes"]?.stringValue

        if let dueDateStr = input["dueDate"]?.stringValue,
           let dueDate = ISO8601DateFormatter().date(from: dueDateStr) {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        }

        reminder.calendar = eventStore.defaultCalendarForNewReminders()

        do {
            try eventStore.save(reminder, commit: true)

            let output: JSONValue = .object([
                "success": .bool(true),
                "title": .string(title),
                "reminderId": .string(reminder.calendarItemIdentifier)
            ])

            return SkillResult(
                output: output,
                summary: "Rappel « \(title) » créé avec succès"
            )
        } catch {
            throw SkillError.custom("Erreur lors de la création du rappel: \(error.localizedDescription)")
        }
    }

    // MARK: - List

    private func listReminders(context: SkillExecutionContext) async throws -> SkillResult {
        context.emitEvent(.statusChanged("Récupération des rappels..."))

        let calendars = eventStore.calendars(for: .reminder)
        var allReminders: [EKReminder] = []

        for cal in calendars {
            let predicate = eventStore.predicateForReminders(in: [cal])
            let reminders = await withCheckedContinuation { (continuation: CheckedContinuation<[EKReminder], Never>) in
                eventStore.fetchReminders(matching: predicate) { reminders in
                    continuation.resume(returning: reminders ?? [])
                }
            }
            allReminders.append(contentsOf: reminders)
        }

        let remindersArray: [JSONValue] = allReminders.prefix(50).map { reminder in
            .object([
                "id": .string(reminder.calendarItemIdentifier),
                "title": .string(reminder.title ?? ""),
                "notes": .string(reminder.notes ?? ""),
                "completed": .bool(reminder.isCompleted),
                "dueDate": reminder.dueDateComponents.map { _ in
                    .string(Calendar.current.date(from: reminder.dueDateComponents!).map { ISO8601DateFormatter().string(from: $0) } ?? "")
                } ?? .null
            ])
        }

        let output: JSONValue = .object([
            "reminders": .array(remindersArray),
            "total": .number(Double(allReminders.count))
        ])

        return SkillResult(
            output: output,
            summary: "\(allReminders.count) rappel(s) trouvé(s)"
        )
    }
}
