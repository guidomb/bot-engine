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
    
    public enum EveryOne: String {
        
        public static let subscribables: [EveryOne] = [
            .guemes,
            .azurduy,
            .chile,
            .mexico,
            .us
        ]
        
        case all
        case guemes
        case azurduy
        case buenosAires = "buenosaires"
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
    
    public func subscribeMember(_ member: Member, to group: EveryOne) -> SignalProducer<Member, GoogleAPI.RequestError> {
        return GoogleAPI.directory
            .members(for: group.email)
            .insert(member: member)
            .execute(with: executor)
    }
    
    public func subscriptions(for member: Member) -> SignalProducer<[EveryOne], GoogleAPI.RequestError> {
        var options = ListGroupsOptions()
        options.domain = "wolox.com.ar"
        return fetchAllPages(
            options: options,
            using: GoogleAPI.directory.groups.list(options:),
            executor: executor,
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
