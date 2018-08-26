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
        
        let fields = FirestoreDocument.serialize(object: schedulableJob, skipFields: ["id"])?.fields
        let values = fields.map(FirestoreDocument.MapValue.init)
        let fixture = try? fixtureManager.loadFixture(
            in: "Serialization/ScheduledJob_CreateSurvey_JobMessage.json",
            as: FirestoreDocument.MapValue.self
        )
        
        XCTAssertEqual(values, fixture)
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
        
        let fields = FirestoreDocument.serialize(object: survey, skipFields: ["id"])?.fields
        let values = fields.map(FirestoreDocument.MapValue.init)
        let fixture = try? fixtureManager.loadFixture(
            in: "Serialization/ActiveSurvey.json",
            as: FirestoreDocument.MapValue.self
        )
    
        XCTAssertEqual(values, fixture)
    }
    
    func testSerializeUserConfiguration() {
        let configuration = UserConfiguration(engineUserId: .init(value: "U02FQLM2P"))
        
        let fields = FirestoreDocument.serialize(object: configuration, skipFields: ["id"])?.fields
        let values = fields.map(FirestoreDocument.MapValue.init)
        let fixture = try? fixtureManager.loadFixture(
            in: "Serialization/UserConfiguration.json",
            as: FirestoreDocument.MapValue.self
        )
        
        XCTAssertEqual(values, fixture)
    }
    
}

