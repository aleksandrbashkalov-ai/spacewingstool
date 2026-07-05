import SwiftUI

extension L10n {
    @MainActor
    var localized: String {
        LocalizationManager.shared.translate(self)
    }

    @MainActor
    func localized(_ args: CVarArg...) -> String {
        LocalizationManager.shared.translate(self, args: args)
    }
}

struct LocalizedText: View {
    let key: L10n
    let args: [CVarArg]

    init(_ key: L10n, args: CVarArg...) {
        self.key = key
        self.args = args
    }

    var body: some View {
        if args.isEmpty {
            Text(verbatim: key.localized)
        } else {
            Text(verbatim: key.localized(args))
        }
    }
}

extension View {
    func localeAware(_ lang: AppLanguage) -> some View {
        self
            .environment(\.locale, lang.locale)
            .environment(\.layoutDirection, lang.isRTL ? .rightToLeft : .leftToRight)
    }
}
