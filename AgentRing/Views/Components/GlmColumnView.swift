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

    /// 与 CodexColumnView 相同：优先用户勾选的 5h 环，被关掉时 7d 提升为主环
    private var primaryRingType: LimitType? {
        if activeTypes.contains(.glmPrimary) {
            return .glmPrimary
        }
        if activeTypes.contains(.glmSecondary) {
            return .glmSecondary
        }
        return nil
    }

    private var primaryRingData: GlmUsageData.LimitData? {
        let placeholder = GlmUsageData.LimitData(percentage: 0, resetsAt: nil)
        let showPlaceholder = UserSettings.shared.shouldShowCustomPlaceholderInPopover

        switch primaryRingType {
        case .glmPrimary:
            return glmUsageData.primary ?? (showPlaceholder ? placeholder : nil)
        case .glmSecondary:
            return glmUsageData.secondary ?? (showPlaceholder ? placeholder : nil)
        default:
            return nil
        }
    }

    private var secondaryData: GlmUsageData.LimitData? { glmUsageData.secondary }

    private var showSecondaryRing: Bool {
        primaryRingType == .glmPrimary && activeTypes.contains(.glmSecondary) && secondaryData != nil
    }

    private var isRefreshing: Bool {
        refreshState.isRefreshingProvider(.glm)
    }

    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                if let ringData = primaryRingData {
                    ActivityRingView(
                        outerPercentage: ringData.percentage,
                        innerPercentage: showSecondaryRing ? secondaryData?.percentage : nil,
                        outerColor: UsageColorScheme.glmPrimaryColorSwiftUI(ringData.percentage),
                        innerColor: UsageColorScheme.glmPairedInnerColorSwiftUI(
                            secondaryData?.percentage ?? 0
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
