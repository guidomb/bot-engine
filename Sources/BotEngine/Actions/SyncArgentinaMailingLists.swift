//
//  SyncArgentinaMailingLists.swift
//  BotEngine
//
//  Created by Guido Marucci Blas on 7/14/18.
//

import Foundation
import WoloxKit
import BotEngineKit
import ReactiveSwift
import Result
import GoogleAPI

struct SyncArgentinaMailingLists: BotEngineAction {
    
    let startingMessage = "Syncing argentinean mailing lists ..."
    
    func execute(using services: BotEngine.Services) -> BotEngine.ActionOutputProducer {
        guard let googleToken = services.googleToken else {
            fatalError("ERROR - Missing google token in context with key '\(ContextKey.googleToken.rawValue)'")
        }
        
        let mailGroupService = MailGroupService(token: googleToken)
        return mailGroupService.syncBuenosAires(executeChanges: false)
            .mapError(BotEngine.ErrorMessage.init(error:))
            .flatMap(.concat, printMembers(using: services))
    }
    
}

fileprivate func printMembers(using services: BotEngine.Services) -> ((inserted: [Member], deleted: [Member]))
    -> BotEngine.ActionOutputProducer {
    return { members in
        guard !members.inserted.isEmpty && !members.deleted.isEmpty else {
            return .init(value: "There are no members from azurduy, guemes and buenos-aires mailing lists to be synced")
        }
        
        let insertedList = members.inserted.map { "    - \($0.email)" }.joined(separator: "\n")
        let deletedList = members.deleted.map { "    - \($0.email)" }.joined(separator: "\n")
        let message = """
        Mailing lists azurduy, guemes and buenos-aires have been synced.
        
        *INSERTED*
        \(insertedList)
        
        *DELETED*
        \(deletedList)
        
        *\(members.inserted.count) members inserted* into buenos-aires mailing list.
        *\(members.deleted.count) memebers deleted* from buenos-aires mailing list.
        """
        
        return .init(value: .init(message: message))
    }
}
