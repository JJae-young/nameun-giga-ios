import Foundation

enum DataAmountFormatter {
    static func string(from bytes: Int64, compact: Bool = false) -> String {
        formattedString(from: bytes, compact: compact, fixedFractionDigits: nil, locale: .current)
    }

    /// Remaining allowances use the same precision in the app, widgets and
    /// accessibility labels. This only rounds the display, never stored bytes.
    static func remainingString(from bytes: Int64, locale: Locale = .current) -> String {
        formattedString(from: bytes, compact: false, fixedFractionDigits: 2, locale: locale)
    }

    private static func formattedString(
        from bytes: Int64,
        compact: Bool,
        fixedFractionDigits: Int?,
        locale: Locale
    ) -> String {
        let safeBytes = max(0, bytes)
        let divisor: Int64
        let unit: String

        if safeBytes >= DataBytes.terabyte {
            divisor = DataBytes.terabyte
            unit = "TB"
        } else if safeBytes >= DataBytes.gigabyte {
            divisor = DataBytes.gigabyte
            unit = "GB"
        } else {
            divisor = DataBytes.megabyte
            unit = "MB"
        }

        let value = Decimal(safeBytes) / Decimal(divisor)
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fixedFractionDigits ?? 0
        formatter.maximumFractionDigits = fixedFractionDigits ?? (value >= 100 || compact ? 0 : 1)
        if fixedFractionDigits != nil { formatter.roundingMode = .halfUp }
        let number = formatter.string(from: NSDecimalNumber(decimal: value)) ?? "0"
        return "\(number) \(unit)"
    }

    static func gigabytes(
        from text: String,
        allowingZero: Bool = false,
        locale: Locale = .current
    ) -> Int64? {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        let decimalSeparator = formatter.decimalSeparator ?? "."
        let groupingSeparator = formatter.groupingSeparator ?? ","
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.components(separatedBy: decimalSeparator)
        guard parts.count <= 2, !trimmed.isEmpty else { return nil }

        func isDigits(_ value: String) -> Bool {
            !value.isEmpty && value.unicodeScalars.allSatisfy { (48...57).contains($0.value) }
        }

        let integer = parts[0]
        let groups = integer.components(separatedBy: groupingSeparator)
        if groups.count > 1 {
            let primarySize = max(1, formatter.groupingSize)
            let secondarySize = formatter.secondaryGroupingSize > 0
                ? formatter.secondaryGroupingSize : primarySize
            guard groups.allSatisfy(isDigits),
                  groups.last?.count == primarySize,
                  (1...secondarySize).contains(groups[0].count),
                  groups.dropFirst().dropLast().allSatisfy({ $0.count == secondarySize }) else { return nil }
        } else if !integer.isEmpty, !isDigits(integer) {
            return nil
        }
        if parts.count == 2 {
            guard isDigits(parts[1]), parts[1].count <= 9 else { return nil }
        } else if integer.isEmpty {
            return nil
        }

        let whole = groups.joined()
        let canonical = (whole.isEmpty ? "0" : whole) + (parts.count == 2 ? "." + parts[1] : "")
        guard let amount = Decimal(string: canonical, locale: Locale(identifier: "en_US_POSIX")),
              amount >= 0, amount <= 10_000,
              allowingZero || amount > 0 else { return nil }
        return NSDecimalNumber(decimal: amount * Decimal(DataBytes.gigabyte)).int64Value
    }

    /// Editable numbers must never lose precision or introduce a grouping
    /// separator that could be mistaken for a decimal separator.
    static func gigabyteInput(from bytes: Int64, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 9
        let amount = Decimal(max(0, bytes)) / Decimal(DataBytes.gigabyte)
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "0"
    }
}
