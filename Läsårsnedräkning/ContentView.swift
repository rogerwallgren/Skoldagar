import SwiftUI

struct ContentView: View {
    @State private var store = SchoolCalendarStore()
    @State private var isShowingSettings = false
    @State private var isShowingInfo = false

    var body: some View {
        let schoolYear = store.schoolYear
        NavigationStack {
            ZStack {
                SchoolYearBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        WelcomeHeader()

                        if store.hasImportedSchoolYear {
                            SummerCountdownCard(
                                daysRemaining: schoolYear.schoolDaysRemaining(
                                    until: schoolYear.summerBreakStart
                                ),
                                summerBreakStart: schoolYear.summerBreakStart
                            )

                            if let nextMilestone = schoolYear.nextMilestone {
                                NextBreakCard(
                                    title: nextMilestone.title,
                                    symbolName: nextMilestone.symbolName,
                                    date: nextMilestone.date,
                                    daysRemaining: schoolYear.schoolDaysRemaining(
                                        until: nextMilestone.date
                                    )
                                )
                            }

                            MilestoneSection(
                                milestones: schoolYear.milestones,
                                schoolYear: schoolYear
                            )
                            DataSourceCard(
                                importState: store.importState,
                                openSettings: { isShowingSettings = true }
                            )
                        } else {
                            SetupGuideCard(
                                openSettings: { isShowingSettings = true }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Skoldagar")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Om appen", systemImage: "info.circle") {
                        isShowingInfo = true
                    }
                    .labelStyle(.iconOnly)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kalenderinställningar", systemImage: "gearshape") {
                        isShowingSettings = true
                    }
                    .labelStyle(.iconOnly)
                }
            }
            .sheet(isPresented: $isShowingInfo) {
                AppInfoView()
            }
            .sheet(isPresented: $isShowingSettings) {
                CalendarSettingsView(store: store)
            }
            .task {
                if case .idle = store.importState,
                   !store.sourceURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    await store.importCalendar()
                }
            }
        }
    }
}

private struct SchoolYearBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.98, blue: 1),
                Color(red: 1, green: 0.95, blue: 0.88)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct WelcomeHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hej! 👋")
                .font(.largeTitle.bold())
            Text("Varje skoldag tar dig lite närmare sommarlovet.")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SetupGuideCard: View {
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Kom igång", systemImage: "sparkles")
                .font(.title2.bold())
                .foregroundStyle(.blue)

            Text("Lägg in skolans läsårstider så räknar appen ut skoldagarna till loven.")
                .foregroundStyle(.secondary)

            SetupStep(
                number: 1,
                title: "Hitta läsårstiderna",
                detail: "Öppna skolans webbsida med lov och terminsdatum."
            )
            SetupStep(
                number: 2,
                title: "Kopiera länken",
                detail: "Klistra in sidans adress i kalenderinställningarna."
            )
            SetupStep(
                number: 3,
                title: "Komplettera kalendern",
                detail: "Lägg till studiedagar eller andra lediga dagar som saknas."
            )

            Button("Lägg in skolans kalender", systemImage: "calendar.badge.plus") {
                openSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.65), lineWidth: 1)
        }
    }
}

private struct SetupStep: View {
    let number: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number, format: .number)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(.blue, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SummerCountdownCard: View {
    let daysRemaining: Int
    let summerBreakStart: Date

    var body: some View {
        VStack(spacing: 14) {
            Label("Till sommarlovet", systemImage: "sun.max.fill")
                .font(.headline)
                .foregroundStyle(.yellow)

            Text(daysRemaining, format: .number)
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .contentTransition(.numericText())

            Text("skoldagar kvar")
                .font(.title3.bold())

            Text(summerBreakStart, format: .dateTime.day().month(.wide).year())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(.white.opacity(0.65), lineWidth: 1)
        }
        .shadow(color: .orange.opacity(0.16), radius: 22, y: 12)
    }
}

private struct NextBreakCard: View {
    let title: String
    let symbolName: String
    let date: Date
    let daysRemaining: Int

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbolName)
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 48, height: 48)
                .background(.orange.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("Nästa delmål")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.title3.bold())
                Text(date, format: .dateTime.day().month(.wide))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 0) {
                Text(daysRemaining, format: .number)
                    .font(.title.bold())
                Text("dagar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct MilestoneSection: View {
    let milestones: [SchoolMilestone]
    let schoolYear: SchoolYearCalendar

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Läsårets delmål")
                .font(.title2.bold())

            ForEach(milestones) { milestone in
                MilestoneRow(
                    title: milestone.title,
                    symbolName: milestone.symbolName,
                    date: milestone.date,
                    daysRemaining: schoolYear.schoolDaysRemaining(until: milestone.date),
                    tint: milestone.tint
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MilestoneRow: View {
    let title: String
    let symbolName: String
    let date: Date
    let daysRemaining: Int
    let tint: MilestoneTint

    private var color: Color {
        switch tint {
        case .orange: .orange
        case .blue: .blue
        case .pink: .pink
        }
    }

    var body: some View {
        HStack {
            Image(systemName: symbolName)
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(date, format: .dateTime.day().month(.wide))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(daysRemaining) skoldagar")
                .font(.subheadline.bold())
                .foregroundStyle(color)
        }
        .padding()
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct DataSourceCard: View {
    let importState: CalendarImportState
    let openSettings: () -> Void

    var body: some View {
        Button(action: openSettings) {
            HStack(spacing: 12) {
                Image(systemName: statusSymbol)
                    .foregroundStyle(statusColor)

                VStack(alignment: .leading, spacing: 3) {
                    Text(statusTitle)
                        .font(.headline)
                    Text(statusDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private var statusTitle: String {
        switch importState {
        case .idle: "Skolkalender"
        case .loading: "Hämtar läsårstider…"
        case .success: "Skolkalender uppdaterad"
        case .failed: "Kunde inte uppdatera"
        }
    }

    private var statusDetail: String {
        switch importState {
        case .idle:
            "Tryck för att välja skolans webbsida."
        case .loading:
            "Läser lov, studiedagar och terminsdatum."
        case .success(let date):
            "Senast hämtad \(date.formatted(date: .abbreviated, time: .shortened))."
        case .failed(let message):
            message
        }
    }

    private var statusSymbol: String {
        switch importState {
        case .idle: "calendar.badge.clock"
        case .loading: "arrow.trianglehead.2.clockwise.rotate.90"
        case .success: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch importState {
        case .idle, .loading: .blue
        case .success: .green
        case .failed: .orange
        }
    }
}

private struct AppInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label {
                        Text("Appen räknar vardagar fram till varje delmål.")
                    } icon: {
                        Image(systemName: "calendar")
                            .foregroundStyle(.blue)
                    }

                    Label {
                        Text("Helger, lov, helgdagar och egna lediga dagar räknas bort.")
                    } icon: {
                        Image(systemName: "calendar.badge.minus")
                            .foregroundStyle(.orange)
                    }

                    Label {
                        Text("Egna lediga dagar visas också som nedräkningar.")
                    } icon: {
                        Image(systemName: "list.bullet")
                            .foregroundStyle(.pink)
                    }
                } header: {
                    Text("Så fungerar det")
                }

                Section {
                    Text("Läsårstiderna hämtas från webbsidan du väljer och sparas på enheten. Samma kalender delas med appens widget.")
                } header: {
                    Text("Kalenderdata")
                }

                Section {
                    Text("Widgeten uppdateras automatiskt när kalendern ändras och efter varje dygnsskifte.")
                } header: {
                    Text("Widget")
                }

                Section {
                    Text("Skapad av Roger Wallgren · 2026")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Om Skoldagar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct CalendarSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: SchoolCalendarStore
    @State private var isAddingCustomDay = false
    @State private var selectedMilestone: SchoolMilestone?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "https://skola.se/lasarstider/",
                        text: $store.sourceURLString,
                        axis: .vertical
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                } header: {
                    Text("Skolans webbsida")
                } footer: {
                    Text("Sidan behöver innehålla läsår, lov och terminsdatum som vanlig text.")
                }

                Section {
                    Button {
                        Task {
                            await store.importCalendar()
                        }
                    } label: {
                        HStack {
                            Text("Hämta läsårstider")
                            Spacer()
                            if case .loading = store.importState {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(store.importState == .loading)
                }

                if store.hasImportedSchoolYear {
                    Section {
                        DatePicker(
                            "Sommarlovet börjar",
                            selection: Binding(
                                get: { store.schoolYear.summerBreakStart },
                                set: { store.updateSummerBreakStart($0) }
                            ),
                            displayedComponents: .date
                        )

                        ForEach(store.schoolYear.milestones) { milestone in
                            Button {
                                selectedMilestone = milestone
                            } label: {
                                HStack {
                                    Label(milestone.title, systemImage: milestone.symbolName)
                                    Spacer()
                                    Text(
                                        milestone.date,
                                        format: .dateTime.day().month(.abbreviated)
                                    )
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: store.removeMilestones)
                    } header: {
                        Text("Inlästa datum")
                    } footer: {
                        Text("Tryck på ett lov för att ändra namn eller datum. Svep åt vänster för att ta bort det.")
                    }

                    Section {
                        ForEach(store.automaticDaysOff) { day in
                            HStack {
                                Text(day.title)
                                Spacer()
                                Text(
                                    day.date,
                                    format: .dateTime.day().month(.abbreviated)
                                )
                                .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Automatiskt borträknade dagar")
                    } footer: {
                        Text("Varje datum räknas bara en gång, även när en helgdag infaller under ett lov.")
                    }
                }

                Section("Egna lediga dagar") {
                    ForEach(store.customDays) { day in
                        CustomSchoolDayRow(title: day.title, date: day.date)
                    }
                    .onDelete(perform: store.removeCustomDays)

                    Button("Lägg till ledig dag", systemImage: "plus") {
                        isAddingCustomDay = true
                    }
                }

                if case .failed(let message) = store.importState {
                    Section("Problem") {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Skolkalender")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Stäng") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isAddingCustomDay) {
                AddCustomSchoolDayView { title, date in
                    store.addCustomDay(title: title, date: date)
                }
            }
            .sheet(item: $selectedMilestone) { milestone in
                EditMilestoneView(milestone: milestone) { title, date in
                    store.updateMilestone(id: milestone.id, title: title, date: date)
                }
            }
        }
    }
}

private struct EditMilestoneView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var date: Date
    let save: (String, Date) -> Void

    init(milestone: SchoolMilestone, save: @escaping (String, Date) -> Void) {
        _title = State(initialValue: milestone.title)
        _date = State(initialValue: milestone.date)
        self.save = save
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Namn", text: $title)
                DatePicker("Startdatum", selection: $date, displayedComponents: .date)
            }
            .navigationTitle("Redigera lov")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") {
                        save(title, date)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct CustomSchoolDayRow: View {
    let title: String
    let date: Date

    var body: some View {
        HStack {
            Label(title, systemImage: "calendar.badge.minus")
            Spacer()
            Text(date, format: .dateTime.day().month(.abbreviated))
                .foregroundStyle(.secondary)
        }
    }
}

private struct AddCustomSchoolDayView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = "Studiedag"
    @State private var date = Date()
    let save: (String, Date) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Namn", text: $title)

                DatePicker(
                    "Datum",
                    selection: $date,
                    displayedComponents: .date
                )
            }
            .navigationTitle("Ny ledig dag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Lägg till") {
                        save(title, date)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
