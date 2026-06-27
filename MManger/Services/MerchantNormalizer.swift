import Foundation

enum MerchantNormalizer {
    private static let locationSuffixes = [
        "DUBAI ARE", "DUBAI AE", "DUBAI",
        "ABU DHABI ARE", "ABU DHABI AE", "ABU DHABI",
        "RAS AL KHAIMA", "RAS AL-KHAIMA",
        "AJMAN", "SHARJAH", "UAE", "AE"
    ]

    static func normalize(_ value: String) -> String {
        var text = value.uppercased()
        text = text.replacingOccurrences(of: #"CR\.?CARD\s*XXX\d+\s*USED\s*FOR\s*[A-Z]{3}[\d,.]+\s*AT\s*"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"CARD\s*XXX\d+\s*USED\s*FOR\s*[A-Z]{3}[\d,.]+\s*AT\s*"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"CR\.?CARDXXX\d+USED"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"CARDXXX\d+USED"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\(\+\d+(?:\.\d+)?%[^)]*\)"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"AVL\.?\s*CR\.?\s*LIMIT(?:\s*IS)?\s*[A-Z]{3}[\d,.]+"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"AVLCRLIMIT(?:IS)?[A-Z]{3}[\d,.]+"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"[^A-Z0-9&%+./ -]"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: " -,."))

        var changed = true
        while changed {
            changed = false
            for suffix in locationSuffixes where text.hasSuffix(" \(suffix)") {
                text = String(text.dropLast(suffix.count)).trimmingCharacters(in: CharacterSet(charactersIn: " -,."))
                changed = true
            }
            for suffix in locationSuffixes where text.hasSuffix("-\(suffix)") {
                text = String(text.dropLast(suffix.count)).trimmingCharacters(in: CharacterSet(charactersIn: " -,."))
                changed = true
            }
        }
        return text
    }
}

struct CategorySuggestion: Equatable {
    var category: String
    var subcategory: String?
    var kind: TransactionKind
    var confidence: Double
}

enum CategoryMatcher {
    static func match(merchant: String, rules: [MerchantRule], fallbackKind: TransactionKind) -> CategorySuggestion? {
        match(merchant: merchant, ruleSnapshots: rules.map(MerchantRuleSnapshot.init), fallbackKind: fallbackKind)
    }

    /// Snapshot-based matcher safe to call off the main actor.
    static func match(merchant: String, ruleSnapshots: [MerchantRuleSnapshot], fallbackKind: TransactionKind) -> CategorySuggestion? {
        let normalized = MerchantNormalizer.normalize(merchant)
        let sortedRules = ruleSnapshots.filter(\.isEnabled).sorted {
            if $0.sampleCount == $1.sampleCount {
                return $0.pattern.count > $1.pattern.count
            }
            return $0.sampleCount > $1.sampleCount
        }

        for rule in sortedRules {
            let pattern = MerchantNormalizer.normalize(rule.pattern)
            guard !pattern.isEmpty else { continue }
            let isMatch: Bool
            switch rule.matchType {
            case .exact:
                isMatch = normalized == pattern
            case .contains:
                isMatch = normalized.contains(pattern) || pattern.contains(normalized)
            }
            if isMatch {
                return CategorySuggestion(
                    category: rule.categoryName,
                    subcategory: rule.subcategoryName,
                    kind: rule.kind,
                    confidence: rule.confidence
                )
            }
        }

        return hardCodedFallback(for: normalized, fallbackKind: fallbackKind)
    }

    private static func hardCodedFallback(for merchant: String, fallbackKind: TransactionKind) -> CategorySuggestion? {
        let mappings: [(String, String, String?)] = [
            ("CAREEM HALA", "Transportation", "Taxi"),
            ("CAREEM RIDE", "Transportation", "Taxi"),
            ("CAREEM DELIVERIES", "Food", "Delivery"),
            ("CAREEM FOOD", "Food", "Delivery"),
            ("CAREEM QUIK", "Food", nil),
            ("CAREEM PLUS", "Transportation", nil),
            ("NATIONAL TAXI", "Transportation", "Taxi"),
            ("DUBAI TAXI", "Transportation", "Taxi"),
            ("DUBAI BOLT", "Transportation", "Taxi"),
            ("RTA-DUBAI METRO", "Transportation", "Metro"),
            ("DOTT SCOOTER", "Transportation", nil),
            ("DOTT PASS", "Transportation", nil),
            ("AMAZON GROCERY", "Food", "Groceries"),
            ("AMAZON NOW", "Food", "Groceries"),
            ("ALL DAY MARKET", "Food", "Groceries"),
            ("WEST ZONE", "Food", "Groceries"),
            ("VIVA", "Food", "Groceries"),
            ("UNION COOP", "Food", "Groceries"),
            ("AL MAYA", "Food", "Groceries"),
            ("CARREFOUR", "Food", "Groceries"),
            ("CHOITHRAM", "Food", "Groceries"),
            ("SPINNEYS", "Food", "Groceries"),
            ("HALAL MINI MART", "Food", "Groceries"),
            ("AL BONDOQ", "Food", "Groceries"),
            ("NOON FOOD", "Food", "Delivery"),
            ("AFRINA SWEETS", "Food", "Restaurants"),
            ("TIM HORTONS", "Food", "Coffee"),
            ("COTTI COFFEE", "Food", "Coffee"),
            ("HUNGRY JACKS", "Food", "Restaurants"),
            ("THE VILLA RESTAURANT", "Food", "Restaurants"),
            ("LAUNDRY", "Shopping", "Laundry"),
            ("AGODA", "Travel", nil),
            ("BOOKING", "Travel", nil),
            ("ROVE", "Travel", nil),
            ("ADNOC", "Transportation", "Fuel"),
            ("EMARAT", "Transportation", "Fuel"),
            ("SALIK", "Transportation", "Parking"),
            ("SMART DUBAI GOVERNMENT", "Transportation", "Parking"),
            ("IKEA", "Shopping", "Household"),
            ("JUSTLIFE", "Shopping", "Household"),
            ("DAY TO DAY", "Shopping", "Household"),
            ("AVENUE BY DAY TO DAY", "Shopping", "Household"),
            ("NOON.COM", "Shopping", "Household"),
            ("AMAZON.AE", "Shopping", "Household"),
            ("TEMU", "Shopping", "Household"),
            ("GIFTS VILLAGE", "Family", "Gifts"),
            ("GROUPON", "Entertainment", nil),
            ("VOX CINEMAS", "Entertainment", "Movies"),
            ("MATOVI DIGITAL", "Entertainment", "Subscriptions"),
            ("AMAZON PRIME", "Entertainment", "Subscription"),
            ("TABBY", "to return shopping", nil),
            ("THE BALLET CENTRE", "Academy", "Classes"),
            ("YO FIT", "Academy", "Yoga")
        ]

        guard let mapping = mappings.first(where: { merchant.contains($0.0) }) else {
            return nil
        }
        return CategorySuggestion(category: mapping.1, subcategory: mapping.2, kind: fallbackKind, confidence: 0.75)
    }
}
