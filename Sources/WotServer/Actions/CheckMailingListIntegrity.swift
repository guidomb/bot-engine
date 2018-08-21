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
    
    typealias CountryMember = (woloxer: String, subscriptions: Int)
    
    static func fetch(using services: BotEngine.Services) -> BotEngine.Producer<State> {
        return SignalProducer.combineLatest(
            listAllUser(using: services),
            fetchEveryoneMembers(using: services),
            fetchOfficeMailGroupMembers(using: services),
            fetchAllCountryMembers(using: services),
            fetchSpecialMailingListMembers(.nonWoloxers, using: services),
            fetchSpecialMailingListMembers(.everyoneBlacklist, using: services),
            fetchSpecialMailingListMembers(.multicountry, using: services)
        )
        .map(State.init)
    }
    
    let woloxers: Set<String>
    let everyoneMembers: Set<String>
    let officeMailGroupMembers: Set<String>
    let countryMembers: [Set<String>]
    let nonWoloxers: Set<String>
    let everyoneBlacklist: Set<String>
    let multicountry: Set<String>
    
    init(woloxers: Set<String>,
         everyoneMembers: Set<String>,
         officeMailGroupMembers: Set<String>,
         countryMembers: [Set<String>],
         nonWoloxers: Set<String>,
         everyoneBlacklist: Set<String>,
         multicountry: Set<String>) {
        self.woloxers = woloxers.subtracting(nonWoloxers)
        self.everyoneMembers = everyoneMembers
        self.officeMailGroupMembers = officeMailGroupMembers
        self.countryMembers = countryMembers
        self.nonWoloxers = nonWoloxers
        self.everyoneBlacklist = everyoneBlacklist
        self.multicountry = multicountry
    }
    
    func woloxersNotSubscribedToEveryone() -> Set<String> {
        return woloxers.subtracting(everyoneMembers).subtracting(everyoneBlacklist)
    }
    
    func woloxersNotSubscribedToAnyOfficeMailGroup() -> Set<String> {
        return woloxers.subtracting(officeMailGroupMembers).subtracting(everyoneBlacklist)
    }
    
    func countryMailGroupSubscriptions() -> (missing: [String], overSubscribed: [String]) {
        let countrySubscribtionsByWoloxer: [CountryMember] = woloxers.map { woloxer in
            let subscriptions = countryMembers.reduce(0) { $0 + ($1.contains(woloxer) ? 1 : 0) }
            return (woloxer: woloxer, subscriptions: subscriptions)
        }
        let missingCountrySubscribers = countrySubscribtionsByWoloxer
            .filter { $0.subscriptions == 0 && !everyoneBlacklist.contains($0.woloxer) }
            .map { $0.woloxer }
        let overSubscribedWoloxers = countrySubscribtionsByWoloxer
            .filter { $0.subscriptions > 1 && !multicountry.contains($0.woloxer) }
            .map { $0.woloxer }
        
        return (missing: missingCountrySubscribers, overSubscribed: overSubscribedWoloxers)
    }
    
}

fileprivate func renderState(_ state: State, newEveryoneSubscribers: Set<String>) -> BotEngine.ActionOutputMessage {
    let missingOfficeSubscribers = state.woloxersNotSubscribedToAnyOfficeMailGroup()
    let countrySubscribers = state.countryMailGroupSubscriptions()
    if  newEveryoneSubscribers.isEmpty &&
        missingOfficeSubscribers.isEmpty &&
        countrySubscribers.missing.isEmpty &&
        countrySubscribers.overSubscribed.isEmpty {
        return "All mail groups have passed the integrity check."
    }
    
    var message = ""
    var violationsCount = 0
    if !newEveryoneSubscribers.isEmpty {
        let list = newEveryoneSubscribers.map { "- \($0)" }.sorted().joined(separator: "\n")
        let everyoneMail = MailGroupService.EveryOne.all.email
        message += "The following woloxers have been added to '\(everyoneMail)':\n\(list)\n"
        violationsCount += newEveryoneSubscribers.count
    }
    if !missingOfficeSubscribers.isEmpty {
        let list = missingOfficeSubscribers.map { "- \($0)" }.sorted().joined(separator: "\n")
        message += "The following woloxers *are not subscribed* to any office mail group:\n\(list)\n"
        violationsCount += missingOfficeSubscribers.count
    }
    if !countrySubscribers.missing.isEmpty {
        let list = countrySubscribers.missing.map { "- \($0)" }.sorted().joined(separator: "\n")
        message += "The following woloxers *are not subscribed* to any country mail group:\n\(list)\n"
        violationsCount += countrySubscribers.missing.count
    }
    if !countrySubscribers.overSubscribed.isEmpty {
        let list = countrySubscribers.overSubscribed.map { "- \($0)" }.sorted().joined(separator: "\n")
        message += "The following woloxers *are subscribed to more than one* country mail group:\n\(list)\n"
        violationsCount += countrySubscribers.overSubscribed.count
    }
    message += "\nThere are *\(violationsCount)* mail group integrity violations"
    
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
   return SignalProducer.merge(members.map(subscribeMemeberToEveryoneMailGroup(using: services)))
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

fileprivate func fetchAllCountryMembers(using services: BotEngine.Services) -> BotEngine.Producer<[Set<String>]> {
    let countryMembersProducers = MailGroupService.Country.all.map { services.mailGroup.members(in: $0) }
    return SignalProducer.merge(countryMembersProducers)
        .collect()
        .map { membersByCountry in membersByCountry.map { Set($0.map(\.email)) } }
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

fileprivate func fetchSpecialMailingListMembers(_ mailGroup: MailGroupService.Special, using services: BotEngine.Services) -> BotEngine.Producer<Set<String>> {
    return services.mailGroup.members(in: mailGroup)
        .map { Set($0.map(\.email)) }
        .mapError(fetchSpecialGroupMembersError(mailGroup))
    
}

fileprivate func fetchMailGroupMembersError(_ mailGroup: MailGroupService.EveryOne) -> (GoogleAPI.RequestError) -> BotEngine.ErrorMessage {
    return { error in
        .init(message: """
        Oops! Something went wrong. I couldn't fetch the list of members for '\(mailGroup.rawValue)'.
        Google API services failed with \(error)
        """)
    }
}

fileprivate func fetchSpecialGroupMembersError(_ mailGroup: MailGroupService.Special) -> (GoogleAPI.RequestError) -> BotEngine.ErrorMessage {
    return { error in
        .init(message: """
            Oops! Something went wrong. I couldn't fetch the list of members for '\(mailGroup.rawValue)'.
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
