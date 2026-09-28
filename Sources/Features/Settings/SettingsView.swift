import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dvTheme) private var theme
    @AppStorage("displayTheme") private var appearanceMode = DataViewAppearanceMode.system.rawValue
    @AppStorage("visualTheme") private var visualTheme = DataViewVisualTheme.classicBlue.rawValue
    @State private var showingPlan = false
    @State private var showingCalibration = false
    @State private var showingHotspotSync = false
    @State private var showingPrivacy = false
    @State private var showingResetConfirmation = false
    @State private var showingResetSetup = false

    var body: some View {
        NavigationStack {
            List {
                Section("데이터") {
                    Button {
                        showingPlan = true
                    } label: {
                        SettingsRow(icon: "simcard.fill", title: "요금제 설정", value: planLabel)
                    }
                    .buttonStyle(.plain)
                    Button {
                        showingCalibration = true
                    } label: {
                        SettingsRow(icon: "equal.circle.fill", title: "통신사 값 맞추기", value: calibrationLabel)
                    }
                    .buttonStyle(.plain)
                    Button {
                        showingHotspotSync = true
                    } label: {
                        SettingsRow(icon: "personalhotspot", title: "핫스팟 값 맞추기", value: hotspotLabel)
                    }
                    .buttonStyle(.plain)
                    Button {
                        showingResetConfirmation = true
                    } label: {
                        SettingsRow(icon: "arrow.counterclockwise", title: "입력값 초기화", value: "다시 설정")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("reset-inputs-button")
                }

                if appModel.plan?.hotspot?.hasLimit == true {
                    Section("핫스팟 알림") {
                        hotspotNotificationToggle("핫스팟 80% 사용 시", keyPath: \.alert80)
                        hotspotNotificationToggle("핫스팟 90% 사용 시", keyPath: \.alert90)
                    }
                }

                Section("알림") {
                    if appModel.plan?.isUnlimited == true {
                        Text("사용량 한도가 없는 요금제에서는 비율 알림을 사용하지 않습니다.")
                            .font(.footnote)
                            .foregroundStyle(theme.textSecondary)
                    } else {
                        notificationToggle("50% 사용 시", keyPath: \.alert50)
                        notificationToggle("80% 사용 시", keyPath: \.alert80)
                        notificationToggle("90% 사용 시", keyPath: \.alert90)
                    }
                }

                Section {
                    DesignThemeRow(
                        visualTheme: .classicBlue,
                        isSelected: selectedVisualTheme == .classicBlue
                    ) {
                        visualTheme = DataViewVisualTheme.classicBlue.rawValue
                    }
                    DesignThemeRow(
                        visualTheme: .softPastel,
                        isSelected: selectedVisualTheme == .softPastel
                    ) {
                        visualTheme = DataViewVisualTheme.softPastel.rawValue
                    }
                } header: {
                    Text("디자인 테마")
                } footer: {
                    Text("디자인과 표시 모드는 앱과 홈 화면 위젯에 함께 적용됩니다.")
                }

                Section("표시 모드") {
                    Picker(selection: $appearanceMode) {
                        Text("시스템 설정 따르기").tag(DataViewAppearanceMode.system.rawValue)
                        Text("라이트").tag(DataViewAppearanceMode.light.rawValue)
                        Text("다크").tag(DataViewAppearanceMode.dark.rawValue)
                    } label: {
                        Label("화면 모드", systemImage: "circle.lefthalf.filled")
                    }
                    SettingsRow(icon: "ruler", title: "단위", value: "자동")
                }

                Section("측정") {
                    NavigationLink {
                        MeasurementStatusView()
                    } label: {
                        SettingsRow(icon: "waveform.path.ecg", title: "측정 상태", value: statusLabel)
                    }
                    #if DEBUG
                    NavigationLink {
                        InterfaceDiagnosticsView()
                    } label: {
                        SettingsRow(icon: "stethoscope", title: "인터페이스 진단")
                    }
                    #endif
                }

                Section("개인정보") {
                    Button {
                        showingPrivacy = true
                    } label: {
                        SettingsRow(icon: "lock.shield.fill", title: "개인정보 처리 안내")
                    }
                    .buttonStyle(.plain)
                }

                Section {
                    VStack(spacing: 4) {
                        LogoMark(color: .secondary, height: 18)
                        Text(versionLabel)
                        Text("앱 측정 기준")
                            .font(.caption)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background { DataViewThemeBackground() }
            .tint(theme.accentMintStrong)
            .navigationTitle("설정")
            .alert("입력값을 다시 설정할까요?", isPresented: $showingResetConfirmation) {
                Button("취소", role: .cancel) { }
                Button("다시 설정") {
                    appModel.errorMessage = nil
                    showingResetSetup = true
                }
            } message: {
                Text("요금제·사용량 보정값·알림을 새로 입력합니다. 측정 기록과 테마는 삭제하지 않습니다. 다음 화면에서 저장하기 전까지 기존 설정이 유지됩니다.")
            }
            .sheet(isPresented: $showingResetSetup) {
                PlanSetupView(plan: .standard, isResettingInputs: true) { plan in
                    if appModel.savePlan(plan, resettingInputs: true) { showingResetSetup = false }
                }
            }
            .sheet(isPresented: $showingPlan) {
                PlanSetupView(plan: appModel.plan ?? .standard) { plan in
                    if appModel.savePlan(plan) { showingPlan = false }
                }
            }
            .sheet(isPresented: $showingCalibration) {
                CarrierUsageSyncView()
            }
            .sheet(isPresented: $showingHotspotSync) {
                HotspotUsageSyncView()
            }
            .sheet(isPresented: $showingPrivacy) {
                PrivacyInfoView()
            }
        }
    }

    private var planLabel: String {
        guard let plan = appModel.plan else { return "설정 필요" }
        if plan.isUnlimited { return "무제한" }
        return DataAmountFormatter.string(from: plan.dataLimitBytes ?? 0)
    }

    private var selectedVisualTheme: DataViewVisualTheme {
        DataViewVisualTheme(rawValue: visualTheme) ?? .classicBlue
    }

    private var versionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "남은기가 \(version) (\(build))"
    }

    private var hotspotLabel: String {
        guard let hotspot = appModel.plan?.hotspot else { return "필요 시" }
        if hotspot.manualAdjustmentPeriodStart != nil { return "적용 중" }
        return hotspot.hasLimit ? DataAmountFormatter.string(from: hotspot.limitBytes) : "필요 시"
    }

    private var calibrationLabel: String {
        guard appModel.plan?.manualAdjustmentPeriodStart != nil else { return "필요 시" }
        return "적용 중"
    }

    private var statusLabel: String {
        switch appModel.lastQuality {
        case .verified: "최근 측정 완료"
        case .partial: "일부 측정"
        case .estimated: "추정"
        case .unavailable: "기준 설정 중"
        }
    }

    @ViewBuilder
    private func hotspotNotificationToggle(
        _ title: String,
        keyPath: WritableKeyPath<HotspotPlanSettings, Bool>
    ) -> some View {
        Toggle(title, isOn: Binding(
            get: { appModel.plan?.hotspot?[keyPath: keyPath] ?? false },
            set: { newValue in
                guard var plan = appModel.plan, var hotspot = plan.hotspot else { return }
                hotspot[keyPath: keyPath] = newValue
                plan.hotspot = hotspot
                appModel.savePlan(plan)
            }
        ))
    }

    @ViewBuilder
    private func notificationToggle(_ title: String, keyPath: WritableKeyPath<PlanSettings, Bool>) -> some View {
        Toggle(title, isOn: Binding(
            get: { appModel.plan?[keyPath: keyPath] ?? false },
            set: { newValue in
                guard var plan = appModel.plan else { return }
                plan[keyPath: keyPath] = newValue
                appModel.savePlan(plan)
            }
        ))
    }
}

private struct DesignThemeRow: View {
    @Environment(\.dvTheme) private var theme
    let visualTheme: DataViewVisualTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DVSpacing.m) {
                ThemeSwatches(visualTheme: visualTheme)
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(theme.accentMintStrong)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(isSelected ? "선택됨" : "선택 안 됨")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var title: String {
        switch visualTheme {
        case .classicBlue: "Classic Blue"
        case .softPastel: "Soft Pastel"
        }
    }
}

private struct ThemeSwatches: View {
    let visualTheme: DataViewVisualTheme

    var body: some View {
        HStack(spacing: -5) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                Circle()
                    .fill(color)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(.white.opacity(0.75), lineWidth: 1))
            }
        }
        .frame(width: 70, alignment: .leading)
        .accessibilityHidden(true)
    }

    private var colors: [Color] {
        switch visualTheme {
        case .classicBlue:
            [
                Color(red: 47 / 255, green: 128 / 255, blue: 237 / 255),
                Color(red: 69 / 255, green: 184 / 255, blue: 245 / 255),
                Color(red: 23 / 255, green: 105 / 255, blue: 224 / 255),
                Color(red: 16 / 255, green: 34 / 255, blue: 61 / 255)
            ]
        case .softPastel:
            [
                Color(red: 116 / 255, green: 215 / 255, blue: 196 / 255),
                Color(red: 168 / 255, green: 216 / 255, blue: 255 / 255),
                Color(red: 195 / 255, green: 181 / 255, blue: 250 / 255),
                Color(red: 247 / 255, green: 196 / 255, blue: 215 / 255)
            ]
        }
    }
}

private struct SettingsRow: View {
    @Environment(\.dvTheme) private var theme
    let icon: String
    let title: String
    var value: String? = nil

    var body: some View {
        HStack(spacing: DVSpacing.m) {
            Image(systemName: icon)
                .foregroundStyle(theme.accentMintStrong)
                .frame(width: 24)
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            if let value {
                Text(value)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
    }
}

struct CarrierUsageSyncView: View {
    private enum InputKind: String, CaseIterable, Identifiable {
        case used = "사용량"
        case remaining = "남은 데이터"

        var id: Self { self }
    }

    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dvTheme) private var theme
    @State private var inputKind: InputKind = .used
    @State private var usedText = ""
    @State private var remainingText = ""
    @State private var saveError: String?
    @State private var inputPeriodStart: Date?

    private var text: Binding<String> {
        inputKind == .used ? $usedText : $remainingText
    }

    private var enteredBytes: Int64? {
        DataAmountFormatter.gigabytes(from: text.wrappedValue, allowingZero: true)
    }

    private var validationMessage: String? {
        guard !text.wrappedValue.isEmpty else { return nil }
        guard enteredBytes != nil else { return "0 이상 10,000GB 이하의 숫자를 입력해 주세요." }
        if inputKind == .remaining, carrierUsageBytes == nil {
            return "남은 데이터가 요금제 용량보다 큽니다. 같은 데이터 항목의 잔여량인지 확인해 주세요."
        }
        return nil
    }

    private var carrierUsageBytes: Int64? {
        guard let enteredBytes else { return nil }
        switch inputKind {
        case .used:
            return enteredBytes
        case .remaining:
            guard let limit = appModel.plan?.dataLimitBytes,
                  appModel.plan?.isUnlimited == false else { return nil }
            return UsageCalibrationService().usedBytes(
                fromRemaining: enteredBytes,
                limitBytes: limit
            )
        }
    }

    private var supportsRemainingInput: Bool {
        appModel.plan?.isUnlimited == false && appModel.plan?.dataLimitBytes != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if supportsRemainingInput {
                        Picker("입력할 값", selection: $inputKind) {
                            ForEach(InputKind.allCases) { kind in
                                Text(kind.rawValue).tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    HStack {
                        TextField("통신사에 표시된 값", text: text)
                            .keyboardType(.decimalPad)
                            .font(.title2.bold())
                            .accessibilityLabel("통신사 \(inputKind.rawValue), GB")
                            .accessibilityIdentifier("carrier-amount-input")
                        Text("GB")
                            .foregroundStyle(.secondary)
                    }
                    if let validationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(theme.danger)
                    }
                } header: {
                    Text("통신사 앱에 표시된 \(inputKind.rawValue)")
                } footer: {
                    Text("통신사 앱을 갱신한 뒤 값을 입력해 주세요. 남은 데이터는 요금제에 설정한 용량과 같은 항목을 기준으로 합니다.")
                }

                if let carrierUsageBytes {
                    Section {
                        LabeledContent(
                            "현재 사용량",
                            value: "\(DataAmountFormatter.gigabyteInput(from: carrierUsageBytes)) GB"
                        )
                        .fontWeight(.semibold)
                    } header: {
                        Text("적용 결과")
                    } footer: {
                        Text("이 값을 현재 사용 주기의 기준으로 저장하고, 이후 남은기가 앱이 측정한 변화량을 더합니다. 다음 사용 주기에는 자동으로 초기화됩니다.")
                    }
                }

                if let saveError {
                    Section {
                        Text(saveError)
                            .font(.footnote)
                            .foregroundStyle(theme.danger)
                            .accessibilityIdentifier("carrier-save-error")
                    }
                }

                Section {
                    Label {
                        Text("저장한 값은 이번 주기 합계와 위젯에 반영됩니다. 오늘 사용량과 과거 차트는 앱이 측정한 기록을 유지합니다.")
                    } icon: {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(theme.accentMintStrong)
                    }
                    .font(.footnote)
                    .foregroundStyle(theme.textSecondary)
                }
            }
            .navigationTitle("통신사 값 맞추기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        guard let carrierUsageBytes else { return }
                        if appModel.saveManualCalibration(bytes: carrierUsageBytes, expectedPeriodStart: inputPeriodStart) {
                            dismiss()
                        } else {
                            saveError = appModel.errorMessage ?? "저장하지 못했습니다. 다시 시도해 주세요."
                            let newPeriodStart = currentPeriodStart
                            if inputPeriodStart != newPeriodStart {
                                usedText = ""
                                remainingText = ""
                                inputPeriodStart = newPeriodStart
                            }
                        }
                    }
                    .disabled(carrierUsageBytes == nil)
                }
            }
            .onAppear { inputPeriodStart = currentPeriodStart }
            .onChange(of: inputKind) { _, _ in saveError = nil }
            .onChange(of: usedText) { old, new in if !new.isEmpty, old != new { saveError = nil } }
            .onChange(of: remainingText) { old, new in if !new.isEmpty, old != new { saveError = nil } }
        }
    }

    private var currentPeriodStart: Date {
        BillingPeriodService().currentPeriod(
            now: .now,
            resetDay: appModel.plan?.resetDay ?? 1,
            calendar: appModel.billingCalendar
        ).start
    }
}

private struct PrivacyInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dvTheme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DVSpacing.xl) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(theme.accentMintStrong)
                    Text("사용량은 기기에만 저장됩니다")
                        .font(.title2.bold())
                    Text("남은기가는 계정을 요구하지 않고, 측정한 데이터 사용량을 외부 서버로 전송하지 않습니다. 위젯에는 화면 표시에 필요한 요약값만 앱 그룹을 통해 공유합니다.")
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                    Divider()
                    Label("통신사 계정 정보 저장 안 함", systemImage: "person.crop.circle.badge.xmark")
                    Label("광고 SDK 미포함", systemImage: "megaphone.fill")
                    Label("원시 인터페이스 정보 외부 전송 안 함", systemImage: "network.badge.shield.half.filled")
                }
                .padding(DVSpacing.xl)
            }
            .background { DataViewThemeBackground() }
            .navigationTitle("개인정보")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
    }
}
