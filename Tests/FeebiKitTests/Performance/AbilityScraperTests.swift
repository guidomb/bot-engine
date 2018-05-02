//
//  AbilityScraperTests.swift
//  FeebiKitTests
//
//  Created by Guido Marucci Blas on 4/1/18.
//

import Foundation
import XCTest
//import Quick
//import Nimble
@testable import FeebiKit

class AbilityScraperTests: XCTestCase {

    var resourceExecutor: MockGoogleAPIResourceExecutor!
    let token = GoogleAPI.Token(type: "Bearer", value: "somefaketoken123456")
    let spreadSheetId = "somespreadsheetid123456"
    let fixtureManager = FixtureManager()
    
    override func setUp() {
        resourceExecutor = MockGoogleAPIResourceExecutor()
    }
    
    func testScrapWithValidAbility() {
        let expectedAbility = try! fixtureManager.loadFixture(in: "Performance/AbilityU1.json", as: Ability.self)
        let mapper = UniversalAbilityGroupMapper(spreadSheetName: "SomeSpreadSheetName").abilityU1
        resourceExecutor.setFixtureAsResourceResponse(fixturePath: "Performance/AbilityU1SpreadSheetsPayload.json")

        let scraper = AbilityScraper(mapper: mapper, executor: resourceExecutor)
        
        let result = scraper.scrap(spreadSheetId: spreadSheetId, token: token).first()!
        XCTAssertEqual(result.value, [expectedAbility])
    }
    
    func testScrapWithValidAbilities() {
        let expectedAbilities = try! fixtureManager.loadFixture(in: "Performance/UniversalAbilityGroup.json", as: [Ability].self)
        let mapper = UniversalAbilityGroupMapper(spreadSheetName: "SomeSpreadSheetName")
        resourceExecutor.setFixtureAsResourceResponse(fixturePath: "Performance/UniversalAbilityGroupSpreadSheetsPayload.json")
        
        let scraper = AbilityScraper(abilityGroupMapper: mapper, executor: resourceExecutor)
        
        let result = scraper.scrap(spreadSheetId: spreadSheetId, token: token).first()!
        XCTAssertEqual(result.value, expectedAbilities)
    }
    
}

