//
//  Fixtures.swift
//  GoogleAPITests
//
//  Created by Guido Marucci Blas on 10/2/18.
//
import Foundation
import TestKit

func createResourceExecutor() -> MockGoogleAPIResourceExecutor {
    return MockGoogleAPIResourceExecutor(fixturesDirectoryPath: #file)
}

func createFixtureManager() -> FixtureManager {
    return FixtureManager(fixturesDirectoryPath: #file)
}
