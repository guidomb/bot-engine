//
//  FixtureManager.swift
//  FeebiKitTests
//
//  Created by Guido Marucci Blas on 4/1/18.
//

import Foundation

final class FixtureManager {
    
    static let fixturesDirectory = URL(fileURLWithPath: #file).deletingLastPathComponent()
    
    func loadFixture(in fixturePath: String) throws -> Data {
        return try Data(contentsOf: fixtureUrl(for: fixturePath))
    }
    
    func fixtureUrl(for fixturePath: String) -> URL {
        return FixtureManager.fixturesDirectory.appendingPathComponent(fixturePath)
    }
    
    func save<T: Encodable>(object: T, in fixturePath: String) throws {
        let data = try JSONEncoder().encode(object)
        try data.write(to: fixtureUrl(for: fixturePath))
    }
    
    func loadFixture<T: Decodable>(in fixturePath: String, as decodableType: T.Type) throws -> T {
        let data = try loadFixture(in: fixturePath)
        return try JSONDecoder().decode(decodableType, from: data)
    }
    
}
