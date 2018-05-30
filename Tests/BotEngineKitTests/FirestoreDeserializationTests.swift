//
//  FirestoreDeserializationTests.swift
//  BotEngineKitTests
//
//  Created by Guido Marucci Blas on 5/29/18.
//

import Foundation
import XCTest
import BotEngineKit
import GoogleAPI
import TestKit

class FirestoreDeserializationTests: XCTestCase {
    
    var fixtureManager: FixtureManager!
    
    override func setUp() {
        fixtureManager = createFixtureManager()
    }
    
    func testDeserializeScheduledJobCreateSurveyBehaviorJobMessage() {
        let documentList = try? fixtureManager.loadFixture(
            in: "Deserialization/ScheduledJob_CreateSurvey_JobMessage_FirestoreDocumentList.json",
            as: FirestoreDocumentList.self
        )
        let scheduledJob: ScheduledJob<CreateSurveyBehavior.JobMessage>? = documentList?
            .documents?
            .first
            .flatMap { try? $0.deserialize() }
        
        XCTAssertNotNil(scheduledJob)
    }
    
    func testDeserializeActiveSurvey() {
        let document = try? fixtureManager.loadFixture(
            in: "Deserialization/ActiveSurvey_FirestoreDocument.json",
            as: FirestoreDocument.self
        )
        let activeSurvey: ActiveSurvey? = document
            .flatMap { try? $0.deserialize() }
        
        XCTAssertNotNil(activeSurvey)
    }
    
}
