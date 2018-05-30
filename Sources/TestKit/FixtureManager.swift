//
//  FixtureManager.swift
//  FeebiKitTests
//
//  Created by Guido Marucci Blas on 4/1/18.
//

import Foundation

public final class FixtureManager {
    
    let fixturesDirectory: URL
    
    public init(fixturesDirectoryPath: String) {
        self.fixturesDirectory = URL(fileURLWithPath: fixturesDirectoryPath).deletingLastPathComponent()
    }
    
    public func loadFixture(in fixturePath: String) throws -> Data {
        return try Data(contentsOf: fixtureUrl(for: fixturePath))
    }
    
    public func loadJSONFixture(in fixturePath: String) throws -> [String : Any] {
        let data = try loadFixture(in: fixturePath)
        return (try JSONSerialization.jsonObject(with: data, options: [])) as! [String : Any]
    }
    
    public func fixtureUrl(for fixturePath: String) -> URL {
        return fixturesDirectory.appendingPathComponent(fixturePath)
    }
    
    public func save<T: Encodable>(object: T, in fixturePath: String) throws {
        let data = try JSONEncoder().encode(object)
        try data.write(to: fixtureUrl(for: fixturePath))
    }
    
    public func loadFixture<T: Decodable>(in fixturePath: String, as decodableType: T.Type) throws -> T {
        let data = try loadFixture(in: fixturePath)
        return try JSONDecoder().decode(decodableType, from: data)
    }
    
}
