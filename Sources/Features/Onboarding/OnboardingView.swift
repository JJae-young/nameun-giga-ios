import SwiftUI

struct OnboardingView: View {
    struct Page: Identifiable {
        let id: Int
        let title: String
        let message: String
        let icon: String
    }

    private let pages = [
        Page(id: 0, title: "데이터 사용량을\n한눈에", message: "이번 달 사용량과 남은 데이터를\n가장 먼저 확인하세요.", icon: "gauge.with.dots.needle.50percent"),
        Page(id: 1, title: "홈 화면에서\n바로", message: "앱을 열지 않아도 위젯으로\n필요한 숫자를 빠르게 볼 수 있어요.", icon: "widget.small"),
        Page(id: 2, title: "내 데이터는\n내 기기 안에", message: "계정도 서버 전송도 없이\n사용량을 기기에만 저장해요.", icon: "lock.shield.fill")
    ]

    @State private var selection = 0
    @Environment(\.dvTheme) private var theme
    let onFinished: () -> Void

    var body: some View {
        ZStack {
            DataViewThemeBackground()
            VStack(spacing: 0) {
                HStack {
                    LogoMark(height: 22)
                    Text("DataView")
                        .font(.headline)
                    Spacer()
                    Button("건너뛰기", action: onFinished)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.accentMintStrong)
                }
                .padding(.horizontal, DVSpacing.xl)
                .padding(.top, DVSpacing.s)

                TabView(selection: $selection) {
                    ForEach(pages) { page in
                        OnboardingPage(page: page)
                            .frame(maxWidth: 720)
                            .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button(selection == pages.count - 1 ? "요금제 설정하기" : "계속") {
                    if selection == pages.count - 1 {
                        onFinished()
                    } else {
                        withAnimation(.easeInOut(duration: 0.25)) { selection += 1 }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, DVSpacing.xl)
                .padding(.bottom, DVSpacing.xl)
                .frame(maxWidth: 640)
            }
        }
    }
}

private struct OnboardingPage: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dvTheme) private var theme

    let page: OnboardingView.Page

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView { pageContent.padding(.vertical, DVSpacing.l) }
            } else {
                pageContent
            }
        }
    }

    private var pageContent: some View {
        VStack(spacing: DVSpacing.xxl) {
            Spacer(minLength: DVSpacing.xl)
            VStack(spacing: DVSpacing.m) {
                Text(page.title)
                    .font(.largeTitle.bold())
                    .fontDesign(.rounded)
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(page.message)
                    .font(.body)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            OnboardingIllustration(index: page.id, icon: page.icon)
            Spacer(minLength: DVSpacing.xxxl)
        }
        .padding(.horizontal, DVSpacing.xl)
    }
}

private struct OnboardingIllustration: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dvTheme) private var theme

    let index: Int
    let icon: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32)
                .fill(
                    LinearGradient(
                        colors: [theme.accentMint.opacity(0.22), theme.accentLavender.opacity(0.14)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 300)

            if index == 0 {
                VStack(spacing: DVSpacing.m) {
                    UsageRing(progress: 0.45, primary: "87.60 GB", secondary: "남음", caption: "45% 사용", size: 188)
                    Text("사용량은 앱 측정 기준")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
            } else if index == 1 {
                ViewThatFits(in: .horizontal) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        HStack(spacing: DVSpacing.m) {
                            remainingWidget
                            todayWidget
                        }
                    }
                    VStack(spacing: DVSpacing.m) {
                        remainingWidget
                        todayWidget
                    }
                }
                .padding(DVSpacing.xl)
            } else {
                VStack(spacing: DVSpacing.xl) {
                    Image(systemName: icon)
                        .font(.system(size: 72, weight: .medium))
                        .foregroundStyle(theme.accentMintStrong)
                    Label("로컬 저장", systemImage: "iphone")
                        .font(.headline)
                    Text("계정 필요 없음")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var remainingWidget: some View {
        MiniWidget(
            title: "남은 데이터",
            value: "87.60 GB",
            icon: "chart.donut",
            tint: theme.accentSkyForeground
        )
    }

    private var todayWidget: some View {
        MiniWidget(
            title: "오늘 사용",
            value: "1.2 GB",
            icon: "chart.bar.fill",
            tint: theme.accentPinkForeground
        )
    }
}

private struct MiniWidget: View {
    @Environment(\.dvTheme) private var theme

    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DVSpacing.l) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Spacer()
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(theme.textPrimary)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(DVSpacing.l)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .background(theme.elevated, in: RoundedRectangle(cornerRadius: DVRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: DVRadius.large)
                .stroke(theme.borderSoft, lineWidth: 1)
        }
        .shadow(color: theme.cardShadow, radius: 16, y: 4)
    }
}
