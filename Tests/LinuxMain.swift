import XCTest

import WoloxKitTests
import BotEngineKitTests
import GoogleAPITests

var tests = [XCTestCaseEntry]()
tests += WoloxKitTests.__allTests()
tests += BotEngineKitTests.__allTests()
tests += GoogleAPITests.__allTests()

XCTMain(tests)
