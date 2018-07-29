//
//  SyncMailChimpMailingList.swift
//  BotEngine
//
//  Created by Guido Marucci Blas on 7/15/18.
//

import Foundation
import WoloxKit
import BotEngineKit
import ReactiveSwift
import Result
import GoogleAPI

private let mailingListId = "331f15e613"

struct SyncMailChimpMailingList: BotEngineAction {
    
    let startingMessage: String? = "Syncing MailChimp mailing list ..."
    
    func execute(using services: BotEngine.Services) -> BotEngine.ActionOutputProducer {
        guard let apiKey = ProcessInfo.processInfo.environment["MAILCHIMP_API_KEY"] else {
            fatalError("ERROR - Missing MAILCHIMP_API_KEY environmental variable")
        }
        
        return MailGroupService(executor: services.googleAPIResourceExecutor)
            .members(in: .all)
            .mapError(BotEngine.ErrorMessage.init(error:))
            .flatMap(.concat, addMembersToMailChimpList(apiKey: apiKey))
    }
    
}

fileprivate func addMembersToMailChimpList(apiKey: String) -> ([Member]) -> BotEngine.ActionOutputProducer {
    return { members in
        MailChimp(apiKey: apiKey).lists
            .update(list: mailingListId, members: members.map(asMailChimpMember))
            .mapError(BotEngine.ErrorMessage.init(error:))
            .map(printNewMembers)
    }
}

fileprivate func asMailChimpMember(_ member: Member) -> MailChimp.Lists.Member {
    return .init(emailAddress: member.email, status: .subscribed)
}

fileprivate func printNewMembers(_ response: MailChimp.Lists.UpdateMembersResponse) -> BotEngine.ActionOutputMessage {
    let addedMembers = response.newMembers
        .map { "    - \($0.emailAddress)" }
        .joined(separator: "\n")
    let message = """
    MailChimp mailing list '\(mailingListId)' has been synced with everyone mailing list.
    Added members:
    \(addedMembers)
    
    *\(response.totalCreated) new members added* to MailChimp mailing list.
    """
    return .init(message: message)
}
