import Foundation
import BotEngineCLI

let admins = ["U02F7KUJM"]
let configuration = BotEngineCLI.Configuration(
    googleAuth: .init(
        scopes: [
            "https://www.googleapis.com/auth/spreadsheets.readonly",
            "https://www.googleapis.com/auth/forms",
            "https://www.googleapis.com/auth/drive.metadata.readonly",
            "https://www.googleapis.com/auth/datastore",
            "https://www.googleapis.com/auth/admin.directory.group",
            "https://www.googleapis.com/auth/admin.directory.user.readonly"
        ],
        credentialsFilename: "wotcrendentials.json"
    ),
    environment: ProcessInfo.processInfo.environment,
    repositoryBuilder: { FirebaseObjectRepository(
        executor: $0,
        projectId: "feedi-dev",
        databaseId: "(default)"
        )
    }
)

let botEngine = BotEngineCLI(configuration: configuration) { engine in
    // Register commands
    engine.registerCommand(SubscribeToMailGroup())
    
    // Register schedulable actions
    engine.registerActions(
        SyncArgentinaMailingLists(),
        SyncMailChimpMailingList()
    )
    
    // Bind actions
    engine.bindAction(
        SyncArgentinaMailingLists(),
        to: "sync argentinean mailing lists",
        allow: .only(admins)
    )
    engine.bindAction(
        SyncMailChimpMailingList(),
        to: "sync mailchimp mailing list",
        allow: .only(admins)
    )
}
botEngine.run()