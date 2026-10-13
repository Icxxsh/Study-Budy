import SwiftUI
import WebKit
import Security
import UIKit

enum AppPalette {
    private static let defaultAccent = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.40, green: 0.79, blue: 0.69, alpha: 1)
            : UIColor(red: 0.12, green: 0.48, blue: 0.39, alpha: 1)
    }

    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.055, green: 0.075, blue: 0.12, alpha: 1)
            : .systemGroupedBackground
    })
    static let card = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.10, green: 0.13, blue: 0.19, alpha: 1)
            : .secondarySystemGroupedBackground
    })
    static let foreground = Color(uiColor: .label)
    static let muted = Color(uiColor: .secondaryLabel)
    static var accent: Color {
        guard let hex = UserDefaults.standard.string(forKey: "accentColorHex"),
              let color = Color(hex: hex) else {
            return Color(uiColor: defaultAccent)
        }
        return color
    }
    static let highlight = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.06)
            : UIColor.black.withAlphaComponent(0.035)
    })
    static let border = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.08)
            : UIColor.black.withAlphaComponent(0.08)
    })
}

extension Color {
    init?(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            opacity: 1
        )
    }

    var hexString: String? {
        let color = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: nil) else { return nil }
        return String(
            format: "#%02X%02X%02X",
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded())
        )
    }
}

struct ContentView: View {
    @StateObject private var session = WebAurionSession.shared
    @StateObject private var agenda = AgendaViewModel()
    @State private var username = ""
    @State private var password = ""
    @State private var selectedTab = 0
    @State private var agendaURL: String?
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("accentColorHex") private var accentColorHex = ""
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            AppPalette.background.ignoresSafeArea()

            if let grades = session.grades {
                TabView(selection: $selectedTab) {
                    gradesView(grades)
                        .tabItem {
                            Label("Notes", systemImage: "graduationcap")
                        }
                        .tag(0)

                    AgendaView(
                        viewModel: agenda,
                        calendarURL: agendaURL,
                        selectedTab: $selectedTab
                    )
                        .tabItem {
                            Label("Agenda", systemImage: "calendar")
                        }
                        .tag(1)

                    SettingsView(
                        session: session,
                        calendarURL: $agendaURL,
                        appearance: $appearance,
                        accentColorHex: $accentColorHex
                    )
                    .tabItem {
                        Label("Paramètres", systemImage: "slider.horizontal.3")
                    }
                    .tag(2)
                }
                .tint(AppPalette.accent)
                .transition(.opacity)
            } else {
                loginView
                    .transition(.opacity)
            }

            WebAurionBrowserView(session: session)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .accessibilityHidden(true)
        }
        .preferredColorScheme(preferredColorScheme)
        .animation(.easeInOut(duration: 0.25), value: session.grades != nil)
        .task {
            session.restoreSavedCredentials()
            switch CredentialsKeychain.loadAgendaURL() {
            case .success(let savedURL):
                agendaURL = savedURL
            case .failure(let error):
                agenda.setLoadError("Impossible de lire l’URL de l’agenda enregistrée : \(error.localizedDescription)")
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, let agendaURL else { return }
            Task {
                await agenda.refresh(calendarURL: agendaURL)
            }
        }
        .onChange(of: agendaURL) { _, newValue in
            guard let newValue else {
                agenda.clearEvents()
                return
            }
            Task {
                await agenda.refresh(calendarURL: newValue)
            }
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearance {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    private var loginView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                HStack {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(AppPalette.background)
                        .frame(width: 48, height: 48)
                        .background(AppPalette.accent, in: RoundedRectangle(cornerRadius: 16))
                    Text("CARNET")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .tracking(2.2)
                        .foregroundStyle(AppPalette.foreground.opacity(0.8))
                    Spacer()
                    Image(systemName: "sparkles")
                        .foregroundStyle(AppPalette.accent)
                }
                .padding(.top, 26)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Vos résultats,\nplus simplement.")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .tracking(-1.1)
                        .foregroundStyle(AppPalette.foreground)
                    Text("Retrouvez vos notes et leurs coefficients au même endroit.")
                        .font(.system(size: 16))
                        .foregroundStyle(AppPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 18) {
                    credentialField(title: "Identifiant", symbol: "person", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.default)
                        .textContentType(.username)

                    VStack(alignment: .leading, spacing: 9) {
                        Text("MOT DE PASSE")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(AppPalette.muted)
                        HStack(spacing: 12) {
                            Image(systemName: "lock")
                                .foregroundStyle(AppPalette.muted)
                                .frame(width: 20)
                            SecureField("Votre mot de passe", text: $password)
                                .textContentType(.password)
                                .submitLabel(.go)
                                .onSubmit(signIn)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                        .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppPalette.border))
                    }

                    if let error = session.errorMessage {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.52))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(action: signIn) {
                        HStack(spacing: 10) {
                            if session.isLoading {
                                ProgressView().tint(AppPalette.background)
                            } else {
                                Text("Voir mes notes")
                                Image(systemName: "arrow.right")
                            }
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppPalette.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(AppPalette.accent, in: RoundedRectangle(cornerRadius: 17))
                    }
                    .disabled(session.isLoading || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                    .opacity(session.isLoading ? 0.75 : 1)
                }
                .padding(20)
                .background(AppPalette.highlight, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppPalette.border))

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(AppPalette.accent)
                    Text("Vos identifiants sont conservés dans le trousseau sécurisé de cet iPhone pour reconnecter automatiquement l’app.")
                        .font(.footnote)
                        .foregroundStyle(AppPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 3)
                Spacer(minLength: 18)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
    }

    private func credentialField(title: String, symbol: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(AppPalette.muted)
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(AppPalette.muted)
                    .frame(width: 20)
                TextField(title, text: text)
                    .textContentType(.username)
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppPalette.border))
        }
    }

    private func signIn() {
        session.signIn(username: username, password: password)
        password = ""
    }

    private func gradesView(_ grades: [GradeRecord]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("STUDY BUDY")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.7)
                            .foregroundStyle(AppPalette.accent)
                        Text("Mes notes")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(AppPalette.foreground)
                    }
                    Spacer()
                    if session.isRefreshingGrades {
                        ProgressView()
                            .tint(AppPalette.accent)
                            .frame(width: 24, height: 24)
                            .accessibilityLabel("Actualisation des notes en cours")
                    }
                    Button {
                        session.signOut()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppPalette.foreground)
                            .frame(width: 46, height: 46)
                            .background(AppPalette.card, in: Circle())
                    }
                    .accessibilityLabel("Se déconnecter")
                }
                .padding(.top, 18)

                HStack(spacing: 14) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppPalette.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(grades.count) \(grades.count > 1 ? "évaluations" : "évaluation")")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppPalette.foreground)
                        Text("Données synchronisées avec WebAurion")
                            .font(.system(size: 12))
                            .foregroundStyle(AppPalette.muted)
                    }
                    Spacer()
                }
                .padding(18)
                .background(
                    LinearGradient(colors: [AppPalette.card, AppPalette.card.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 20)
                )

                if let error = session.errorMessage {
                    Label(error, systemImage: "exclamationmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(Color(red: 1, green: 0.65, blue: 0.55))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                }

                if grades.isEmpty {
                    ContentUnavailableView(
                        "Aucune note publiée",
                        systemImage: "tray",
                        description: Text("Vos évaluations apparaîtront ici dès leur publication sur WebAurion.")
                    )
                    .foregroundStyle(AppPalette.foreground)
                    .padding(.top, 28)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("ÉVALUATIONS")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(AppPalette.muted)
                            .padding(.leading, 3)

                        ForEach(Array(grades.enumerated()), id: \.offset) { _, grade in
                            gradeCard(grade)
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 32)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .refreshable { session.refresh() }
    }

    private func gradeCard(_ grade: GradeRecord) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(grade.name.isEmpty ? "Évaluation" : grade.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppPalette.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                    if !grade.detail.isEmpty {
                        Text(grade.detail)
                            .font(.system(size: 13))
                            .foregroundStyle(AppPalette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 6)
                Text(grade.note.isEmpty ? "—" : grade.note)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(grade.note.isEmpty ? AppPalette.muted : AppPalette.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppPalette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }

            if !grade.startDate.isEmpty || !grade.endDate.isEmpty {
                Label(dateRange(grade), systemImage: "calendar")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppPalette.muted)
            }

            if !grade.examCoefficient.isEmpty || !grade.courseCoefficient.isEmpty {
                Rectangle()
                    .fill(AppPalette.border)
                    .frame(height: 1)
                HStack(spacing: 8) {
                    if !grade.examCoefficient.isEmpty {
                        coefficientPill("Coeff. épreuve", value: grade.examCoefficient)
                    }
                    if !grade.courseCoefficient.isEmpty {
                        coefficientPill("Coeff. CC/CT matière", value: grade.courseCoefficient)
                    }
                }
            }

            if !grade.otherFields.isEmpty {
                Rectangle()
                    .fill(AppPalette.border)
                    .frame(height: 1)
                ForEach(Array(grade.otherFields.enumerated()), id: \.offset) { _, field in
                    HStack(alignment: .top, spacing: 12) {
                        Text(field.name)
                            .foregroundStyle(AppPalette.muted)
                        Spacer(minLength: 8)
                        Text(field.value)
                            .foregroundStyle(AppPalette.foreground.opacity(0.9))
                            .multilineTextAlignment(.trailing)
                    }
                    .font(.system(size: 12))
                }
            }
        }
        .padding(18)
        .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppPalette.border))
    }

    private func coefficientPill(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppPalette.muted)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppPalette.foreground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppPalette.highlight, in: RoundedRectangle(cornerRadius: 12))
    }

    private func dateRange(_ grade: GradeRecord) -> String {
        if grade.startDate.isEmpty { return grade.endDate }
        if grade.endDate.isEmpty || grade.startDate == grade.endDate { return grade.startDate }
        return "\(grade.startDate) – \(grade.endDate)"
    }
}

private struct GradeRecord: Codable {
    let name: String
    let detail: String
    let startDate: String
    let endDate: String
    let note: String
    let examCoefficient: String
    let courseCoefficient: String
    let otherFields: [GradeField]
}

private struct GradeField: Codable {
    let name: String
    let value: String
}

private struct GradePage: Decodable {
    let headers: [String]
    let rows: [[String]]
    let title: String?
    let tableCount: Int?
    let visibleHeaders: [String]?
    let pageURL: String?
    let dataTableCount: Int?
    let rowCount: Int?
}

struct SavedCredentials: Codable {
    let username: String
    let password: String
}

enum CredentialsKeychain {
    private static let service = "fr.centralelille.webaurion"
    private static let account = "webaurion-login"
    private static let agendaAccount = "webaurion-agenda-ical-url"

    static func load() -> Result<SavedCredentials?, Error> {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return .success(nil)
        }
        guard status == errSecSuccess else {
            return .failure(keychainError(status))
        }
        guard let data = result as? Data else {
            return .failure(KeychainFailure.invalidStoredData)
        }
        do {
            return .success(try JSONDecoder().decode(SavedCredentials.self, from: data))
        } catch {
            return .failure(error)
        }
    }

    static func save(_ credentials: SavedCredentials) -> Result<Void, Error> {
        do {
            let data = try JSONEncoder().encode(credentials)
            let attributes: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
            if status == errSecSuccess {
                return .success(())
            }
            guard status == errSecItemNotFound else {
                return .failure(keychainError(status))
            }

            var addQuery = baseQuery
            attributes.forEach { addQuery[$0.key] = $0.value }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                return .failure(keychainError(addStatus))
            }
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    static func delete() -> Result<Void, Error> {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            return .failure(keychainError(status))
        }
        return .success(())
    }

    static func loadAgendaURL() -> Result<String?, Error> {
        var query = baseQuery(account: agendaAccount)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return .success(nil)
        }
        guard status == errSecSuccess else {
            return .failure(keychainError(status))
        }
        guard let data = result as? Data,
              let url = String(data: data, encoding: .utf8) else {
            return .failure(KeychainFailure.invalidStoredData)
        }
        return .success(url)
    }

    static func saveAgendaURL(_ url: String) -> Result<Void, Error> {
        guard let data = url.data(using: .utf8) else {
            return .failure(KeychainFailure.invalidStoredData)
        }
        let query = baseQuery(account: agendaAccount)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess {
            return .success(())
        }
        guard status == errSecItemNotFound else {
            return .failure(keychainError(status))
        }

        var addQuery = query
        attributes.forEach { addQuery[$0.key] = $0.value }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            return .failure(keychainError(addStatus))
        }
        return .success(())
    }

    static func deleteAgendaURL() -> Result<Void, Error> {
        let status = SecItemDelete(baseQuery(account: agendaAccount) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            return .failure(keychainError(status))
        }
        return .success(())
    }

    private static var baseQuery: [String: Any] {
        baseQuery(account: account)
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private static func keychainError(_ status: OSStatus) -> NSError {
        NSError(
            domain: NSOSStatusErrorDomain,
            code: Int(status),
            userInfo: [NSLocalizedDescriptionKey: "Erreur du trousseau iOS (code \(status))."]
        )
    }

    private enum KeychainFailure: Error {
        case invalidStoredData
    }
}

@MainActor
final class WebAurionSession: NSObject, ObservableObject, WKNavigationDelegate {
    static let shared = WebAurionSession()
    private static let cachedGradesKey = "cachedWebAurionGrades"
    @Published fileprivate var grades: [GradeRecord]?
    @Published private(set) var isLoading = false
    @Published private(set) var isCheckingSavedCredentials = true
    @Published private(set) var isSynchronizingSavedCredentials = false
    @Published private(set) var isRefreshingGrades = false
    @Published var errorMessage: String?

    private let baseURL = URL(string: "https://webaurion.centralelille.fr")!
    private var pendingCredentials: (username: String, password: String)?
    private var didSubmitCredentials = false
    private var isLoadingGrades = false
    private var menuNavigationStarted = false
    private var credentialsToRemember: SavedCredentials?
    private var didAttemptCredentialRestore = false

    override init() {
        super.init()
        guard let data = UserDefaults.standard.data(forKey: Self.cachedGradesKey) else { return }
        do {
            grades = try JSONDecoder().decode([GradeRecord].self, from: data)
        } catch {
            UserDefaults.standard.removeObject(forKey: Self.cachedGradesKey)
            errorMessage = "Impossible de lire les notes enregistrées : \(error.localizedDescription)"
        }
    }

    lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = self
        return view
    }()

    func signIn(username: String, password: String, preservingDisplayedGrades: Bool = false) {
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !password.isEmpty else {
            errorMessage = "Saisissez votre identifiant et votre mot de passe."
            return
        }
        if !preservingDisplayedGrades {
            grades = nil
            UserDefaults.standard.removeObject(forKey: Self.cachedGradesKey)
        }
        errorMessage = nil
        isLoading = true
        isRefreshingGrades = preservingDisplayedGrades
        didSubmitCredentials = false
        isLoadingGrades = false
        menuNavigationStarted = false
        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        credentialsToRemember = SavedCredentials(username: normalizedUsername, password: password)
        pendingCredentials = (normalizedUsername, password)
        webView.load(URLRequest(url: baseURL.appending(path: "/faces/Login.xhtml")))
    }

    func restoreSavedCredentials() {
        guard !didAttemptCredentialRestore else { return }
        didAttemptCredentialRestore = true
        switch CredentialsKeychain.load() {
        case .success(let credentials):
            isCheckingSavedCredentials = false
            guard let credentials else { return }
            isSynchronizingSavedCredentials = true
            signIn(
                username: credentials.username,
                password: credentials.password,
                preservingDisplayedGrades: grades != nil
            )
        case .failure(let error):
            isCheckingSavedCredentials = false
            errorMessage = "Impossible de lire les identifiants enregistrés : \(error.localizedDescription)"
        }
    }

    func signOut() {
        pendingCredentials = nil
        credentialsToRemember = nil
        didSubmitCredentials = false
        isLoadingGrades = false
        menuNavigationStarted = false
        isSynchronizingSavedCredentials = false
        isRefreshingGrades = false
        isCheckingSavedCredentials = false
        grades = nil
        UserDefaults.standard.removeObject(forKey: Self.cachedGradesKey)
        errorMessage = nil
        isLoading = true
        if case .failure(let error) = CredentialsKeychain.delete() {
            errorMessage = "Impossible d’effacer les identifiants enregistrés : \(error.localizedDescription)"
        }
        webView.configuration.websiteDataStore.removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        ) { [weak self] in
            Task { @MainActor in self?.isLoading = false }
        }
    }

    func refresh() {
        guard grades != nil else { return }
        errorMessage = nil
        isLoadingGrades = true
        isRefreshingGrades = true
        menuNavigationStarted = false
        webView.reload()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url, isTrustedHost(url.host) else { return }

        if let credentials = pendingCredentials, !didSubmitCredentials {
            submit(credentials, in: webView)
            return
        }

        guard didSubmitCredentials else { return }
        let path = url.path.lowercased()
        if path.contains("login") {
            finishWithError("Connexion refusée. Vérifiez votre identifiant et votre mot de passe.")
            return
        }

        if path == "/faces/choixdonnee.xhtml" {
            menuNavigationStarted = false
            extractGrades(from: webView)
            return
        }

        if path != "/faces/mainmenupage.xhtml" {
            isLoadingGrades = true
            menuNavigationStarted = false
            webView.load(URLRequest(url: baseURL.appending(path: "/faces/MainMenuPage.xhtml")))
            return
        }

        if path == "/faces/mainmenupage.xhtml" {
            startGradesNavigation(in: webView)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finishWithError("Impossible de charger WebAurion. Vérifiez votre connexion puis réessayez.")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finishWithError("Impossible de joindre WebAurion. Vérifiez votre connexion puis réessayez.")
    }

    private func startGradesNavigation(in webView: WKWebView) {
        guard !menuNavigationStarted else { return }
        menuNavigationStarted = true
        isLoadingGrades = true

        let script = """
        (() => {
          const normalize = value => value.normalize('NFD')
            .replace(/[\\u0300-\\u036f]/g, '')
            .replace(/\\s+/g, ' ').trim().toLowerCase();
          const findLink = label => [...document.querySelectorAll('a.ui-menuitem-link')]
            .find(link => normalize(link.innerText || link.textContent || '') === normalize(label)
              && link.getClientRects().length > 0);
          const waitForLink = (label, timeout = 8000) => new Promise(resolve => {
            const deadline = Date.now() + timeout;
            const check = () => {
              const link = findLink(label);
              if (link) return resolve(link);
              if (Date.now() >= deadline) return resolve(null);
              setTimeout(check, 200);
            };
            check();
          });
          (async () => {
            const results = await waitForLink('Résultats');
            if (!results) throw new Error('Résultats');
            results.click();
            const program = await waitForLink('IG2I');
            if (!program) throw new Error('IG2I');
            program.click();
            const grades = await waitForLink('Mes Notes aux épreuves');
            if (!grades) throw new Error('Mes Notes aux épreuves');
            grades.click();
          })().catch(error => {
            document.documentElement.dataset.gradesNavigationError = error.message;
          });
          return true;
        })()
        """
        webView.evaluateJavaScript(script) { [weak self, weak webView] result, error in
            guard let self else { return }
            if let error {
                self.menuNavigationStarted = false
                self.finishWithError("Impossible d’ouvrir le menu des notes WebAurion : \(error.localizedDescription)")
                return
            }
            guard (result as? Bool) == true else {
                self.menuNavigationStarted = false
                self.finishWithError("Le menu WebAurion n’a pas pu être lancé.")
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self, weak webView] in
                guard let self, self.isLoadingGrades, self.menuNavigationStarted,
                      let webView, webView.url?.path.lowercased() != "/faces/choixdonnee.xhtml" else {
                    return
                }
                webView.evaluateJavaScript("document.documentElement.dataset.gradesNavigationError || ''") { result, _ in
                    guard self.isLoadingGrades, self.menuNavigationStarted else { return }
                    let missingItem = result as? String ?? ""
                    let item = missingItem.isEmpty ? "le menu des notes" : missingItem
                    self.menuNavigationStarted = false
                    self.finishWithError("WebAurion n’a pas ouvert \(item). Vérifiez l’accès à cette rubrique puis réessayez.")
                }
            }
        }
    }

    private func submit(_ credentials: (username: String, password: String), in webView: WKWebView) {
        guard let username = Self.javascriptString(credentials.username),
              let password = Self.javascriptString(credentials.password) else {
            finishWithError("Impossible de préparer les informations de connexion.")
            return
        }
        let script = """
        (() => {
          const user = document.querySelector('input[name="username"], input#username');
          const pass = document.querySelector('input[name="password"], input#password');
          if (!user || !pass) return false;
          user.value = \(username);
          pass.value = \(password);
          user.dispatchEvent(new Event('input', { bubbles: true }));
          pass.dispatchEvent(new Event('input', { bubbles: true }));
          const form = pass.form || user.form;
          if (!form) return false;
          const submit = form.querySelector('button[type="submit"], input[type="submit"]');
          if (submit) submit.click(); else form.submit();
          return true;
        })()
        """
        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self else { return }
            if let error {
                self.finishWithError("La page de connexion n’a pas pu être traitée : \(error.localizedDescription)")
                return
            }
            guard (result as? Bool) == true else {
                self.finishWithError("Le formulaire de connexion WebAurion est introuvable.")
                return
            }
            self.didSubmitCredentials = true
            self.pendingCredentials = nil
        }
    }

    private func extractGrades(from webView: WKWebView) {
        let script = """
        (() => {
          const tables = [...new Set(document.querySelectorAll('table, [role="grid"]'))];
          const readHeader = cell =>
            (cell.getAttribute('aria-label') ||
             cell.getAttribute('title') ||
             cell.innerText ||
             cell.textContent ||
             '')
              .replace(/Filter by.*$/i, '')
              .replace(/:\\s*activer pour trier.*$/i, '')
              .trim();
          const headerElements = [...new Set(document.querySelectorAll(
            'th[aria-label], [role="columnheader"], thead th'
          ))];
          const visibleHeaders = headerElements.map(readHeader).filter(Boolean);
          const hasAssessment = header =>
            /épreuve|evaluation|contrôle|controle|matière|matiere|module/i.test(header);
          const hasGrade = header =>
            /note|résultat|resultat|grade/i.test(header);
          const headerSet = visibleHeaders.some(hasAssessment) && visibleHeaders.some(hasGrade);
          const readCell = cell => {
            const copy = cell.cloneNode(true);
            copy.querySelectorAll(
              '.ui-column-title, [class~="ui-column-title"], [data-prime-column-title]'
            ).forEach(label => label.remove());
            const value = copy.querySelector('.preformatted') || copy;
            return (value.textContent || '')
              .replace(/\\s+/g, ' ')
              .trim();
          };

          const candidates = tables.map(table => {
            const rows = [...table.querySelectorAll('tbody tr, [role="rowgroup"] [role="row"]')]
              .map(row => [...row.querySelectorAll('td, [role="gridcell"]')].map(readCell))
              .filter(row => row.length > 0);
            const width = rows.reduce((maximum, row) => Math.max(maximum, row.length), 0);
            const matchingHeaders = visibleHeaders.length > 0 && width === visibleHeaders.length;
            return { rows, width, matchingHeaders };
          }).filter(candidate => candidate.rows.length > 0);
          const match = candidates.sort((a, b) =>
            Number(b.matchingHeaders) - Number(a.matchingHeaders) ||
            b.width - a.width ||
            b.rows.length - a.rows.length
          )[0];
          const pageIsGrades = /mes notes aux épreuves|mes notes aux epreuves/i.test(document.title || '');
          const headers = headerSet ? visibleHeaders : [];
          const rows = match ? match.rows : [];
          return JSON.stringify({
            title: document.title || '',
            pageURL: location.href,
            tableCount: tables.length,
            visibleHeaders,
            dataTableCount: candidates.length,
            rowCount: rows.length,
            pageIsGrades,
            headers: headerSet && pageIsGrades ? headers : [],
            rows
          });
        })()
        """
        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self else { return }
            if let error {
                self.finishWithError("Impossible de lire les notes WebAurion : \(error.localizedDescription)")
                return
            }
            guard let json = result as? String,
                  let data = json.data(using: .utf8),
                  let page = try? JSONDecoder().decode(GradePage.self, from: data) else {
                self.finishWithError("WebAurion a renvoyé une réponse que l’app ne peut pas décoder.")
                return
            }
            guard page.headers.contains(where: Self.isAssessmentHeader) else {
                let title = page.title.flatMap { $0.isEmpty ? nil : " « \($0) »" } ?? ""
                let foundHeaders = page.visibleHeaders?
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ") ?? ""
                let headerDetails = foundHeaders.isEmpty
                    ? "aucune colonne détectée"
                    : "colonnes détectées : \(foundHeaders)"
                self.finishWithError(
                    "La page\(title) n’a pas pu associer les colonnes des notes à leurs lignes (\(headerDetails), tableaux : \(page.tableCount ?? 0), tableaux avec lignes : \(page.dataTableCount ?? 0), lignes : \(page.rowCount ?? 0))."
                )
                return
            }
            let records = Self.makeRecords(page)
            self.grades = records
            self.isLoading = false
            self.isLoadingGrades = false
            self.isSynchronizingSavedCredentials = false
            self.isRefreshingGrades = false
            var persistenceErrors: [String] = []
            do {
                let data = try JSONEncoder().encode(records)
                UserDefaults.standard.set(data, forKey: Self.cachedGradesKey)
            } catch {
                persistenceErrors.append("Notes actualisées, mais impossible de les mettre en cache : \(error.localizedDescription)")
            }
            if let credentials = self.credentialsToRemember {
                switch CredentialsKeychain.save(credentials) {
                case .success:
                    break
                case .failure(let error):
                    persistenceErrors.append("Notes chargées, mais impossible d’enregistrer les identifiants : \(error.localizedDescription)")
                }
            }
            self.errorMessage = persistenceErrors.isEmpty ? nil : persistenceErrors.joined(separator: "\n")
            self.credentialsToRemember = nil
        }
    }

    private func finishWithError(_ message: String) {
        guard isLoading || isLoadingGrades else { return }
        pendingCredentials = nil
        credentialsToRemember = nil
        isLoading = false
        isLoadingGrades = false
        isSynchronizingSavedCredentials = false
        isRefreshingGrades = false
        menuNavigationStarted = false
        errorMessage = message
    }

    private func isTrustedHost(_ host: String?) -> Bool {
        host == "webaurion.centralelille.fr" || host == "cas.centralelille.fr"
    }

    private static func makeRecords(_ page: GradePage) -> [GradeRecord] {
        func normalized(_ value: String) -> String {
            value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        }

        func column(matching terms: [String]) -> Int? {
            page.headers.firstIndex { header in
                let header = normalized(header)
                return terms.contains { header.contains(normalized($0)) }
            }
        }

        let nameIndex = column(matching: ["épreuve", "evaluation", "évaluation", "matière", "module"])
        let detailIndex = column(matching: ["détail", "description", "contrôle", "commentaire"])
        let startIndex = column(matching: ["début", "date de début", "date"])
        let endIndex = column(matching: ["fin", "date de fin"])
        let noteIndex = column(matching: ["note", "résultat", "grade"])
        let examCoefficientIndex = column(matching: ["coefficient de l'épreuve", "coefficient épreuve", "coef épreuve"])
        let courseCoefficientIndex = column(matching: ["coef de la moyenne du cc ou ct", "coefficient matière", "coef matière"])
        let knownIndexes = Set([
            nameIndex, detailIndex, startIndex, endIndex, noteIndex,
            examCoefficientIndex, courseCoefficientIndex
        ].compactMap { $0 })

        func value(_ row: [String], at index: Int?) -> String {
            guard let index, row.indices.contains(index) else { return "" }
            return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return page.rows.compactMap { row in
            let name = value(row, at: nameIndex)
            let detail = value(row, at: detailIndex)
            let note = value(row, at: noteIndex)
            let examCoefficient = value(row, at: examCoefficientIndex)
            let courseCoefficient = value(row, at: courseCoefficientIndex)
            guard row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                return nil
            }
            let otherFields = row.indices.compactMap { index -> GradeField? in
                guard !knownIndexes.contains(index) else { return nil }
                let fieldValue = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !fieldValue.isEmpty else { return nil }
                let label = page.headers.indices.contains(index) && !page.headers[index].isEmpty
                    ? page.headers[index]
                    : "Information \(index + 1)"
                return GradeField(name: label, value: fieldValue)
            }
            return GradeRecord(
                name: name.isEmpty ? "Évaluation" : name,
                detail: detail,
                startDate: value(row, at: startIndex),
                endDate: value(row, at: endIndex),
                note: note,
                examCoefficient: examCoefficient,
                courseCoefficient: courseCoefficient,
                otherFields: otherFields
            )
        }
    }

    private static func isAssessmentHeader(_ header: String) -> Bool {
        let normalized = header.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return ["epreuve", "evaluation", "controle", "matiere", "module"]
            .contains { normalized.contains($0) }
    }

    private static func javascriptString(_ value: String) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

private extension WebAurionSession {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if navigationAction.targetFrame == nil ||
            (navigationAction.targetFrame?.isMainFrame == true && !isTrustedHost(url.host)) {
            decisionHandler(.cancel)
            return
        }
        guard navigationAction.targetFrame?.isMainFrame == true else {
            decisionHandler(.allow)
            return
        }
        decisionHandler(.allow)
    }
}

private struct WebAurionBrowserView: UIViewRepresentable {
    @ObservedObject var session: WebAurionSession

    func makeUIView(context: Context) -> WKWebView {
        session.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
