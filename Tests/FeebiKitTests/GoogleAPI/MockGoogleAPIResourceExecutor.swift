//
//  MockGoogleAPIResourceExecutor.swift
//  FeebiKitTests
//
//  Created by Guido Marucci Blas on 4/1/18.
//

import Foundation
@testable import FeebiKit

final class MockGoogleAPIResourceExecutor: GoogleAPIResourceExecutor {
    
//    private var responses: [String : Data] = [:]
    private let fixtureManager = FixtureManager()
    var response: Data? = .none
    
    init() {}
    
    func execute<T>(
        resource: GoogleAPI.Resource<T>,
        token: GoogleAPI.Token,
        session: URLSession,
        deserializer: @escaping GoogleAPI.ResourceDeserializer<T>) -> GoogleAPI.ResourceProducer<T> {
        if let data = self.response {
            let url = URL(string: resource.urlPath)!
            let response = HTTPURLResponse(
                url: url,
                mimeType: "application/json",
                expectedContentLength: data.count,
                textEncodingName: String.Encoding.utf8.description
            )
            let result = deserializer(data, response).mapError(GoogleAPI.RequestError.deserializationError)
            return GoogleAPI.ResourceProducer(result: result)
        } else {
            let error = GoogleAPI.ResourceError.create(
                code: 404,
                message: "There is no registered response. Maybe you forgot to call '\(setFixtureAsResourceResponse(fixturePath:))'",
                status: "NOT_AVAILABLE"
            )
            return GoogleAPI.ResourceProducer(error: .resourceError(error))
        }
    }
    
    func setFixtureAsResourceResponse(fixturePath: String) {
        response = try! fixtureManager.loadFixture(in: fixturePath)
    }
    
//    func execute<T>(
//        resource: GoogleAPI.Resource<T>,
//        token: GoogleAPI.Token,
//        session: URLSession,
//        deserializer: @escaping GoogleAPI.ResourceDeserializer<T>) -> GoogleAPI.ResourceProducer<T> {
//        let resourceKey = key(for: resource)
//        if let data = responses[resourceKey] {
//            let url = GoogleAPI.shared.absoluteUrl(for: resource)
//            let response = HTTPURLResponse(
//                url: url,
//                mimeType: "application/json",
//                expectedContentLength: data.count,
//                textEncodingName: String.Encoding.utf8.description
//            )
//            let result = deserializer(data, response).mapError(GoogleAPI.RequestError.deserializationError)
//            return GoogleAPI.ResourceProducer(result: result)
//        } else {
//            let error = GoogleAPI.ResourceError.create(
//                code: 404,
//                message: "There is no response registed for key '\(resourceKey)'",
//                status: "NOT_AVAILABLE"
//            )
//            return GoogleAPI.ResourceProducer(error: .resourceError(error))
//        }
//    }
    
//    func register<T>(response data: Data, for resource: GoogleAPI.Resource<T>) {
//        responses[key(for: resource)] = data
//    }
//
//    func register<T>(fixture fixturePath: String, for resource: GoogleAPI.Resource<T>) {
//        let data = try! fixtureManager.loadFixture(in: fixturePath)
//        register(response: data, for: resource)
//    }
//
}
//
//extension MockGoogleAPIResourceExecutor {
//    
//    func key<T>(for resource: GoogleAPI.Resource<T>) -> String {
//        let resourceType = String(describing: T.self)
//        return "\(resourceType)-\(resource.urlPath)"
//    }
//    
//}
