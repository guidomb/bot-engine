//
//  FirestoreSerializationTests.swift
//  BotEngineKitTests
//
//  Created by Guido Marucci Blas on 5/30/18.
//

import Foundation
import XCTest
@testable import BotEngineKit
import GoogleAPI
import TestKit

class FirestoreSerializationTests: XCTestCase {
    
    var fixtureManager: FixtureManager!
    
    override func setUp() {
        fixtureManager = createFixtureManager()
    }
    
    func testSerializeScheduledJobCreateSurveyBehaviorJobMessage() {
        let schedulableJob = SchedulableJob<CreateSurveyBehavior.JobMessage>(
            interval: .everyDay(at: DayTime.at("10:30", in: "America/Argentina/Buenos_Aires")!),
            message: .monitorSurvey(surveyId: Identifier(identifier: "xwu9KTMoKOFBc9xmF6kR"))
        ).asCancelableJob()
        
        let json = serialize(value: schedulableJob)
        let expectedJson = try! fixtureManager.loadFixtureAsDictionary(in: "Serialization/ScheduledJob_CreateSurvey_JobMessage.json")
        
        XCTAssertEqual(json, expectedJson)
    }
    
    func testSerializeActiveSurvey() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.date(from: "2018-10-10")!
        let survey = ActiveSurvey(
            survey: Survey(
                formId: "1mlteVfq46HlO4VPR4LQjUKAqGS8f8fE7AtqWapqoM3w",
                destinataries: [
                    .slackUser(
                        id: "U02FQLM2P",
                        info: UserEntityInfo(
                            id: "U02FQLM2P",
                            name: "anita",
                            email: "anita.romero@wolox.com.ar",
                            firstName: "Anita",
                            lastName: "Romero"
                        )
                    )
                ],
                deadline: date,
                creatorId: BotEngine.UserId(value: "U02F7KUJM")
            ),
            destinataries: Set(["U02FQLM2P"])
        )
        
        let json = serialize(value: survey)
        let expectedJson = try! fixtureManager.loadFixtureAsDictionary(in: "Serialization/ActiveSurvey.json")
    
        XCTAssertEqual(json, expectedJson)
    }
    
    func testSerializeEmptyUserConfiguration() {
        var configuration = UserConfiguration(engineUserId: .init(value: "U02FQLM2P"))
        configuration.intentLanguage = .spanish
        configuration.properties = [
            "someFlag"          : .bool(true),
            "someStringValue"   : .string("hello"),
            "someDoubleValue"   : .double(10.50),
            "someIntegerValue"  : .integer(10)
        ]
        
        let json = serialize(value: configuration)
        let expectedJson = try! fixtureManager.loadFixtureAsDictionary(in: "Serialization/UserConfiguration.json")
        
        XCTAssertEqual(json, expectedJson)
    }
    
}

fileprivate func serialize<T: Persistable>(value: T, id: String = "fKtnskPFrsR7YdM0KXmS") -> NSDictionary {
    let name = "projects/feedi-dev/databases/(default)/documents/\(T.collectionName)/\(id)"
    let document = try! FirestoreEncoder().encode(value, name: name, skipFields: ["id"])
    let data = try! JSONEncoder().encode(document)
    let json = try! JSONSerialization.jsonObject(with: data, options: []) as! NSDictionary
    return json
}
