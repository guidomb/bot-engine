//
//  MailGroupService.swift
//  WoloxKit
//
//  Created by Guido Marucci Blas on 6/25/18.
//

import Foundation
import ReactiveSwift
import GoogleAPI
import Result
import BotEngineKit

public struct MailGroupService {
    
    public enum Domain: String {
        
        case woloxComAr = "wolox.com.ar"
        case woloxCo    = "wolox.co"
        case woloxCl    = "wolox.cl"
        
    }
    
    public enum Country: String {
        
        static let all: [Country] = [
            .argentina,
            .colombia,
            .chile,
            .us
        ]
        
        case argentina  = "argentina@wolox.com.ar"
        case colombia   = "colombia@wolox.com.ar"
        case chile      = "chile@wolox.com.ar"
        case us         = "us@wolox.com.ar"
        
    }
    
    public enum EveryOne: String {
        
        public static let subscribables: [EveryOne] = [
            .guemes,
            .azurduy,
            .colombia,
            .chile,
            .mexico,
            .us
        ]
        
        case all
        case guemes
        case azurduy
        case buenosAires = "buenosaires"
        case colombia
        case chile
        case mexico
        case us
        
        public var email: String {
            if case .all = self {
                return "everyone@wolox.com.ar"
            } else {
                return "everyone-\(self.rawValue)@wolox.com.ar"
                
            }
        }
        
        public init?(email: String) {
            if email == "everyone@wolox.com.ar" {
                self = .all
            } else if let value = parseEmail(email) {
                self = value
            } else {
                return nil
            }
        }
        
    }
    
    private let executor: GoogleAPIResourceExecutor
    
    public init(executor: GoogleAPIResourceExecutor) {
        self.executor = executor
    }
    
    public func syncBuenosAires(executeChanges: Bool = true) -> SignalProducer<([Member], [Member]), GoogleAPI.RequestError> {
        
        func insertInBuenosAires(member: Member) -> SignalProducer<Member, GoogleAPI.RequestError> {
            return GoogleAPI.directory
                .members(for: EveryOne.buenosAires.email)
                .insert(member: member)
                .execute(with: executor)
        }
        
        func deleteFromBuenosAires(member: Member) -> SignalProducer<Member, GoogleAPI.RequestError> {
            return GoogleAPI.directory
                .members(for: EveryOne.buenosAires.email)
                .delete(member: member.email)
                .execute(with: executor)
                .map { _ in member }
        }
        
        return SignalProducer.zip(
                members(in: .buenosAires).map(Set.init),
                members(in: .azurduy).map(Set.init),
                members(in: .guemes).map(Set.init)
            )
            .flatMap(.concat) { groups -> SignalProducer<([Member], [Member]), GoogleAPI.RequestError> in
                let (buenosAires, azurduy, guemes) = groups
                
                let onlyInAzurduy = azurduy.subtracting(buenosAires)
                let onlyInGuemes = guemes.subtracting(buenosAires)
                let membersToInsert = onlyInAzurduy.union(onlyInGuemes)
                let membersToDelete = buenosAires.filter { !azurduy.contains($0) && !guemes.contains($0) }
                
                if executeChanges {
                    return  SignalProducer.merge(membersToInsert.map(insertInBuenosAires)).collect()
                            .zip(with:
                            SignalProducer.merge(membersToDelete.map(deleteFromBuenosAires)).collect())
                } else {
                    return .init(value: (Array(membersToInsert), Array(membersToDelete)))
                }
                
            }
    }
 
    public func members(in group: EveryOne) -> SignalProducer<[Member], GoogleAPI.RequestError> {
        return fetchAllPages(
            options: ListMembersOptions(),
            using: GoogleAPI.directory.members(for: group.email).list(options:),
            executor: executor,
            extract: \.members
        )
    }
    
    public func members(in group: Country) -> SignalProducer<[Member], GoogleAPI.RequestError> {
        return fetchAllPages(
            options: ListMembersOptions(),
            using: GoogleAPI.directory.members(for: group.rawValue).list(options:),
            executor: executor,
            extract: \.members
        )
    }
    
    public func allCountryMembers() -> SignalProducer<[Member], GoogleAPI.RequestError> {
        return SignalProducer.merge(Country.all.map { members(in: $0) })
            .collect()
            .map { $0.flatten() }
    }
    
    public func subscribeMember(_ member: Member, to group: EveryOne) -> SignalProducer<Member, GoogleAPI.RequestError> {
        return GoogleAPI.directory
            .members(for: group.email)
            .insert(member: member)
            .execute(with: executor)
    }
    
    public func subscriptions(for member: Member) -> SignalProducer<[EveryOne], GoogleAPI.RequestError> {
        var options = ListGroupsOptions()
        options.domain = "wolox.com.ar"
        options.userKey = member.email
        return fetchAllPages(
            options: options,
            using: GoogleAPI.directory.groups.list(options:),
            executor: self.executor,
            extract: \.groups
        )
        .map(filterOnlyEveryOneGroups)
    }
    
    public func unsubscribe(member: Member, from mailGroup: EveryOne) -> SignalProducer<(Member, EveryOne), GoogleAPI.RequestError> {
        return GoogleAPI.directory
            .members(for: mailGroup.email)
            .delete(member: member.email)
            .execute(with: executor)
            .map { (member, mailGroup) }
    }
    
    public func unsubscribe(member: String, from mailGroup: EveryOne) -> SignalProducer<(String, EveryOne), GoogleAPI.RequestError> {
        return GoogleAPI.directory
            .members(for: mailGroup.email)
            .delete(member: member)
            .execute(with: executor)
            .map { (member, mailGroup) }
    }
    
    public func listUsers(in domain: Domain) -> SignalProducer<[DirectoryUser], GoogleAPI.RequestError> {
        var options = ListUsersOptions()
        options.domain = domain.rawValue
        return fetchAllPages(
            options: options,
            using: GoogleAPI.directory.users.list(options:),
            executor: executor,
            extract: \.users
        )
        .map { users in
            let filteredUsers = Set(domain.filteredUsersEmail(in: domain))
            return users.filter { !filteredUsers.contains($0.primaryEmail) }
        }
    }
    
    public func listAllUsers() -> SignalProducer<[DirectoryUser], GoogleAPI.RequestError> {
        return SignalProducer.merge(
            listUsers(in: .woloxComAr),
            listUsers(in: .woloxCo),
            listUsers(in: .woloxCl)
        )
        .collect()
        .map { lists in lists.flatMap { $0 } }
    }
    
}

fileprivate extension MailGroupService.Domain {
    
    func filteredUsersEmail(in domain: MailGroupService.Domain) -> [String] {
        switch domain {
        case .woloxComAr:
            return ["wonu@wolox.com.ar", "transparency@wolox.com.ar"]
        default:
            return []
        }
    }
    
}

extension Array where Element == MailGroupService.EveryOne {
    
    public func containsAnyBuenosAiresOffice() -> Bool {
        return self.contains(.azurduy) || self.contains(.guemes)
    }
    
}

fileprivate let everyoneEmailRegex: NSRegularExpression = {
    let subscribables = MailGroupService.EveryOne
        .subscribables
        .map { $0.rawValue }
        .joined(separator: "|")
    return try! NSRegularExpression(
        pattern: "^everyone-(\(subscribables))@wolox.com.ar$",
        options: .caseInsensitive
    )
}()

fileprivate func filterOnlyEveryOneGroups(_ groups: [Group]) -> [MailGroupService.EveryOne]{
    return groups.compactMap { MailGroupService.EveryOne.init(email: $0.email) }
}

fileprivate func parseEmail(_ email: String)  -> MailGroupService.EveryOne? {
    return email.firstMatch(regex: everyoneEmailRegex).flatMap(extractMailGroup(from: email))
}


fileprivate func extractMailGroup(from input: String) -> (NSTextCheckingResult) -> MailGroupService.EveryOne? {
    return { $0.substring(from: input, at: 1).flatMap(MailGroupService.EveryOne.init(rawValue:)) }
}
