import ISBN
import Testing

@Test("Ensure validation works for a valid ISBN", arguments: ["978-1-4088-5589-8", "1-4088-5589-5"])
func validate(isbnString: String) {
    #expect(ISBN.isValid(isbnString))
}

@Test("Ensure validation works with an invalid ISBN", arguments: ["978-1-4088-5589-0", "1-4088-5589-0"])
func validateWithInvalidChecksum(isbnString: String) {
    #expect(!ISBN.isValid(isbnString))
}
