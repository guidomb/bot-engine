import XCTest

extension DayTimeTests {
    static let __allTests = [
        ("testAtWithInvalidTimeString", testAtWithInvalidTimeString),
        ("testAtWithInvalidTimeZoneIdentifier", testAtWithInvalidTimeZoneIdentifier),
        ("testAtWithValidTimeString", testAtWithValidTimeString),
        ("testAtWithValidTimeZoneIdentifier", testAtWithValidTimeZoneIdentifier),
        ("testInitializerWithInvalidHours", testInitializerWithInvalidHours),
        ("testInitializerWithInvalidMinutes", testInitializerWithInvalidMinutes),
        ("testInitializerWithValidHoursAndMinutes", testInitializerWithValidHoursAndMinutes),
        ("testIntervalSinceWhenDayTimeIsInTheFuture", testIntervalSinceWhenDayTimeIsInTheFuture),
        ("testIntervalSinceWhenDayTimeIsInThePast", testIntervalSinceWhenDayTimeIsInThePast),
    ]
}

extension FirestoreDeserializationTests {
    static let __allTests = [
        ("testDeserializeActiveSurvey", testDeserializeActiveSurvey),
        ("testDeserializeScheduledJobCreateSurveyBehaviorJobMessage", testDeserializeScheduledJobCreateSurveyBehaviorJobMessage),
    ]
}

extension FirestoreSerializationTests {
    static let __allTests = [
        ("testSerializeActiveSurvey", testSerializeActiveSurvey),
        ("testSerializeScheduledJobCreateSurveyBehaviorJobMessage", testSerializeScheduledJobCreateSurveyBehaviorJobMessage),
    ]
}

#if !os(macOS)
public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(DayTimeTests.__allTests),
        testCase(FirestoreDeserializationTests.__allTests),
        testCase(FirestoreSerializationTests.__allTests),
    ]
}
#endif
