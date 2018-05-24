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

let semaphore = DispatchSemaphore(value: 0)

GoogleAPI.directory
    .members(for: "comunicacion@wolox.com.ar")
    .list()
    .execute(using: googleToken)
    .startWithResult { result in
        switch result {
        case .success(let members):
            print(members)
        case .failure(let error):
            print("ERROR - Could not fetch memebers: \(error)")
        }
        semaphore.signal()
        exit(0)
    }

_ = semaphore.wait(timeout: DispatchTime.distantFuture)

print("Running bot engine ...")
let engine = BotEngine.slackBotEngine(
    slackToken: slackToken,
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
