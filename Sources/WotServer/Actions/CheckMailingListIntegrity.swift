//
//  CheckMailgroupMembers.swift
//  WotServer
//
//  Created by Guido Marucci Blas on 8/16/18.
//

import Foundation
import WoloxKit
import BotEngineKit

struct CheckMailingListIntegrity: BotEngineAction {
    
    func execute(using services: BotEngine.Services) -> BotEngine.ActionOutputMessageProducer {
        return State.fetch(using: services)
            |> subscribeMissingEveryoneMembers(using: services)
            |> renderState
    }
    
}

fileprivate struct State {
    
    static func fetch(using services: BotEngine.Services) -> BotEngine.Producer<State> {
        return SignalProducer.combineLatest(
            listAllUser(using: services),
            fetchEveryoneMembers(using: services),
            fetchOfficeMailGroupMembers(using: services),
            fetchAllCountryMembers(using: services)
        )
        .map(State.init)
    }
    
    let woloxers: Set<String>
    let everyoneMembers: Set<String>
    let officeMailGroupMembers: Set<String>
    let countryMembers: Set<String>
    
    func woloxersNotSubscribedToEveryone() -> Set<String> {
        return woloxers.subtracting(everyoneMembers)
    }
    
    func woloxersNotSubscribedToAnyOfficeMailGroup() -> Set<String> {
        return woloxers.subtracting(officeMailGroupMembers)
    }
    
    func woloxersNotSubscribedToAnyCountryMailGroup() -> Set<String> {
        return woloxers.subtracting(countryMembers)
    }
    
}

fileprivate func renderState(_ state: State, newEveryoneSubscribers: Set<String>) -> BotEngine.ActionOutputMessage {
    let missingOfficeSubscribers = state.woloxersNotSubscribedToAnyOfficeMailGroup()
    let missingCountrySubscribers = state.woloxersNotSubscribedToAnyCountryMailGroup()
    if newEveryoneSubscribers.isEmpty && missingOfficeSubscribers.isEmpty && missingCountrySubscribers.isEmpty {
        return "All mail groups have passed the integrity check."
    }
    
    var message = ""
    if !newEveryoneSubscribers.isEmpty {
        let list = newEveryoneSubscribers.map { "- \($0)" }.joined(separator: "\n")
        let everyoneMail = MailGroupService.EveryOne.all.email
        message += "The following woloxers have been added to '\(everyoneMail)':\n\(list)\n"
    }
    if !missingOfficeSubscribers.isEmpty {
        let list = missingOfficeSubscribers.map { "- \($0)" }.joined(separator: "\n")
        message += "The following woloxers *are not subscribed* to any office mail group:\n\(list)\n"
    }
    if !missingCountrySubscribers.isEmpty {
        let list = missingCountrySubscribers.map { "- \($0)" }.joined(separator: "\n")
        message += "The following woloxers *are not subscribed* to any country mail group:\n\(list)"
    }
    
    return .init(message: message)
}

fileprivate func subscribeMissingEveryoneMembers(using services: BotEngine.Services) -> (State) -> BotEngine.Producer<(State, Set<String>)> {
    return { state in
        let missingMembers = state.woloxersNotSubscribedToEveryone()
        return subscribeMemebersToEveryoneMailGroup(missingMembers, using: services)
            .map { _ in (state, missingMembers) }
    }
    
}

fileprivate func subscribeMemebersToEveryoneMailGroup(_ members: Set<String>, using services: BotEngine.Services) -> BotEngine.Producer<Set<String>> {
   return SignalProducer(members.map(subscribeMemeberToEveryoneMailGroup(using: services)))
        .collect()
        .map { _ in members }
}

fileprivate func subscribeMemeberToEveryoneMailGroup(using services: BotEngine.Services) -> (String) -> BotEngine.Producer<String> {
    return { email in
        services.mailGroup.subscribeMember(.init(email: email, role: .member), to: .all)
        .map { _ in email }
        .mapError { error in
            .init(message: """
                Oops! Something went wrong. I couldn't subscribe member '\(email)' to everyone mail group.
                Google API services failed with \(error)
                """
            )
        }
    }
}

fileprivate func fetchAllCountryMembers(using services: BotEngine.Services) -> BotEngine.Producer<Set<String>> {
    return services.mailGroup.allCountryMembers()
        .map { Set($0.map(\.email)) }
        .mapError { error in
            .init(message: """
                Oops! Something went wrong. I couldn't fetch all country mailing list's members.
                Google API services failed with \(error)
                """
            )
    }
}

fileprivate func fetchEveryoneMembers(using services: BotEngine.Services) -> BotEngine.Producer<Set<String>> {
    return fetchMembers(from: .all, using: services).map(Set.init)
}

fileprivate func fetchOfficeMailGroupMembers(using services: BotEngine.Services) -> BotEngine.Producer<Set<String>> {
    return SignalProducer.merge(
        fetchMembers(from: .buenosAires, using: services),
        fetchMembers(from: .colombia, using: services),
        fetchMembers(from: .chile, using: services),
        fetchMembers(from: .mexico, using: services),
        fetchMembers(from: .us, using: services)
    )
    .collect()
    .map { members in Set(members.flatten()) }
}

fileprivate func fetchMembers(
    from mailGroup: MailGroupService.EveryOne,
    using services: BotEngine.Services) -> BotEngine.Producer<Set<String>> {
    return services.mailGroup.members(in: mailGroup)
        .map { Set($0.map(\.email)) }
        .mapError(fetchMailGroupMembersError(mailGroup))
}


fileprivate func fetchMailGroupMembersError(_ mailGroup: MailGroupService.EveryOne) -> (GoogleAPI.RequestError) -> BotEngine.ErrorMessage {
    return { error in
        .init(message: """
        Oops! Something went wrong. I couldn't fetch the list of members for '\(mailGroup)'.
        Google API services failed with \(error)
        """)
    }
}

fileprivate func listAllUser(using services: BotEngine.Services) -> BotEngine.Producer<Set<String>> {
    return services.mailGroup.listAllUsers()
        .map { Set($0.map(\.primaryEmail)) }
        .mapError { error in
            .init(message: """
            Oops! Something went wrong. I couldn't fetch the list of woloxers.
            Google API services failed with \(error)
            """
            )
        }
}
