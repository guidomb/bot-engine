//
//  AbilityScraperTests.swift
//  FeebiKitTests
//
//  Created by Guido Marucci Blas on 4/1/18.
//

import Foundation
import XCTest
import GoogleAPI
import TestKit
@testable import WoloxKit

class AbilityScraperTests: XCTestCase {

    var resourceExecutor: MockGoogleAPIResourceExecutor!
    var fixtureManager: FixtureManager!
    let spreadSheetId = "somespreadsheetid123456"
    
    override func setUp() {
        fixtureManager = createFixtureManager()
        resourceExecutor = createResourceExecutor()
    }
    
    func testScrapWithValidAbility() {
        let expectedAbility = try! fixtureManager.loadFixture(in: "Performance/AbilityU1.json", as: Ability.self)
        let mapper = UniversalAbilityGroupMapper(spreadSheetName: "SomeSpreadSheetName").abilityU1
        resourceExecutor.setFixtureAsResourceResponse(fixturePath: "Performance/AbilityU1SpreadSheetsPayload.json")

        let scraper = AbilityScraper(mapper: mapper, executor: resourceExecutor)
        
        let result = scraper.scrap(spreadSheetId: spreadSheetId).first()!
        XCTAssertEqual(result.value, [expectedAbility])
    }
    
    func testScrapWithValidAbilities() {
        let expectedAbilities = try! fixtureManager.loadFixture(in: "Performance/UniversalAbilityGroup.json", as: [Ability].self)
        let mapper = UniversalAbilityGroupMapper(spreadSheetName: "SomeSpreadSheetName")
        resourceExecutor.setFixtureAsResourceResponse(fixturePath: "Performance/UniversalAbilityGroupSpreadSheetsPayload.json")
        
        let scraper = AbilityScraper(abilityGroupMapper: mapper, executor: resourceExecutor)
        
        let result = scraper.scrap(spreadSheetId: spreadSheetId).first()!
        XCTAssertEqual(result.value, expectedAbilities)
    }
    
}

