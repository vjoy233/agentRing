//
//  GlmColumnView.swift
//  Agent Ring
//

import SwiftUI

struct GlmColumnView: View {
    let glmUsageData: GlmUsageData
    let showRemainingMode: Bool
    let refreshState: RefreshState
    @Binding var animationType: UsageDetailView.LoadingAnimationType
    @Binding var rotationAngle: Double
    let remainingModeAnimationTrigger: Int
    var onRefresh: (() -> Void)?
    var onAnimationHint: ((String) -> Void)?

    private var activeTypes: [LimitType] {
        UserSettings.shared.getActiveGlmDisplayTypes(glmUsageData: glmUsageData)
    }

    private var isRefreshing: Bool {
        refreshState.isRefreshingProvider(.glm)
    }

    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                if let primary = glmUsageData.primary {
                    ActivityRingView(
                        outerPercentage: primary.percentage,
                        innerPercentage: activeTypes.contains(.glmSecondary)
                            ? glmUsageData.secondary?.percentage
                            : nil,
                        outerColor: UsageColorScheme.glmPrimaryColorSwiftUI(primary.percentage),
                        innerColor: UsageColorScheme.glmPairedInnerColorSwiftUI(
                            glmUsageData.secondary?.percentage ?? 0
                        ),
                        isRefreshing: isRefreshing,
                        rotationAngle: rotationAngle,
                        showRemainingMode: showRemainingMode,
                        remainingModeAnimationTrigger: remainingModeAnimationTrigger,
                        animationType: animationType
                    )
                }
            }
            .frame(height: 114)
            .contentShape(Circle())
            .onTapGesture {
                if refreshState.canRefresh && !refreshState.isRefreshing {
                    onRefresh?()
                }
            }
            .onLongPressGesture(minimumDuration: 3.0) {
                let allTypes = UsageDetailView.LoadingAnimationType.allCases
                let currentIndex = allTypes.firstIndex(of: animationType) ?? 0
                animationType = allTypes[(currentIndex + 1) % allTypes.count]
                onAnimationHint?(animationType.name)
            }

            limitRows(for: activeTypes) { type in
                UnifiedLimitRow(
                    type: type,
                    glmData: glmUsageData,
                    showRemainingMode: showRemainingMode
                )
            }
            .padding(.horizontal, 10)
        }
    }
}
