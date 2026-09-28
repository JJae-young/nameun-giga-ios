import SwiftUI

struct HotspotDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dvTheme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DVSpacing.l) {
                    VStack(spacing: DVSpacing.xl) {
                        ZStack {
                            Circle()
                                .fill(theme.accentLavender.opacity(0.26))
                                .frame(width: 104, height: 104)
                            Image(systemName: "personalhotspot")
                                .font(.system(size: 42, weight: .medium))
                                .foregroundStyle(theme.textPrimary)
                        }
                        VStack(spacing: DVSpacing.s) {
                            Text("핫스팟 분리 측정 미지원")
                                .font(.title3.bold())
                                .foregroundStyle(theme.textPrimary)
                            Text("이 기기에서는 핫스팟 트래픽을 iPhone 사용량과 안정적으로 분리할 수 없습니다.")
                                .font(.subheadline)
                                .foregroundStyle(theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(DVSpacing.xl)
                    .background(
                        LinearGradient(
                            colors: [theme.elevated, theme.accentLavender.opacity(0.20)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: DVRadius.large)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: DVRadius.large)
                            .stroke(theme.borderSoft, lineWidth: 1)
                    }
                    .shadow(color: theme.cardShadow, radius: 24, y: 8)

                    SectionCard {
                        VStack(alignment: .leading, spacing: DVSpacing.l) {
                            Label("현재 제공되는 정보", systemImage: "checkmark.shield.fill")
                                .font(.headline)
                                .foregroundStyle(theme.accentMintStrong)
                            FeatureRow(text: "셀룰러 전체 사용량", available: true)
                            FeatureRow(text: "핫스팟 전체 사용량 분리", available: false)
                            FeatureRow(text: "연결 기기별 사용량", available: false)
                        }
                    }

                    HStack(alignment: .top, spacing: DVSpacing.m) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(theme.accentMintStrong)
                        Text("검증되지 않은 인터페이스 값을 실제 핫스팟 사용량처럼 표시하지 않습니다. 기기와 iOS 버전별 검증이 끝난 경우에만 제공됩니다.")
                            .font(.footnote)
                            .foregroundStyle(theme.textSecondary)
                    }
                    .padding(DVSpacing.s)
                }
                .padding(DVSpacing.l)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background { DataViewThemeBackground() }
            .navigationTitle("핫스팟")
        }
    }
}

private struct FeatureRow: View {
    @Environment(\.dvTheme) private var theme

    let text: String
    let available: Bool

    var body: some View {
        HStack(spacing: DVSpacing.m) {
            Image(systemName: available ? "checkmark.circle.fill" : "minus.circle.fill")
                .foregroundStyle(available ? theme.success : theme.textTertiary)
            Text(text)
                .font(.subheadline)
            Spacer()
            Text(available ? "지원" : "미지원")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}
