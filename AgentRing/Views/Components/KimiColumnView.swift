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

    /// 与 CodexColumnView 相同：优先用户勾选的 5h 环，被关掉时 7d 提升为主环
    private var primaryRingType: LimitType? {
        if activeTypes.contains(.kimiPrimary) {
            return .kimiPrimary
        }
        if activeTypes.contains(.kimiSecondary) {
            return .kimiSecondary
        }
        return nil
    }

    private var primaryRingData: KimiUsageData.LimitData? {
        let placeholder = KimiUsageData.LimitData(percentage: 0, resetsAt: nil)
        let showPlaceholder = UserSettings.shared.shouldShowCustomPlaceholderInPopover

        switch primaryRingType {
        case .kimiPrimary:
            return kimiUsageData.primary ?? (showPlaceholder ? placeholder : nil)
        case .kimiSecondary:
            return kimiUsageData.secondary ?? (showPlaceholder ? placeholder : nil)
        default:
            return nil
        }
    }

    private var secondaryData: KimiUsageData.LimitData? { kimiUsageData.secondary }

    private var showSecondaryRing: Bool {
        primaryRingType == .kimiPrimary && activeTypes.contains(.kimiSecondary) && secondaryData != nil
    }

    private var isRefreshing: Bool {
        refreshState.isRefreshingProvider(.kimi)
    }

    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                if let ringData = primaryRingData {
                    ActivityRingView(
                        outerPercentage: ringData.percentage,
                        innerPercentage: showSecondaryRing ? secondaryData?.percentage : nil,
                        outerColor: UsageColorScheme.kimiPrimaryColorSwiftUI(ringData.percentage),
                        innerColor: UsageColorScheme.kimiPairedInnerColorSwiftUI(
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
                    kimiData: kimiUsageData,
                    showRemainingMode: showRemainingMode
                )
            }
            .padding(.horizontal, 10)
        }
    }
}
