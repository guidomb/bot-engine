import Foundation
import FeebiKit
import ReactiveSwift
import Result

GoogleAPI.shared.printDebugCurlCommand = true
GoogleAPI.shared.printRequest = true

let runner: BotBehaviorRunner
if let token = ProcessInfo.processInfo.environment["SLACK_API_TOKEN"] {
    runner = .slackRunner(token: token)
} else {
    runner = .consoleRunner()
}

runner.run()
RunLoop.main.run()
