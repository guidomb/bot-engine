import Foundation
import FeebiKit
import ReactiveSwift
import Result

GoogleAPI.shared.printDebugCurlCommand = true
GoogleAPI.shared.printRequest = true

guard let googleToken = try? GoogleAuth().login() else {
    fatalError("Unable to login using Google OAuth")
}

print("Running bot engine ...")
let engine = BotEngine.slackBotEngine(
    repository: FirebaseObjectRepository(
        token: googleToken,
        projectId: "feedi-dev",
        databaseId: "(default)"
    ),
    context: [
        "GoogleToken" : googleToken
    ]
)
engine.registerBehavior(CreateSurveyBehavior())
engine.registerBehavior(RandomMathQuestionBehavior())
engine.start()
RunLoop.main.run()
