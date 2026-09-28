import SwiftUI

/// Home card for Personal Hotspot usage. Values come from the device's local
/// sharing-interface counters and are labelled as beta until they have been
/// checked against carrier values on real devices.
struct HotspotUsageCard: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dvTheme) private var theme
    let onSync: () -> Void

    private var summary: WidgetSummary { appModel.summary }

    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: DVSpacing.m) {
                HStack(alignment: .firstTextBaseline) {
                    Label("핫스팟", systemImage: "personalhotspot")
                        .font(.headline)
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Text("베타")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(theme.accentLavenderForeground)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(theme.tintLavender, in: Capsule())
                        .accessibilityLabel("베타 기능")
                }

                if let limit = summary.hotspotLimitBytes,
                   let remaining = summary.hotspotRemainingBytes,
                   let percent = summary.hotspotUsagePercent {
                    HStack(alignment: .firstTextBaseline, spacing: DVSpacing.s) {
                        Text(DataAmountFormatter.remainingString(from: remaining))
                            .font(.title2.bold())
                            .foregroundStyle(theme.textPrimary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text("남음")
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                    }
                    ProgressView(value: min(1, max(0, percent)))
                        .tint(progressTint(for: percent))
                        .accessibilityLabel("핫스팟 사용 비율")
                        .accessibilityValue("\(Int((percent * 100).rounded()))퍼센트")
                    Text("\(DataAmountFormatter.string(from: limit)) 중 \(DataAmountFormatter.string(from: summary.hotspotBytes ?? 0)) 사용")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .monospacedDigit()
                    if isLimitedByTotalData(limit: limit, remaining: remaining) {
                        Text("전체 남은 데이터가 더 적어서 핫스팟도 \(DataAmountFormatter.remainingString(from: remaining))까지만 쓸 수 있어요.")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(theme.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text(DataAmountFormatter.string(from: summary.hotspotBytes ?? 0))
                        .font(.title2.bold())
                        .foregroundStyle(theme.textPrimary)
                        .monospacedDigit()
                    Text("이번 주기 핫스팟 사용")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }

                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onSync) {
                    Label("통신사 핫스팟 값으로 맞추기", systemImage: "arrow.left.arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(theme.accentMintStrong)
                .accessibilityIdentifier("hotspot-sync-button")
            }
        }
    }

    private var statusMessage: String {
        if summary.hotspotSupportState == .unsupported {
            return "아직 이 iPhone에서 핫스팟 트래픽을 감지하지 못했어요. 핫스팟을 사용한 뒤 앱을 열면 측정값이 쌓입니다."
        }
        return "핫스팟 사용량은 전체 데이터에도 포함돼요. 기기 카운터로 추정한 값이라, 핫스팟을 쓰는 동안 앱이 한 번도 측정하지 못하면 일부가 빠질 수 있어요."
    }

    private func isLimitedByTotalData(limit: Int64, remaining: Int64) -> Bool {
        let used = summary.hotspotBytes ?? 0
        return limit - min(limit, used) > remaining
    }

    private func progressTint(for percent: Double) -> Color {
        if percent >= 0.9 { return theme.danger }
        if percent >= 0.8 { return theme.warning }
        return theme.accentLavenderForeground
    }
}

/// Saves the carrier's hotspot (tethering) figure as this period's base.
struct HotspotUsageSyncView: View {
    private enum InputKind: String, CaseIterable, Identifiable {
        case used = "사용량"
        case remaining = "남은 핫스팟"

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

    private var limitBytes: Int64? {
        guard let hotspot = appModel.plan?.hotspot, hotspot.hasLimit else { return nil }
        return hotspot.limitBytes
    }

    private var carrierUsageBytes: Int64? {
        guard let enteredBytes else { return nil }
        switch inputKind {
        case .used:
            return enteredBytes
        case .remaining:
            guard let limitBytes else { return nil }
            return UsageCalibrationService().usedBytes(
                fromRemaining: enteredBytes,
                limitBytes: limitBytes
            )
        }
    }

    private var validationMessage: String? {
        guard !text.wrappedValue.isEmpty else { return nil }
        guard enteredBytes != nil else { return "0 이상 10,000GB 이하의 숫자를 입력해 주세요." }
        if inputKind == .remaining, carrierUsageBytes == nil {
            return "남은 핫스팟이 설정한 핫스팟 한도보다 큽니다. 같은 항목의 잔여량인지 확인해 주세요."
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if limitBytes != nil {
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
                            .accessibilityLabel("통신사 핫스팟 \(inputKind.rawValue), GB")
                            .accessibilityIdentifier("hotspot-amount-input")
                        Text("GB")
                            .foregroundStyle(.secondary)
                    }
                    if let validationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(theme.danger)
                    }
                } header: {
                    Text("통신사 앱에 표시된 핫스팟 \(inputKind == .used ? "사용량" : "잔여량")")
                } footer: {
                    Text("통신사 앱의 테더링·핫스팟 항목을 갱신한 뒤 입력해 주세요.")
                }

                if let carrierUsageBytes {
                    Section {
                        LabeledContent(
                            "핫스팟 사용량",
                            value: "\(DataAmountFormatter.gigabyteInput(from: carrierUsageBytes)) GB"
                        )
                        .fontWeight(.semibold)
                    } header: {
                        Text("적용 결과")
                    } footer: {
                        Text("이 값을 이번 주기 핫스팟 기준으로 저장하고, 이후 DataView가 감지한 핫스팟 사용량을 더합니다. 다음 주기에는 자동으로 초기화됩니다.")
                    }
                }

                if let saveError {
                    Section {
                        Text(saveError)
                            .font(.footnote)
                            .foregroundStyle(theme.danger)
                            .accessibilityIdentifier("hotspot-save-error")
                    }
                }
            }
            .navigationTitle("핫스팟 값 맞추기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        guard let carrierUsageBytes else { return }
                        if appModel.saveHotspotCalibration(
                            bytes: carrierUsageBytes,
                            expectedPeriodStart: inputPeriodStart
                        ) {
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
