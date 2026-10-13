import Foundation
import SwiftUI

struct AgendaEvent: Identifiable {
    let uid: String
    let title: String
    let start: Date
    let end: Date?
    let isAllDay: Bool
    let location: String
    let details: String

    var id: String {
        "\(uid)|\(start.timeIntervalSince1970)"
    }
}

@MainActor
final class AgendaViewModel: ObservableObject {
    @Published private(set) var events: [AgendaEvent] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?
    @Published var errorMessage: String?

    private var lastRequestedURL: String?
    private var activeRequestID: UUID?

    func setLoadError(_ message: String) {
        errorMessage = message
    }

    func clearEvents() {
        activeRequestID = nil
        events = []
        isLoading = false
        lastUpdated = nil
        errorMessage = nil
        lastRequestedURL = nil
    }

    func refresh(calendarURL: String) async {
        let trimmedURL = calendarURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmedURL),
              components.scheme?.lowercased() == "https",
              components.host != nil,
              let url = components.url else {
            errorMessage = "Saisissez une URL HTTPS valide pour votre agenda iCalendar."
            return
        }

        let requestID = UUID()
        activeRequestID = requestID
        isLoading = true
        errorMessage = nil

        do {
            var request = URLRequest(url: url)
            request.setValue("text/calendar, text/plain;q=0.9, */*;q=0.5", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 30
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode) else {
                throw AgendaError.invalidResponse
            }
            guard let calendar = String(data: data, encoding: .utf8) else {
                throw AgendaError.invalidEncoding
            }
            let parsedEvents = try ICalendarParser.parse(calendar)
            guard activeRequestID == requestID else { return }
            events = parsedEvents
            lastRequestedURL = trimmedURL
            lastUpdated = .now
        } catch {
            guard activeRequestID == requestID else { return }
            errorMessage = error.localizedDescription
            if lastRequestedURL != trimmedURL {
                events = []
                lastUpdated = nil
            }
        }
        guard activeRequestID == requestID else { return }
        activeRequestID = nil
        isLoading = false
    }
}

private enum AgendaError: LocalizedError {
    case invalidResponse
    case invalidEncoding
    case invalidCalendar

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Le serveur de l’agenda a renvoyé une réponse invalide."
        case .invalidEncoding:
            "Le fichier iCalendar n’est pas encodé en UTF-8."
        case .invalidCalendar:
            "L’URL ne renvoie pas un agenda iCalendar valide."
        }
    }
}

private enum ICalendarParser {
    static func parse(_ source: String) throws -> [AgendaEvent] {
        var lines: [String] = []
        for line in source.components(separatedBy: .newlines) {
            if (line.hasPrefix(" ") || line.hasPrefix("\t")), !lines.isEmpty {
                lines[lines.count - 1].append(String(line.dropFirst()))
            } else {
                lines.append(line)
            }
        }

        var events: [AgendaEvent] = []
        var properties: [String: [(parameters: [String: String], value: String)]]?

        for line in lines {
            if line == "BEGIN:VEVENT" {
                properties = [:]
                continue
            }
            if line == "END:VEVENT" {
                if let properties, let event = makeEvent(properties) {
                    events.append(event)
                }
                properties = nil
                continue
            }
            guard properties != nil,
                  let separator = line.firstIndex(of: ":") else {
                continue
            }

            let keyAndParameters = line[..<separator].split(separator: ";")
            guard let rawKey = keyAndParameters.first else { continue }
            let key = rawKey.uppercased()
            var parameters: [String: String] = [:]
            for parameter in keyAndParameters.dropFirst() {
                let pair = parameter.split(separator: "=", maxSplits: 1)
                if pair.count == 2 {
                    parameters[pair[0].uppercased()] = String(pair[1]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                }
            }
            let value = String(line[line.index(after: separator)...])
            properties?[key, default: []].append((parameters, value))
        }

        guard source.contains("BEGIN:VCALENDAR"), !events.isEmpty else {
            throw AgendaError.invalidCalendar
        }
        return events.sorted { $0.start < $1.start }
    }

    private static func makeEvent(
        _ properties: [String: [(parameters: [String: String], value: String)]]
    ) -> AgendaEvent? {
        guard let startProperty = properties["DTSTART"]?.first,
              let start = parseDate(startProperty.value, parameters: startProperty.parameters) else {
            return nil
        }
        let endProperty = properties["DTEND"]?.first
        let end = endProperty.flatMap { parseDate($0.value, parameters: $0.parameters) }
        let uid = properties["UID"]?.first?.value ?? UUID().uuidString
        let title = properties["SUMMARY"]
            .flatMap { $0.first?.value }
            .map(unescape) ?? "Événement"
        let location = properties["LOCATION"]
            .flatMap { $0.first?.value }
            .map(unescape) ?? ""
        let details = properties["DESCRIPTION"]
            .flatMap { $0.first?.value }
            .map(unescape) ?? ""
        let isAllDay = startProperty.parameters["VALUE"]?.uppercased() == "DATE"
            || startProperty.value.count == 8

        return AgendaEvent(
            uid: uid,
            title: title,
            start: start,
            end: end,
            isAllDay: isAllDay,
            location: location,
            details: details
        )
    }

    private static func parseDate(_ value: String, parameters: [String: String]) -> Date? {
        let isDateOnly = parameters["VALUE"]?.uppercased() == "DATE" || value.count == 8
        let isUTC = value.hasSuffix("Z")
        let rawDate = isUTC ? String(value.dropLast()) : value
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = isUTC
            ? TimeZone(secondsFromGMT: 0)
            : parameters["TZID"].flatMap(TimeZone.init(identifier:)) ?? .current
        formatter.dateFormat = isDateOnly ? "yyyyMMdd" : (rawDate.count >= 15 ? "yyyyMMdd'T'HHmmss" : "yyyyMMdd'T'HHmm")
        return formatter.date(from: rawDate)
    }

    private static func unescape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\N", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}

struct AgendaView: View {
    @ObservedObject var viewModel: AgendaViewModel
    let calendarURL: String?
    @Binding var selectedTab: Int
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)

    private var selectedDayEvents: [AgendaEvent] {
        guard let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else {
            return []
        }
        return viewModel.events
            .filter { event in
                let overlapsSelectedDay = event.end.map { end in
                    end > selectedDate
                } ?? (event.start >= selectedDate)
                return event.start < nextDay && overlapsSelectedDay
            }
            .sorted { $0.start < $1.start }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("STUDY BUDY")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.7)
                            .foregroundStyle(AppPalette.accent)
                        Text("Agenda")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(AppPalette.foreground)
                    }
                    Spacer()
                    Button {
                        guard let calendarURL else {
                            selectedTab = 2
                            return
                        }
                        Task { await viewModel.refresh(calendarURL: calendarURL) }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(AppPalette.accent)
                                .frame(width: 46, height: 46)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppPalette.foreground)
                                .frame(width: 46, height: 46)
                        }
                    }
                    .background(AppPalette.card, in: Circle())
                    .disabled(viewModel.isLoading && calendarURL != nil)
                    .accessibilityLabel("Actualiser l’agenda")
                }
                .padding(.top, 18)

                HStack(spacing: 10) {
                    Button {
                        changeSelectedDate(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppPalette.foreground)
                            .frame(width: 42, height: 42)
                            .background(AppPalette.card, in: Circle())
                    }
                    .accessibilityLabel("Jour précédent")

                    DatePicker(
                        "Date de l’agenda",
                        selection: $selectedDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)
                    .environment(\.locale, Locale(identifier: "fr_FR"))
                    .labelsHidden()
                    .tint(AppPalette.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .frame(height: 48)
                    .background(AppPalette.card, in: Capsule())

                    Button {
                        changeSelectedDate(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppPalette.foreground)
                            .frame(width: 42, height: 42)
                            .background(AppPalette.card, in: Circle())
                    }
                    .accessibilityLabel("Jour suivant")
                }

                if let lastUpdated = viewModel.lastUpdated {
                    Label("Mis à jour \(lastUpdated.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.circle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppPalette.muted)
                }

                if let errorMessage = viewModel.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(Color.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                }

                if calendarURL == nil {
                    ContentUnavailableView {
                        Label("Configurez votre agenda", systemImage: "calendar.badge.plus")
                    } description: {
                        Text("Ajoutez l’URL iCalendar de votre emploi du temps dans les paramètres pour afficher vos événements ici.")
                    } actions: {
                        Button {
                            selectedTab = 2
                        } label: {
                            Label("Ouvrir les paramètres", systemImage: "slider.horizontal.3")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppPalette.accent)
                    }
                    .foregroundStyle(AppPalette.foreground)
                    .padding(.top, 24)
                } else if viewModel.isLoading && viewModel.events.isEmpty {
                    ProgressView("Chargement de l’agenda…")
                        .tint(AppPalette.accent)
                        .foregroundStyle(AppPalette.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 36)
                } else if selectedDayEvents.isEmpty {
                    ContentUnavailableView(
                        "Aucun événement ce jour",
                        systemImage: "calendar",
                        description: Text("Choisissez une autre date ou actualisez l’agenda.")
                    )
                    .foregroundStyle(AppPalette.foreground)
                    .padding(.top, 24)
                } else {
                    Text(selectedDate.formatted(
                        .dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "fr_FR"))
                    ).capitalized)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppPalette.foreground)

                    ForEach(selectedDayEvents) { event in
                        agendaEventCard(event)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 32)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(AppPalette.background)
        .refreshable {
            if let calendarURL {
                await viewModel.refresh(calendarURL: calendarURL)
            }
        }
    }

    private func changeSelectedDate(by days: Int) {
        guard let date = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) else {
            return
        }
        selectedDate = date
    }

    private func agendaEventCard(_ event: AgendaEvent) -> some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 2)
                .fill(AppPalette.accent)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(event.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppPalette.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Text(event.isAllDay ? "Toute la journée" : event.start.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppPalette.accent)
                        .fixedSize()
                }

                if let end = event.end, !event.isAllDay {
                    Text("Jusqu’à \(end.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 12))
                        .foregroundStyle(AppPalette.muted)
                }
                if !event.location.isEmpty {
                    Label(event.location, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 12))
                        .foregroundStyle(AppPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !event.details.isEmpty {
                    Text(event.details)
                        .font(.system(size: 12))
                        .foregroundStyle(AppPalette.muted)
                        .lineLimit(3)
                }
            }
            .padding(.vertical, 2)
        }
        .padding(15)
        .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 17))
    }
}
