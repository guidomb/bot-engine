//
//  File.swift
//  WoloxKitTests
//
//  Created by Guido Marucci Blas on 5/29/18.
//

import Foundation
import TestKit

func createResourceExecutor() -> MockGoogleAPIResourceExecutor {
    return MockGoogleAPIResourceExecutor(fixturesDirectoryPath: #file)
}

func createFixtureManager() -> FixtureManager {
    return FixtureManager(fixturesDirectoryPath: #file)
}
