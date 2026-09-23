//
//  KimiColumnView.swift
//  Agent Ring
//

import SwiftUI

struct KimiColumnView: View {
    let kimiUsageData: KimiUsageData
    let showRemainingMode: Bool
    let refreshState: RefreshState
    @Binding var animationType: UsageDetailView.LoadingAnimationType
    @Binding var rotationAngle: Double
    let remainingModeAnimationTrigger: Int
    var onRefresh: (() -> Void)?
    var onAnimationHint: ((String) -> Void)?

    private var activeTypes: [LimitType] {
        UserSettings.shared.getActiveKimiDisplayTypes(kimiUsageData: kimiUsageData)
    }

    private var isRefreshing: Bool {
        refreshState.isRefreshingProvider(.kimi)
    }

    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                if let primary = kimiUsageData.primary {
                    ActivityRingView(
                        outerPercentage: primary.percentage,
                        innerPercentage: activeTypes.contains(.kimiSecondary)
                            ? kimiUsageData.secondary?.percentage
                            : nil,
                        outerColor: UsageColorScheme.kimiPrimaryColorSwiftUI(primary.percentage),
                        innerColor: UsageColorScheme.kimiPairedInnerColorSwiftUI(
                            kimiUsageData.secondary?.percentage ?? 0
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
                    kimiData: kimiUsageData,
                    showRemainingMode: showRemainingMode
                )
            }
            .padding(.horizontal, 10)
        }
    }
}
