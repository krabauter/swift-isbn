/// The registration ranges of ISBNs, generated from the range message of the International ISBN Agency
enum RangeTable {
    /// A range of ISBNs whose registrant elements have the same length
    ///
    /// - `lowerBound`: The first 12 digits of the lowest ISBN in the range
    /// - `upperBound`: The first 12 digits of the highest ISBN in the range
    /// - `groupLength`: The length of the registration group element
    /// - `registrantLength`: The length of the registrant element
    /// - `agency`: The index of the registration group name in `agencies`
    ///
    /// Entries are tuples because the compiler type-checks the generated array literal
    /// considerably faster than an array of initializer calls.
    typealias Entry = (lowerBound: UInt64, upperBound: UInt64, groupLength: UInt8, registrantLength: UInt8, agency: UInt16)

    /// Returns the entry whose range contains the ISBN with the given first 12 digits.
    static func entry(containing firstTwelveDigits: UInt64) -> Entry? {
        let entries = self.entries
        // The entries are sorted and don't overlap, so the last entry starting at or before the
        // digits is the only one that may contain them.
        var low = 0
        var high = entries.count
        while low < high {
            let middle = low + (high - low) / 2
            if entries[middle].lowerBound <= firstTwelveDigits {
                low = middle + 1
            } else {
                high = middle
            }
        }
        guard low > 0, firstTwelveDigits <= entries[low - 1].upperBound else {
            return nil
        }
        return entries[low - 1]
    }
}
