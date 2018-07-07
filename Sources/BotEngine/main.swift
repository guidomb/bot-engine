import Foundation
import BotEngineKit
import GoogleAPI
import ReactiveSwift
import Result

GoogleAPI.shared.printDebugCurlCommand = true
GoogleAPI.shared.printRequest = true
FirestoreDocument.printSerializationDebugLog = true

let env = ProcessInfo.processInfo.environment
let hostname = env["HOSTNAME"] ?? "0.0.0.0"
let port = env["PORT"].flatMap(Int.init) ?? 8080
print("Starting HTTP server at port '\(port)'")
guard case .some(.success(let httpServer)) = BotEngine.HTTPServer.build(hostname: hostname, port: port).first() else {
    fatalError("ERROR - Unable to start HTTP server")
}

let googleToken: GoogleAPI.Token
let googleAuth = GoogleAuth()
let credentialsOptionName = "--google-service-account-credentials-file"
let credentialsOptionShortName = "-C"
let arguments = ProcessInfo.processInfo.arguments

if let credentialsArgIndex = arguments.index(where: { $0 == credentialsOptionName || $0 == credentialsOptionShortName })
    .map({ $0 + 1 }) {
    let delegatedAccount = arguments.index(of: "--delegated-account").map { index -> String in
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            fatalError("ERROR - Option '--delegated-account' requires a delegated account's emaill address value.")
        }
        return arguments[valueIndex]
    }
    guard credentialsArgIndex < arguments.count else {
        fatalError("ERROR - Option \(credentialsOptionName) requires a file URL.")
    }
    let credentialsFileUrl = URL(fileURLWithPath: arguments[credentialsArgIndex])
    print("INFO - Using google service account credentials file: '\(credentialsFileUrl.absoluteString)'")
    guard case .some(.success(let token)) = googleAuth.login(serviceAccountCredentials: credentialsFileUrl, delegatedAccount: delegatedAccount).first() else {
        fatalError("ERROR - Unable to login using Google OAuth")
    }
    googleToken = token
} else {
    guard let token = try? googleAuth.login(with: httpServer) else {
        fatalError("ERROR - Unable to login using Google OAuth")
    }
    googleToken = token
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

while true {
    fflush(stdout)
    usleep(10)
}
