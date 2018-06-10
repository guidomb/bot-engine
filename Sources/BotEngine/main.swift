import Foundation
import BotEngineKit
import GoogleAPI
import ReactiveSwift
import Result

GoogleAPI.shared.printDebugCurlCommand = true
GoogleAPI.shared.printRequest = true
FirestoreDocument.printSerializationDebugLog = true

guard case .some(.success(let httpServer)) = BotEngine.HTTPServer.build().first() else {
    fatalError("ERROR - Unable to start HTTP server")
}
guard let googleToken = try? GoogleAuth().login(with: httpServer) else {
    fatalError("ERROR - Unable to login using Google OAuth")
}

print("Running bot engine ...")
let engine = BotEngine.slackBotEngine(
    server: httpServer,
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
