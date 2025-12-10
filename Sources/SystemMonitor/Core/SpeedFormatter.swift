import Foundation

struct SpeedFormatter {
    static func format(_ bytes: Int64) -> String {
        let textFormat = UserDefaults.standard.string(forKey: "textFormat") ?? "4 Digits"
        let unitStyle = UserDefaults.standard.string(forKey: "unitStyle") ?? "standard"
        
        let value: Double
        var unit: String
        
        // Determine unit string base
        let isLowercase = unitStyle.contains("lowercase")
        let hasSuffix = unitStyle.contains("suffix") || unitStyle == "suffix"
        
        // User requesting ONLY KB and MB
        if bytes < 1024 * 1024 {
            // < 1 MB -> Display as KB
            value = Double(bytes) / 1024.0
            unit = isLowercase ? "kb" : "KB"
            if hasSuffix { unit += "/s" }
        } else {
            // >= 1 MB -> Display as MB
            value = Double(bytes) / 1024.0 / 1024.0
            unit = isLowercase ? "mb" : "MB"
            if hasSuffix { unit += "/s" }
        }
        
        // Format logic based on user preference
        let formatStr: String
        switch textFormat {
        case "3 Digits":
            // %3.0f e.g. " 10" KB
            formatStr = "%3.0f%@"
        case "2 Digits + Decimal":
            // %4.1f e.g. " 1.2" KB
            formatStr = "%4.1f%@"
        case "4 Digits":
            fallthrough
        default:
             // %4.0f e.g. "  10" KB
             formatStr = "%4.0f%@"
        }
        
        return String(format: formatStr, value, unit)
    }
}
