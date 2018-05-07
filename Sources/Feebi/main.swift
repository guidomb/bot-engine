import Foundation
import FeebiKit
import ReactiveSwift
import Result

GoogleAPI.shared.printDebugCurlCommand = true
GoogleAPI.shared.printRequest = true

guard let googleToken = try? GoogleAuth().login() else {
    fatalError("Unable to login using Google OAuth")
}

let runner: BotBehaviorRunner
if let slackToken = ProcessInfo.processInfo.environment["SLACK_API_TOKEN"] {
    print("Using slack runner.")
    runner = .slackRunner(slackToken: slackToken, googleToken: googleToken)
} else {
    print("Using console runner.")
    runner = .consoleRunner(googleToken: googleToken)
}

print("Running bot ...")
runner.run()
RunLoop.main.run()
