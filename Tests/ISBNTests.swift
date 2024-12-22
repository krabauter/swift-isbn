import ISBN
import Testing

@Test("Ensure validation works for a valid ISBN", arguments: ["978-1-4088-5589-8", "1-4088-5589-5"])
func validate(isbnString: String) {
    #expect(ISBN.isValid(isbnString))
}

@Test("Ensure validation works with an invalid ISBN", arguments: ["978-1-4088-5589-0", "1-4088-5589-0"])
func validateWithInvalidCheckDigit(isbnString: String) {
    #expect(!ISBN.isValid(isbnString))
}

@Test("Hyphenation")
func hyphenation() throws {
    #expect(ISBN.hyphenated(9781781100769) == "978-1-78110-076-9")
}

@Test("Ensure each element of the ISBN is correct")
func elements() throws {
    let isbn = try #require(ISBN("978-1-4088-5589-8"))
    #expect(isbn.elements.prefix == 978)
    #expect(isbn.elements.group == 1)
    #expect(isbn.elements.registrant == "4088")
    #expect(isbn.elements.publication == "5589")
    #expect(isbn.elements.checkDigit == 8)
}

@Test("Group name")
func groupName() async throws {
    let isbn = try #require(ISBN("978-1-4088-5589-8"))
    #expect(isbn.groupName == "English language")
}
