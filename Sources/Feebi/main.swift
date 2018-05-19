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

//let jobOrchestrator = RecurringJobOrchestrator(store: InMemoryRecurringJobStore())
//guard let bootstrapResult = jobOrchestrator.bootstrap().first() else {
//    print("ERROR - Unable to bootstrap recurring job orchestrator.")
//    exit(1)
//}
//switch bootstrapResult {
//case .success(let activeJobs):
//    print("Running recurring job orchestrator. There are \(activeJobs.count) active jobs.")
//case .failure(let error):
//    print("ERROR - Unable to bootstrap recurring job orchestrator: \(error)")
//    exit(1)
//}

print("Running bot engine ...")
let engine = BotEngine.slackBotEngine(
    slackToken: slackToken,
    googleToken: googleToken,
    repository: InMemoryObjectRepository()
)
engine.registerBehavior(CreateSurveyBehavior(googleToken: googleToken))
engine.start()
RunLoop.main.run()
