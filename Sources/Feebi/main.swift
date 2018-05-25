import Foundation
import FeebiKit
import ReactiveSwift
import Result

GoogleAPI.shared.printDebugCurlCommand = true
GoogleAPI.shared.printRequest = true

guard let googleToken = try? GoogleAuth().login() else {
    fatalError("Unable to login using Google OAuth")
}
guard let slackToken = ProcessInfo.processInfo.environment["SLACK_API_TOKEN"] else {
    fatalError("Missing Slack API token. You need to define SLACK_API_TOKEN env variable.")
}
guard let slackVerificationToken = ProcessInfo.processInfo.environment["SLACK_VERIFICATION_TOKEN"] else {
    fatalError("Missing Slack verification token. You need to define SLACK_VERIFICATION_TOKEN env variable.")
}

print("Running bot engine ...")
let engine = BotEngine.slackBotEngine(
    slackToken: slackToken,
    verificationToken: slackVerificationToken,
    googleToken: googleToken,
    repository: FirebaseObjectRepository(
        token: googleToken,
        projectId: "feedi-dev",
        databaseId: "(default)"
    )
)
engine.registerBehavior(CreateSurveyBehavior(googleToken: googleToken))
engine.start()
RunLoop.main.run()
