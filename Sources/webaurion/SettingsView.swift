import SwiftUI

struct SettingsView: View {
    @ObservedObject var session: WebAurionSession
    @Binding var calendarURL: String?
    @Binding var appearance: String
    @Binding var accentColorHex: String

    @State private var calendarURLDraft = ""
    @State private var username = ""
    @State private var password = ""
    @State private var calendarMessage: String?
    @State private var credentialsMessage: String?
    @FocusState private var isCalendarURLFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("STUDY BUDY")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.7)
                        .foregroundStyle(AppPalette.accent)
                    Text("Paramètres")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(AppPalette.foreground)
                }
                .padding(.top, 18)

                VStack(alignment: .leading, spacing: 14) {
                    sectionTitle("APPARENCE", symbol: "circle.lefthalf.filled")
                    Picker("Apparence", selection: $appearance) {
                        Text("Système").tag("system")
                        Text("Clair").tag("light")
                        Text("Sombre").tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .tint(AppPalette.accent)

                    HStack(spacing: 12) {
                        ColorPicker(
                            "Couleur d’accentuation",
                            selection: Binding(
                                get: { AppPalette.accent },
                                set: { accentColorHex = $0.hexString ?? "" }
                            ),
                            supportsOpacity: false
                        )
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.foreground)

                        Button("Réinitialiser") {
                            accentColorHex = ""
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppPalette.accent)
                    }
                }
                .settingsCard()

                VStack(alignment: .leading, spacing: 14) {
                    sectionTitle("AGENDA ICALENDAR", symbol: "calendar")
                    Text("URL de votre calendrier")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppPalette.muted)
                    TextField("https://…", text: $calendarURLDraft, axis: .vertical)
                        .font(.system(size: 13))
                        .focused($isCalendarURLFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .padding(13)
                        .background(AppPalette.background, in: RoundedRectangle(cornerRadius: 12))

                    Button(action: saveCalendarURL) {
                        Label("Enregistrer l’URL", systemImage: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppPalette.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(AppPalette.accent, in: RoundedRectangle(cornerRadius: 13))
                    }

                    if let calendarMessage {
                        Text(calendarMessage)
                            .font(.footnote)
                            .foregroundStyle(calendarMessage.hasPrefix("URL enregistrée") || calendarMessage.hasPrefix("URL supprimée") ? AppPalette.accent : Color.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("L’agenda est rechargé à l’ouverture de l’app et après l’enregistrement d’une nouvelle URL.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    if calendarURL != nil {
                        Button(role: .destructive, action: deleteCalendarURL) {
                            Label("Supprimer l’URL enregistrée", systemImage: "trash")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.09), in: RoundedRectangle(cornerRadius: 13))
                        }
                    }
                }
                .settingsCard()

                VStack(alignment: .leading, spacing: 14) {
                    sectionTitle("IDENTIFIANTS WEB AURION", symbol: "lock.shield")
                    TextField("Identifiant", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(13)
                        .background(AppPalette.background, in: RoundedRectangle(cornerRadius: 12))

                    SecureField("Mot de passe", text: $password)
                        .textContentType(.password)
                        .padding(13)
                        .background(AppPalette.background, in: RoundedRectangle(cornerRadius: 12))

                    Button(action: saveCredentials) {
                        Label("Enregistrer les identifiants", systemImage: "key")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppPalette.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(AppPalette.accent, in: RoundedRectangle(cornerRadius: 13))
                    }
                    .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)

                    Button {
                        session.signIn(username: username, password: password)
                    } label: {
                        Label("Enregistrer et synchroniser", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppPalette.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(AppPalette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                    }
                    .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || session.isLoading)

                    if let credentialsMessage {
                        Text(credentialsMessage)
                            .font(.footnote)
                            .foregroundStyle(credentialsMessage.hasPrefix("Identifiants enregistrés") ? AppPalette.accent : Color.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Le mot de passe est conservé dans le trousseau sécurisé de l’iPhone.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .settingsCard()

                Button(role: .destructive) {
                    session.signOut()
                } label: {
                    Label("Se déconnecter et effacer les identifiants", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.red.opacity(0.09), in: RoundedRectangle(cornerRadius: 15))
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 22)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(AppPalette.background)
        .onAppear(perform: loadSettings)
        .onChange(of: calendarURL) { _, newValue in
            calendarURLDraft = newValue ?? ""
        }
    }

    private func sectionTitle(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(AppPalette.accent)
    }

    private func loadSettings() {
        calendarURLDraft = calendarURL ?? ""
        switch CredentialsKeychain.load() {
        case .success(let credentials):
            username = credentials?.username ?? ""
            password = credentials?.password ?? ""
        case .failure(let error):
            credentialsMessage = "Impossible de lire les identifiants enregistrés : \(error.localizedDescription)"
        }
    }

    private func saveCalendarURL() {
        isCalendarURLFocused = false
        let value = calendarURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: value),
              components.scheme?.lowercased() == "https",
              components.host != nil,
              components.url != nil else {
            calendarMessage = "Saisissez une URL HTTPS valide."
            return
        }
        switch CredentialsKeychain.saveAgendaURL(value) {
        case .success:
            calendarURL = value
            calendarMessage = "URL enregistrée dans le trousseau. L’agenda va être actualisé."
        case .failure(let error):
            calendarMessage = "Impossible d’enregistrer l’URL : \(error.localizedDescription)"
        }
    }

    private func deleteCalendarURL() {
        switch CredentialsKeychain.deleteAgendaURL() {
        case .success:
            calendarURL = nil
            calendarURLDraft = ""
            calendarMessage = "URL supprimée du trousseau."
        case .failure(let error):
            calendarMessage = "Impossible de supprimer l’URL : \(error.localizedDescription)"
        }
    }

    private func saveCredentials() {
        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedUsername.isEmpty, !password.isEmpty else {
            credentialsMessage = "Saisissez un identifiant et un mot de passe."
            return
        }
        switch CredentialsKeychain.save(SavedCredentials(username: normalizedUsername, password: password)) {
        case .success:
            username = normalizedUsername
            credentialsMessage = "Identifiants enregistrés dans le trousseau."
        case .failure(let error):
            credentialsMessage = "Impossible d’enregistrer les identifiants : \(error.localizedDescription)"
        }
    }
}

private extension View {
    func settingsCard() -> some View {
        padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppPalette.border))
    }
}
