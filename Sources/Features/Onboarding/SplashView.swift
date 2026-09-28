import SwiftUI

struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dvTheme) private var theme
    @State private var appeared = false

    var body: some View {
        ZStack {
            DataViewThemeBackground()

            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: DVSpacing.l) {
                    LogoMark(height: 46)
                    Text("남은기가")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                    Text("내 데이터를, 더 스마트하게")
                        .font(.headline)
                        .foregroundStyle(theme.textSecondary)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared || reduceMotion ? 0 : 10)
                Spacer()
                Text("데이터 사용은 배경에서도 함께 관리해요")
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)
                    .padding(.bottom, DVSpacing.xxxl)
            }
            .padding(.horizontal, DVSpacing.xxl)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.45)) {
                appeared = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("남은기가. 내 데이터를 더 스마트하게")
    }
}
