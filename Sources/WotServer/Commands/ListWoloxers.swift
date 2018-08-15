//
//  ListWoloxers.swift
//  WotServer
//
//  Created by Guido Marucci Blas on 8/14/18.
//

import Foundation
import WoloxKit
import BotEngineKit
import ReactiveSwift
import Result
import GoogleAPI

struct ListWoloxers: BotEngineCommand {

    var commandUsage: String {
        return "list woloxers"
    }
    
    let permission: BotEngine.ExecutionPermission
    
    init(permission: BotEngine.ExecutionPermission) {
        self.permission = permission
    }
    
    func parseInput(_ input: String) -> Optional<()> {
        return input == commandUsage ? () : .none
    }
    
    func execute(using services: BotEngine.Services, parameters: (), senderId: BotEngine.UserId) -> BotEngine.CommandOutputProducer {
        return MailGroupService(executor: services.googleAPIResourceExecutor)
            .listAllUsers()
            .map(makeCSVFile)
            .mapError(BotEngine.ErrorMessage.init(error:))
    }
    
}

fileprivate func makeCSVFile(_ woloxers: [DirectoryUser]) -> BotEngine.CommandOutput {
    let data = woloxers.map(asCSVRow)
        .joined(separator: "\n")
        .data(using: .utf8)!
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let date = dateFormatter.string(from: Date())
    
    return .init(
        message: "There you go. That's the latest list of *\(woloxers.count) woloxers*.",
        file: .init(
            name: "WoloxersList-\(date).csv",
            contentType: "text/csv", content: data,
            description: "A list of woloxer as of \(date)"
        )
    )
}

fileprivate func asCSVRow(_ user: DirectoryUser) -> String {
    let firstName = user.name.givenName.trimmingCharacters(in: .whitespaces)
    let lastName = user.name.familyName.trimmingCharacters(in: .whitespaces)
    let email = user.primaryEmail.trimmingCharacters(in: .whitespaces)
    return "\(firstName),\(lastName),\(email)"
}
