//
//  MockGoogleAPIResourceExecutor.swift
//  FeebiKitTests
//
//  Created by Guido Marucci Blas on 4/1/18.
//

import Foundation
import GoogleAPI

public final class MockGoogleAPIResourceExecutor: GoogleAPIResourceExecutor {
    
    private let fixtureManager: FixtureManager
    var response: Data? = .none
    
    public init(fixturesDirectoryPath: String) {
        self.fixtureManager = FixtureManager(fixturesDirectoryPath: fixturesDirectoryPath)
    }
    
    public func execute<T>(
        resource: GoogleAPI.Resource<T>,
        session: URLSession,
        deserializer: @escaping GoogleAPI.ResourceDeserializer<T>) -> GoogleAPI.ResourceProducer<T> {
        if let data = self.response {
            let url = URL(string: resource.urlPath)!
            guard let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "1.1", headerFields: [:]) else {
                fatalError("ERROR - Cannot create HTTURLResponse object")
            }
            let result = deserializer(data, response).mapError(GoogleAPI.RequestError.deserializationError)
            return GoogleAPI.ResourceProducer(result: result)
        } else {
            let error = GoogleAPI.ResourceError(
                code: 404,
                message: "There is no registered response. Maybe you forgot to call '\(setFixtureAsResourceResponse(fixturePath:))'",
                status: "NOT_AVAILABLE"
            )
            return GoogleAPI.ResourceProducer(error: .resourceError(error))
        }
    }
    
    public func setFixtureAsResourceResponse(fixturePath: String) {
        response = try! fixtureManager.loadFixture(in: fixturePath)
    }
    
}
