import SwiftUI
import UIKit

struct MeasurementStatusView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dvTheme) private var theme

    var body: some View {
        List {
            Section("최근 측정 상태") {
                HStack {
                    Label("셀룰러", systemImage: "antenna.radiowaves.left.and.right")
                    Spacer()
                    MeasurementStatusBadge(quality: appModel.lastQuality)
                }
                HStack {
                    Label("핫스팟", systemImage: "personalhotspot")
                    Spacer()
                    Text(appModel.summary.hotspotSupportState == .unsupported ? "감지 전" : "감지됨 · 베타")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .listRowBackground(theme.elevated)

            Section("측정 정보") {
                LabeledContent("이번 주기", value: DataAmountFormatter.string(from: appModel.summary.usedBytes))
                LabeledContent("오늘", value: DataAmountFormatter.string(from: appModel.summary.todayBytes))
                if let hotspotBytes = appModel.summary.hotspotBytes {
                    LabeledContent("이번 주기 핫스팟", value: DataAmountFormatter.string(from: hotspotBytes))
                }
                LabeledContent("최근 갱신", value: appModel.summary.generatedAt.formatted(date: .abbreviated, time: .shortened))
            }
            .listRowBackground(theme.elevated)

            Section {
                Text("최근 측정 완료는 마지막 측정이 성공했다는 뜻이며, 이번 주기 전체의 정확도를 보장하지 않습니다. 재부팅이나 연결 변경 사이의 사용량은 일부 누락될 수 있고, 통신사 반영 시각과 과금 기준도 다릅니다. 차이가 있으면 통신사 값 맞추기에서 기준을 갱신해 주세요.")
                    .font(.footnote)
                    .foregroundStyle(theme.textSecondary)
            }
            .listRowBackground(theme.elevated)
        }
        .scrollContentBackground(.hidden)
        .background { DataViewThemeBackground() }
        .tint(theme.accentMintStrong)
        .navigationTitle("측정 상태")
    }
}

struct InterfaceDiagnosticsView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dvTheme) private var theme
    @State private var counters: [NetworkInterfaceCounter] = []
    @State private var copied = false
    /// Counters captured with "기준 저장". Comparing against them shows which
    /// interface grew during a test (for example a hotspot download).
    @State private var baseline: [String: NetworkInterfaceCounter] = [:]
    @State private var baselineDate: Date?

    var body: some View {
        List {
            if counters.isEmpty {
                ContentUnavailableView(
                    "인터페이스 정보 없음",
                    systemImage: "network.slash",
                    description: Text("실기기에서 다시 확인해 주세요.")
                )
            } else {
                ForEach(counters) { counter in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(counter.name)
                                .font(.headline.monospaced())
                            Spacer()
                            Text(classificationLabel(counter.classification))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.textSecondary)
                        }
                        Text("RX \(DataAmountFormatter.string(from: CounterDeltaCalculator.clampedInt64(counter.receivedBytes))) · TX \(DataAmountFormatter.string(from: CounterDeltaCalculator.clampedInt64(counter.sentBytes)))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(theme.textSecondary)
                        if let change = changeSinceBaseline(counter) {
                            Text(change)
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(theme.accentMintStrong)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(theme.elevated)
                }
            }

            Section {
                Button {
                    counters = appModel.diagnosticCounters()
                    baseline = Dictionary(counters.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
                    baselineDate = .now
                    copied = false
                } label: {
                    Label("현재 값을 기준으로 저장", systemImage: "flag")
                        .frame(maxWidth: .infinity)
                }
                if let baselineDate {
                    Text("기준 \(baselineDate.formatted(date: .omitted, time: .standard)) · 아래로 당겨 새로 읽으면 기준 이후 변화량이 표시됩니다.")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                Button {
                    UIPasteboard.general.string = diagnosticText
                    copied = true
                } label: {
                    Label(copied ? "복사됨" : "진단 정보 복사", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
            }
            .listRowBackground(theme.elevated)
        }
        .scrollContentBackground(.hidden)
        .background { DataViewThemeBackground() }
        .tint(theme.accentMintStrong)
        .navigationTitle("인터페이스 진단")
        .onAppear { counters = appModel.diagnosticCounters() }
        .refreshable { counters = appModel.diagnosticCounters() }
    }

    private var diagnosticText: String {
        counters.map { counter -> String in
            var line = "\(counter.name)\t\(counter.receivedBytes)\t\(counter.sentBytes)\t\(diagnosticClassification(counter.classification))"
            if let previous = baseline[counter.name] {
                line += "\tdeltaRX=\(Int64(clamping: counter.receivedBytes) - Int64(clamping: previous.receivedBytes))"
                line += "\tdeltaTX=\(Int64(clamping: counter.sentBytes) - Int64(clamping: previous.sentBytes))"
            }
            return line
        }
        .joined(separator: "\n")
    }

    private func changeSinceBaseline(_ counter: NetworkInterfaceCounter) -> String? {
        guard baselineDate != nil else { return nil }
        guard let previous = baseline[counter.name] else { return "기준 이후 새로 생김" }
        guard counter.receivedBytes >= previous.receivedBytes,
              counter.sentBytes >= previous.sentBytes else { return "기준 이후 초기화됨" }
        let (sum, overflow) = (counter.receivedBytes - previous.receivedBytes)
            .addingReportingOverflow(counter.sentBytes - previous.sentBytes)
        let delta = CounterDeltaCalculator.clampedInt64(overflow ? UInt64.max : sum)
        return "기준 이후 +\(DataAmountFormatter.string(from: delta))"
    }

    private func classificationLabel(_ value: InterfaceClassification) -> String {
        switch value {
        case .cellular: "셀룰러 후보"
        case .wifi: "Wi-Fi"
        case .hotspotCandidate: "핫스팟 후보"
        case .vpn: "VPN/터널"
        case .loopback: "루프백"
        case .unknown: "알 수 없음"
        }
    }

    private func diagnosticClassification(_ value: InterfaceClassification) -> String {
        switch value {
        case .cellular: "cellular"
        case .wifi: "wifi"
        case .hotspotCandidate: "hotspot-candidate"
        case .vpn: "vpn"
        case .loopback: "loopback"
        case .unknown: "unknown"
        }
    }
}
