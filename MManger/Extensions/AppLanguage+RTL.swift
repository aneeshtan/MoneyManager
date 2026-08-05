import Foundation

extension AppLanguage {
    var isRightToLeft: Bool {
        self == .persian || self == .arabic
    }
}