//
//  DayTimeTests.swift
//  BotEngineKit
//
//  Created by Guido Marucci Blas on 5/30/18.
//

import Foundation
import XCTest
import BotEngineKit
import SwiftCheck

struct Time {

    let hours: Int
    let minutes: Int

}

extension Time: Arbitrary {

    public static var arbitrary: Gen<Time> {
        let hours = Int.arbitrary.suchThat { $0 >= 0 && $0 < 24 }
        let minutes = Int.arbitrary.suchThat { $0 >= 0 && $0 < 60 }
        return Gen<(Int, Int)>.zip(hours, minutes).map(Time.init)
    }

    public static var timeString: Gen<String> {
        return arbitrary.map { "\($0.hours):\($0.minutes)" }
    }

    public static var invalidTimeString: Gen<String> {
        let invalidHours = Int.arbitrary.suchThat { $0 > 23 || $0 < 0 }
        let invalidMinutes = Int.arbitrary.suchThat { $0 > 59 || $0 < 0 }
        let invalidTimeStringGen = Gen<(Int, Int)>.zip(invalidHours, invalidMinutes).map { "\($0.0):\($0.1)" }
        let seconds = Int.arbitrary.map(String.init)
        return Gen.one(of: [
            invalidTimeStringGen,
            Gen<(String, String)>.zip(invalidTimeStringGen, seconds).map { "\($0.0):\($0.1)" },
            Gen<(String, String)>.zip(timeString, seconds).map { "\($0.0):\($0.1)" },
        ])
    }

}

extension DayTime: Arbitrary {

    public static var arbitrary: Gen<DayTime> {
        return Time.arbitrary.map { DayTime(hours: $0.hours, minutes: $0.minutes)! }
    }

}

class DayTimeTests: XCTestCase {

    func testInitializerWithInvalidHours() {
        let greaterThanTwentyThree = Int.arbitrary.suchThat { $0 > 23 }
        property("Hours value must be lower then 24") <- forAll(greaterThanTwentyThree) { (hours: Int) in
            return DayTime(hours: hours, minutes: 30) == nil
        }

        let negatives = Int.arbitrary.suchThat { $0 < 0 }
        property("Hours value must be greater or equal to 0") <- forAll(negatives) { (hours: Int) in
            return DayTime(hours: hours, minutes: 30) == nil
        }
    }

    func testInitializerWithInvalidMinutes() {
        let greaterThanFiftyNine = Int.arbitrary.suchThat { $0 > 59 }
        property("Minutes value must be lower then 60") <- forAll(greaterThanFiftyNine) { (minutes: Int) in
            return DayTime(hours: 10, minutes: minutes) == nil
        }

        let negatives = Int.arbitrary.suchThat { $0 < 0 }
        property("Minutes value must be greater or equal to 0") <- forAll(negatives) { (minutes: Int) in
            return DayTime(hours: 10, minutes: minutes) == nil
        }
    }

    func testInitializerWithValidHoursAndMinutes() {
        property("It accepts valid hours and minutes values") <- forAll { (time: Time) in
            return DayTime(hours: time.hours, minutes: time.minutes) != nil
        }
    }

    func testAtWithInvalidTimeString() {
        property("It rejects any random time strings") <- forAll { (time: String) in
            return DayTime.at(time) == nil
        }

        property("It rejects invalid time strings") <- forAll(Time.invalidTimeString) { (time: String) in
            return DayTime.at(time) == nil
        }
    }

    func testAtWithValidTimeString() {
        property("It accepts valid time strings") <- forAll(Time.timeString) { (time: String) in
            return DayTime.at(time) != nil
        }
    }

    func testAtWithInvalidTimeZoneIdentifier() {
        property("It rejects invalid time zone identifiers") <- forAll { (identifier: String) in
            return DayTime.at("10:30", in: identifier) == nil
        }
    }

    func testAtWithValidTimeZoneIdentifier() {
        #if os(Linux)
        // For some reasons calling TimeZone.init(identifier:) with the following
        // timezone identifiers returns nil only on Linux
        let exceptions =  [
          "America/Fort_Nelson",
          "America/Punta_Arenas",
          "Asia/Famagusta",
          "Asia/Atyrau",
          "Asia/Yangon",
          "Europe/Kirov",
          "Europe/Astrakhan",
          "Europe/Saratov",
          "Europe/Ulyanovsk",
          "Asia/Barnaul",
          "Asia/Tomsk"
        ]
        let identifiers = Gen.fromElements(of: TimeZone.knownTimeZoneIdentifiers.filter { !exceptions.contains($0) })
        #else
        let identifiers = Gen.fromElements(of: TimeZone.knownTimeZoneIdentifiers)
        #endif

        property("It accepts valid time zone identifiers") <- forAll(identifiers) { (identifier: String) in
            return DayTime.at("10:30", in: identifier) != nil
        }
    }
    
    func testIntervalSinceWhenDayTimeIsInTheFuture() {
        let a = DayTime.at("10:30")!
        let b = DayTime.at("10:40")!
        
        XCTAssertEqual(a.intervalSince(b), (24 * 60 * 60) - (10 * 60))
    }
    
    func testIntervalSinceWhenDayTimeIsInThePast() {
        let a = DayTime.at("10:30")!
        let b = DayTime.at("10:40")!
        
        XCTAssertEqual(b.intervalSince(a), 10 * 60)
    }

}
