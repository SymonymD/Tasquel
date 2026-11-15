import Foundation
enum Season: String, CaseIterable {
    case spring, summer, fall, winter

    /// The season `date` falls in, by the usual start dates: spring from March 20, summer
    /// June 21, fall September 22, winter December 21. South of the equator (by the phone's
    /// region) they're the other way round: December is summer there.
    static func of(_ date: Date, timeZone: TimeZone = .current, region: Locale.Region? = Locale.current.region) -> Season {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        let parts = gregorian.dateComponents([.month, .day], from: date)
        let monthDay = (parts.month ?? 1) * 100 + (parts.day ?? 1)
        let north: Season = switch monthDay {
        case 320..<621: .spring
        case 621..<922: .summer
        case 922..<1221: .fall
        default: .winter
        }
        guard let code = region?.identifier, southernRegions.contains(code) else { return north }
        return switch north {
        case .spring: .fall
        case .summer: .winter
        case .fall: .spring
        case .winter: .summer
        }
    }

    /// Countries wholly or mostly south of the equator.
    private static let southernRegions: Set<String> = [
        "AU", "NZ", "ZA", "AR", "CL", "UY", "PY", "BR", "BO", "PE", "LS", "SZ", "NA", "BW", "ZW", "ZM", "MZ", "MG", "MW",
        "AO", "FJ", "PG", "NC", "SB", "VU", "WS", "TO", "MU", "RE",
    ]

    /// Today's season. Debug builds take `-demoSeason <spring|summer|fall|winter>`, for
    /// screenshots.
    static var current: Season {
        #if DEBUG
        if let forced { return forced }
        #endif
        return of(Date())
    }

    #if DEBUG
    private static let forced: Season? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-demoSeason"), arguments.indices.contains(index + 1) else { return nil }
        return Season(rawValue: arguments[index + 1])
    }()
    #endif

    /// "Fall"
    var label: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .spring: "camera.macro"
        case .summer: "sun.max"
        case .fall: "leaf"
        case .winter: "snowflake"
        }
    }

}

// MARK: - Palette

enum WhatsNew {
    static let version = "1.1"
    static let buttonOpens = 2
    static func isVersion(_ a: String, olderThan b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l < r }
        }
        return false
    }
}
enum AppInfo { static func version() -> String { "1.1" } }
