import Testing
@testable import OpenbaseShared

@Test func clientExists() async throws {
    #expect(AllAuthClient.shared != nil)
}
