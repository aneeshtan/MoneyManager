import Foundation

enum MerchantNormalizer {
    private static let locationSuffixes = [
        "DUBAI ARE", "DUBAI AE", "DUBAI",
        "ABU DHABI ARE", "ABU DHABI AE", "ABU DHABI",
        "RAS AL KHAIMA", "RAS AL-KHAIMA",
        "AJMAN", "SHARJAH", "UAE", "AE"
    ]

    /// Some exports strip every space out of the bank narration, so the spaced suffixes
    /// above never match. Longest first, so "DUBAIAE" wins over a bare "AE".
    private static let unspacedLocationSuffixes = [
        "ABUDHABIARE", "ABUDHABIAE", "RASALKHAIMA", "DUBAIARE", "SHARJAHAE",
        "DUBAIAE", "AJMANAE", "ABUDHABI", "SHARJAH", "AJMAN", "DUBAI", "UAE", "ARE", "AE"
    ]

    private static let monthAlternation = "JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC"

    // Compiled once: recompiling these on every call dominated import parsing time.
    private static let strippingRegexes: [NSRegularExpression] = {
        let patterns = [
            #"CR\.?CARD\s*XXX\d+\s*USED\s*FOR\s*[A-Z]{3}[\d,.]+\s*AT\s*"#,
            #"CARD\s*XXX\d+\s*USED\s*FOR\s*[A-Z]{3}[\d,.]+\s*AT\s*"#,
            #"CR\.?CARDXXX\d+USED"#,
            #"CARDXXX\d+USED"#,
            #"\(\+\d+(?:\.\d+)?%[^)]*\)"#,
            #"AVL\.?\s*CR\.?\s*LIMIT(?:\s*IS)?\s*[A-Z]{3}[\d,.]+"#,
            #"AVLCRLIMIT(?:IS)?[A-Z]{3}[\d,.]+"#,
            // Running balances and account/reference numbers differ on every line, so
            // without these each transaction normalizes to its own unique merchant.
            #"AVL\.?\s*BAL\.?\s*[A-Z]{3}[\d,.]+"#,
            #"AVAILABLE\s*BALANCE\s*IS\s*[A-Z]{3}[\d,.]+"#,
            #"IS\s*DEBITED\s*WITH\s*[A-Z]{3}[\d,.]+"#,
            #"DEAR\s*CUS(?:TO)?MER"#,
            #"DEBITED\s*A/?C\s*\d+"#,
            #"(?:TRANSACTION\s*)?(?:ACC?|A/C)?\s*NO\.?\s*XXX\d+"#,
            #"XXX\d+"#,
            #"(?:\#(monthAlternation))\d{1,2}20\d\d"#,
            #"\d{1,2}(?:\#(monthAlternation))20\d\d"#
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    private static let disallowedCharacterRegex = try? NSRegularExpression(pattern: #"[^A-Z0-9&%+./ -]"#)
    private static let whitespaceRunRegex = try? NSRegularExpression(pattern: #"\s+"#)
    private static let trailingDigitRunRegex = try? NSRegularExpression(pattern: #"\d{4,}$"#)

    static func normalize(_ value: String) -> String {
        var text = value.uppercased()
        for regex in strippingRegexes {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text), withTemplate: "")
        }
        if let regex = disallowedCharacterRegex {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text), withTemplate: " ")
        }
        if let regex = whitespaceRunRegex {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text), withTemplate: " ")
        }
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: " -,."))

        // Trailing reference digits are stripped inside this loop, not after it: removing
        // them can expose a location suffix ("STOREUAE1234" -> "STOREUAE"), and a pass
        // that left one behind would normalize differently the second time it ran. Import
        // deduplication re-normalizes stored merchants, so convergence here matters.
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
            for suffix in unspacedLocationSuffixes where text.hasSuffix(suffix) && text.count > suffix.count {
                text = String(text.dropLast(suffix.count)).trimmingCharacters(in: CharacterSet(charactersIn: " -,."))
                changed = true
                break
            }
            if let regex = trailingDigitRunRegex {
                let stripped = regex.stringByReplacingMatches(
                    in: text,
                    range: NSRange(text.startIndex..<text.endIndex, in: text),
                    withTemplate: ""
                ).trimmingCharacters(in: CharacterSet(charactersIn: " -,."))
                if stripped != text, !stripped.isEmpty {
                    text = stripped
                    changed = true
                }
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

/// Rule matcher with rules filtered, sorted, and normalized once up front.
/// Build one per import/categorization pass instead of re-preparing rules per row.
struct PreparedCategoryMatcher: Sendable {
    private struct PreparedRule: Sendable {
        var snapshot: MerchantRuleSnapshot
        var normalizedPattern: String
        var normalizedNotePattern: String?
    }

    fileprivate static let minimumContainsLength = 4

    private let rules: [PreparedRule]

    init(ruleSnapshots: [MerchantRuleSnapshot]) {
        rules = ruleSnapshots
            .filter(\.isEnabled)
            .sorted {
                if $0.priority != $1.priority {
                    return $0.priority > $1.priority
                }
                if $0.sampleCount == $1.sampleCount {
                    return $0.pattern.count > $1.pattern.count
                }
                return $0.sampleCount > $1.sampleCount
            }
            .compactMap { snapshot in
                let pattern = MerchantNormalizer.normalize(snapshot.pattern)
                guard !pattern.isEmpty else { return nil }
                let notePattern = snapshot.notePattern.flatMap { note -> String? in
                    let normalized = MerchantNormalizer.normalize(note)
                    return normalized.isEmpty ? nil : normalized
                }
                return PreparedRule(snapshot: snapshot, normalizedPattern: pattern, normalizedNotePattern: notePattern)
            }
    }

    /// `normalizedMerchant` must already be run through `MerchantNormalizer.normalize`.
    func match(
        normalizedMerchant: String,
        accountName: String? = nil,
        note: String? = nil,
        amount: Decimal? = nil,
        fallbackKind: TransactionKind
    ) -> CategorySuggestion? {
        lazy var normalizedNote = note.map(MerchantNormalizer.normalize)

        for rule in rules {
            let pattern = rule.normalizedPattern

            let merchantMatch: Bool
            switch rule.snapshot.matchType {
            case .exact:
                merchantMatch = normalizedMerchant == pattern
            case .contains:
                // Without a floor, a two-letter pattern matches nearly every merchant.
                guard pattern.count >= Self.minimumContainsLength else { continue }
                merchantMatch = normalizedMerchant.contains(pattern)
                    || (normalizedMerchant.count >= Self.minimumContainsLength && pattern.contains(normalizedMerchant))
            }
            guard merchantMatch else { continue }

            if let accountName, let ruleAccount = rule.snapshot.accountName, !ruleAccount.isEmpty,
               accountName != ruleAccount {
                continue
            }

            if let normalizedNote, let normalizedRuleNote = rule.normalizedNotePattern {
                guard normalizedNote.contains(normalizedRuleNote) || normalizedRuleNote.contains(normalizedNote) else {
                    continue
                }
            }

            if let amount {
                if let minAmount = rule.snapshot.minAmount, amount < minAmount { continue }
                if let maxAmount = rule.snapshot.maxAmount, amount > maxAmount { continue }
            }

            return CategorySuggestion(
                category: rule.snapshot.categoryName,
                subcategory: rule.snapshot.subcategoryName,
                kind: rule.snapshot.kind,
                confidence: rule.snapshot.confidence
            )
        }

        return CategoryMatcher.hardCodedFallback(for: normalizedMerchant, fallbackKind: fallbackKind)
    }
}

enum CategoryMatcher {
    static func match(merchant: String, rules: [MerchantRule], fallbackKind: TransactionKind) -> CategorySuggestion? {
        match(merchant: merchant, ruleSnapshots: rules.map(MerchantRuleSnapshot.init), fallbackKind: fallbackKind)
    }

    /// Snapshot-based matcher safe to call off the main actor.
    /// Prefer building a `PreparedCategoryMatcher` when matching many merchants against the same rules.
    static func match(
        merchant: String,
        accountName: String? = nil,
        note: String? = nil,
        amount: Decimal? = nil,
        ruleSnapshots: [MerchantRuleSnapshot],
        fallbackKind: TransactionKind
    ) -> CategorySuggestion? {
        PreparedCategoryMatcher(ruleSnapshots: ruleSnapshots).match(
            normalizedMerchant: MerchantNormalizer.normalize(merchant),
            accountName: accountName,
            note: note,
            amount: amount,
            fallbackKind: fallbackKind
        )
    }

    /// Matched with spaces removed on both sides: some exports strip every space out of
    /// the narration, so "UNIONCOOPDUBAIAE" has to still hit the "UNION COOP" entry.
    fileprivate static func hardCodedFallback(for merchant: String, fallbackKind: TransactionKind) -> CategorySuggestion? {
        let condensed = merchant.replacingOccurrences(of: " ", with: "")
        guard !condensed.isEmpty,
              let mapping = condensedFallbackMappings.first(where: { condensed.contains($0.0) }) else {
            return nil
        }
        return CategorySuggestion(category: mapping.1, subcategory: mapping.2, kind: fallbackKind, confidence: 0.75)
    }

    /// Longest patterns first so "CAREEM DELIVERIES" wins over a bare "CAREEM" entry.
    private static let condensedFallbackMappings: [(String, String, String?)] = fallbackMappings
        .map { ($0.0.replacingOccurrences(of: " ", with: ""), $0.1, $0.2) }
        .sorted { $0.0.count > $1.0.count }

    private static let fallbackMappings: [(String, String, String?)] = [
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
}
