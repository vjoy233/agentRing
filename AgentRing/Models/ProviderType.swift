//
//  ProviderType.swift
//  Agent Ring
//

import Foundation

enum ProviderType: String, Codable, CaseIterable, Hashable {
    case codex
    case cursor
    case glm
    case kimi
    case antigravity
    case antigravityThird = "antigravity_third"

    var displayName: String {
        switch self {
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        case .glm: return "GLM"
        case .kimi: return "Kimi"
        case .antigravity: return "Antigravity"
        case .antigravityThird: return "Antigravity Third"
        }
    }
}

