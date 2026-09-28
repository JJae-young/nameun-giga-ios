import SwiftUI

struct PlanSetupView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dvTheme) private var theme
    @State private var draft: PlanSettings
    @State private var limitText: String
    @State private var currentUsageText: String
    @State private var tracksHotspotLimit: Bool
    @State private var hotspotLimitText: String
    @State private var hotspotUsageText = ""
    @State private var hotspotAlert80: Bool
    @State private var hotspotAlert90: Bool
    private let isInitialSetup: Bool
    private let isResettingInputs: Bool
    /// The plan already tracked a hotspot allowance before this form opened.
    private let hadHotspotLimit: Bool
    let onSave: (PlanSettings) -> Void

    init(
        plan: PlanSettings,
        isInitialSetup: Bool = false,
        isResettingInputs: Bool = false,
        onSave: @escaping (PlanSettings) -> Void
    ) {
        let isInitialSetup = isInitialSetup || isResettingInputs
        var initialPlan = plan
        if isInitialSetup {
            initialPlan.alert50 = false
            initialPlan.alert80 = false
            initialPlan.alert90 = false
        }
        _draft = State(initialValue: initialPlan)
        _limitText = State(
            initialValue: isInitialSetup
                ? ""
                : DataAmountFormatter.gigabyteInput(from: plan.dataLimitBytes ?? (160 * DataBytes.gigabyte))
        )
        _currentUsageText = State(
            initialValue: plan.manualAdjustmentBytes > 0
                ? DataAmountFormatter.gigabyteInput(from: plan.manualAdjustmentBytes)
                : ""
        )
        let hotspot = plan.hotspot
        _tracksHotspotLimit = State(initialValue: hotspot?.hasLimit ?? false)
        _hotspotLimitText = State(
            initialValue: (hotspot?.hasLimit ?? false)
                ? DataAmountFormatter.gigabyteInput(from: hotspot?.limitBytes ?? 0)
                : ""
        )
        _hotspotAlert80 = State(initialValue: isInitialSetup ? false : (hotspot?.alert80 ?? true))
        _hotspotAlert90 = State(initialValue: isInitialSetup ? false : (hotspot?.alert90 ?? true))
        self.isInitialSetup = isInitialSetup
        self.isResettingInputs = isResettingInputs
        self.hadHotspotLimit = !isInitialSetup && (plan.hotspot?.hasLimit ?? false)
        self.onSave = onSave
    }

    private var parsedLimit: Int64? { DataAmountFormatter.gigabytes(from: limitText) }
    private var parsedCurrentUsage: Int64? {
        if currentUsageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return isResettingInputs ? nil : 0
        }
        return DataAmountFormatter.gigabytes(from: currentUsageText, allowingZero: true)
    }
    private var parsedHotspotLimit: Int64? { DataAmountFormatter.gigabytes(from: hotspotLimitText) }
    private var parsedHotspotUsage: Int64? {
        if hotspotUsageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return 0
        }
        return DataAmountFormatter.gigabytes(from: hotspotUsageText, allowingZero: true)
    }
    /// Installing (or enabling the allowance) mid-period: the hotspot already
    /// used this period can only come from the carrier, so ask for it.
    private var asksHotspotUsage: Bool { isInitialSetup || !hadHotspotLimit }
    private var hotspotLimitMessage: String? {
        guard let parsedHotspotLimit else { return nil }
        return HotspotPlanValidator.limitMessage(
            hotspotLimitBytes: parsedHotspotLimit,
            dataLimitBytes: draft.isUnlimited ? nil : parsedLimit
        )
    }
    private var hotspotUsageMessage: String? {
        guard asksHotspotUsage,
              !hotspotUsageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let used = parsedHotspotUsage else { return nil }
        return HotspotPlanValidator.usageMessage(
            hotspotUsedBytes: used,
            hotspotLimitBytes: parsedHotspotLimit,
            dataUsedBytes: isInitialSetup ? parsedCurrentUsage : nil
        )
    }
    private var isHotspotValid: Bool {
        guard tracksHotspotLimit else { return true }
        return parsedHotspotLimit != nil
            && hotspotLimitMessage == nil
            && (!asksHotspotUsage || (parsedHotspotUsage != nil && hotspotUsageMessage == nil))
    }
    private var isValid: Bool {
        (draft.isUnlimited || parsedLimit != nil)
            && (!isInitialSetup || parsedCurrentUsage != nil)
            && isHotspotValid
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DVSpacing.l) {
                    if isResettingInputs {
                        Text("요금제와 통신사 사용량을 다시 입력해 주세요. 저장하면 기존 입력값과 알림 설정을 대체합니다. 일별 측정 기록과 테마는 유지됩니다.")
                            .font(.footnote)
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let error = appModel.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(theme.danger)
                                .accessibilityIdentifier("plan-save-error")
                        }
                    }
                    SectionCard {
                        VStack(alignment: .leading, spacing: DVSpacing.l) {
                            Label("월 데이터 용량", systemImage: "antenna.radiowaves.left.and.right")
                                .font(.headline)
                            Toggle("무제한 요금제", isOn: $draft.isUnlimited)
                            if !draft.isUnlimited {
                                HStack {
                                    TextField("160", text: $limitText)
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .keyboardType(.decimalPad)
                                        .monospacedDigit()
                                        .accessibilityLabel("월 데이터 용량")
                                    Text("GB")
                                        .font(.headline)
                                        .foregroundStyle(theme.textSecondary)
                                }
                                .padding(DVSpacing.l)
                                .background(theme.subtle, in: RoundedRectangle(cornerRadius: DVRadius.small))
                                .overlay {
                                    RoundedRectangle(cornerRadius: DVRadius.small)
                                        .stroke(theme.borderSoft, lineWidth: 1)
                                }
                                if !limitText.isEmpty && parsedLimit == nil {
                                    Text("0보다 크고 10,000GB 이하의 값을 입력해 주세요.")
                                        .font(.caption)
                                        .foregroundStyle(theme.danger)
                                }
                            }
                        }
                    }

                    SectionCard {
                        HStack {
                            Label("데이터 초기화일", systemImage: "calendar")
                                .font(.headline)
                            Spacer()
                            Picker("초기화일", selection: $draft.resetDay) {
                                ForEach(1...31, id: \.self) { day in
                                    Text("매월 \(day)일").tag(day)
                                }
                            }
                            .labelsHidden()
                        }
                    }

                    if isInitialSetup {
                        SectionCard {
                            VStack(alignment: .leading, spacing: DVSpacing.m) {
                                Label("이번 주기에 이미 쓴 데이터", systemImage: "arrow.down.circle.fill")
                                    .font(.headline)
                                HStack {
                                    TextField(isResettingInputs ? "필수 · 0부터 시작하려면 0" : "선택 사항", text: $currentUsageText)
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .keyboardType(.decimalPad)
                                        .monospacedDigit()
                                        .accessibilityLabel("현재 통신사 표시 사용량")
                                    Text("GB")
                                        .font(.headline)
                                        .foregroundStyle(theme.textSecondary)
                                }
                                .padding(DVSpacing.l)
                                .background(theme.subtle, in: RoundedRectangle(cornerRadius: DVRadius.small))
                                .overlay {
                                    RoundedRectangle(cornerRadius: DVRadius.small)
                                        .stroke(theme.borderSoft, lineWidth: 1)
                                }
                                Text(isResettingInputs
                                    ? "통신사 앱의 현재 사용량을 입력하세요. 0을 입력하면 저장 시점부터 새로 합산합니다. 기존 일별 기록은 통계에 남아 월 사용량과 다를 수 있습니다."
                                    : "통신사 앱에 표시된 현재 사용량을 입력하면 처음부터 반영합니다. 비워두면 남은기가 설치 이후부터 측정합니다.")
                                    .font(.footnote)
                                    .foregroundStyle(theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                if !currentUsageText.isEmpty && parsedCurrentUsage == nil {
                                    Text(isResettingInputs ? "0 이상 10,000GB 이하의 값을 입력해 주세요." : "0 이상 10,000GB 이하의 값을 입력하거나 비워 두세요.")
                                        .font(.caption)
                                        .foregroundStyle(theme.danger)
                                }
                            }
                        }
                    }

                    hotspotSection

                    SectionCard {
                        VStack(alignment: .leading, spacing: DVSpacing.m) {
                            Label("데이터 사용량 알림", systemImage: "bell.fill")
                                .font(.headline)
                            Toggle("50% 사용 시", isOn: $draft.alert50)
                            Toggle("80% 사용 시", isOn: $draft.alert80)
                            Toggle("90% 사용 시", isOn: $draft.alert90)
                        }
                    }

                    HStack(alignment: .top, spacing: DVSpacing.m) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(theme.accentMintStrong)
                        Text("남은기가는 앱 설치 후 공개 네트워크 카운터의 변화량을 측정합니다. 통신사 청구량과 차이가 날 수 있어요.")
                            .font(.footnote)
                            .foregroundStyle(theme.textSecondary)
                    }
                    .padding(.horizontal, DVSpacing.s)

                    if !isResettingInputs, let error = appModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(theme.danger)
                            .accessibilityIdentifier("plan-save-error")
                    }

                    Button(isResettingInputs ? "새 설정 저장" : (isInitialSetup ? "남은기가 시작하기" : "설정 저장"), action: saveDraft)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!isValid)
                    .opacity(isValid ? 1 : 0.45)
                    .padding(.top, DVSpacing.s)
                }
                .padding(DVSpacing.xl)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .background { DataViewThemeBackground() }
            .tint(theme.accentMintStrong)
            .navigationTitle(isResettingInputs ? "입력값 다시 설정" : "요금제 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isResettingInputs {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("저장", action: saveDraft)
                            .disabled(!isValid)
                    }
                }
            }
        }
    }

    private func saveDraft() {
        guard isValid else { return }
        draft.dataLimitBytes = draft.isUnlimited ? nil : parsedLimit
        if isInitialSetup {
            draft.manualAdjustmentBytes = parsedCurrentUsage ?? 0
            draft.manualAdjustmentPeriodStart = nil
            draft.manualAdjustmentMeasuredBytes = nil
        }
        applyHotspotSettings()
        onSave(draft)
    }

    private var hotspotSection: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: DVSpacing.l) {
                Label("핫스팟(테더링) 제공량", systemImage: "personalhotspot")
                    .font(.headline)
                Toggle("핫스팟 제공량 설정", isOn: $tracksHotspotLimit)
                    .accessibilityIdentifier("hotspot-limit-toggle")
                if tracksHotspotLimit {
                    Text("월 데이터 중 핫스팟으로 쓸 수 있는 최대량")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                    HStack {
                        TextField("50", text: $hotspotLimitText)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .keyboardType(.decimalPad)
                            .monospacedDigit()
                            .accessibilityLabel("핫스팟 한도")
                            .accessibilityIdentifier("hotspot-limit-input")
                        Text("GB")
                            .font(.headline)
                            .foregroundStyle(theme.textSecondary)
                    }
                    .padding(DVSpacing.l)
                    .background(theme.subtle, in: RoundedRectangle(cornerRadius: DVRadius.small))
                    .overlay {
                        RoundedRectangle(cornerRadius: DVRadius.small)
                            .stroke(theme.borderSoft, lineWidth: 1)
                    }
                    if !hotspotLimitText.isEmpty && parsedHotspotLimit == nil {
                        Text("0보다 크고 10,000GB 이하의 값을 입력해 주세요.")
                            .font(.caption)
                            .foregroundStyle(theme.danger)
                    } else if let hotspotLimitMessage {
                        Text(hotspotLimitMessage)
                            .font(.caption)
                            .foregroundStyle(theme.danger)
                    }

                    if asksHotspotUsage {
                        Text("이번 주기에 이미 쓴 핫스팟")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)
                        HStack {
                            TextField("선택 사항", text: $hotspotUsageText)
                                .font(.body.weight(.semibold))
                                .keyboardType(.decimalPad)
                                .monospacedDigit()
                                .accessibilityLabel("현재 통신사 표시 핫스팟 사용량")
                                .accessibilityIdentifier("hotspot-used-input")
                            Text("GB")
                                .font(.headline)
                                .foregroundStyle(theme.textSecondary)
                        }
                        .padding(DVSpacing.m)
                        .background(theme.subtle, in: RoundedRectangle(cornerRadius: DVRadius.small))
                        if !hotspotUsageText.isEmpty && parsedHotspotUsage == nil {
                            Text("0 이상 10,000GB 이하의 값을 입력하거나 비워 두세요.")
                                .font(.caption)
                                .foregroundStyle(theme.danger)
                        } else if let hotspotUsageMessage {
                            Text(hotspotUsageMessage)
                                .font(.caption)
                                .foregroundStyle(theme.danger)
                        }
                        Text("데이터 초기화일 이후에 설치했다면 통신사 앱의 핫스팟(테더링) 사용량을 입력하세요. 저장한 뒤부터 쓰는 핫스팟은 남은기가 앱이 측정해 더합니다. 비워 두면 앱이 측정한 값만 사용합니다.")
                            .font(.footnote)
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("이미 쓴 핫스팟 값을 고치려면 설정의 '핫스팟 값 맞추기'를 사용하세요.")
                            .font(.footnote)
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Toggle("핫스팟 80% 사용 시 알림", isOn: $hotspotAlert80)
                    Toggle("핫스팟 90% 사용 시 알림", isOn: $hotspotAlert90)
                }
                Text("예: 월 160GB 중 핫스팟은 50GB까지. 핫스팟 사용량은 전체 데이터에도 포함되며, 기기 카운터로 추정합니다(베타).")
                    .font(.footnote)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Writes the hotspot section into the draft while keeping an existing
    /// carrier hotspot calibration when only the limit or alerts change.
    private func applyHotspotSettings() {
        if tracksHotspotLimit, let limit = parsedHotspotLimit {
            var hotspot = draft.hotspot ?? HotspotPlanSettings(limitBytes: limit)
            hotspot.limitBytes = limit
            hotspot.alert80 = hotspotAlert80
            hotspot.alert90 = hotspotAlert90
            let hasEnteredUsage = !hotspotUsageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if isInitialSetup {
                hotspot.manualAdjustmentBytes = parsedHotspotUsage ?? 0
                hotspot.manualAdjustmentPeriodStart = nil
                hotspot.manualAdjustmentMeasuredBytes = nil
            } else if asksHotspotUsage, hasEnteredUsage, let used = parsedHotspotUsage {
                // Enabling the allowance mid-period: the carrier's current
                // hotspot figure becomes this period's base, anchored on save.
                hotspot.manualAdjustmentBytes = used
                hotspot.manualAdjustmentPeriodStart = nil
                hotspot.manualAdjustmentMeasuredBytes = nil
            }
            draft.hotspot = hotspot
        } else if var hotspot = draft.hotspot {
            hotspot.limitBytes = 0
            hotspot.alert80 = false
            hotspot.alert90 = false
            if hotspot.manualAdjustmentPeriodStart == nil && hotspot.manualAdjustmentBytes == 0 {
                draft.hotspot = nil
            } else {
                draft.hotspot = hotspot
            }
        }
    }
}
