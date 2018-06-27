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

public struct MailGroupService {
    
    public enum EveryOne: String {
        
        case guemes
        case azurduy
        case buenosAires = "buenosaires"
        
        var email: String {
            return "everyone-\(self.rawValue)@wolox.com.ar"
        }
        
    }
    
    private let token: GoogleAPI.Token
    
    public init(token: GoogleAPI.Token) {
        self.token = token
    }
    
    public func syncBuenosAires() -> SignalProducer<([Member], [Member]), GoogleAPI.RequestError> {
        
        func insertInBuenosAires(member: Member) -> SignalProducer<Member, GoogleAPI.RequestError> {
            return GoogleAPI.directory
                .members(for: EveryOne.buenosAires.email)
                .insert(member: member)
                .execute(using: token)
        }
        
        func deleteFromBuenosAires(member: Member) -> SignalProducer<Member, GoogleAPI.RequestError> {
            return GoogleAPI.directory
                .members(for: EveryOne.buenosAires.email)
                .delete(member: member.email)
                .execute(using: token)
                .map { _ in member }
        }
        
        return SignalProducer.zip(
                members(in: .buenosAires).map(Set.init),
                members(in: .azurduy).map(Set.init),
                members(in: .guemes).map(Set.init)
            )
            .flatMap(.concat) { groups -> SignalProducer<([Member], [Member]), GoogleAPI.RequestError> in
                let (buenosAires, azurduy, guemes) = groups
                
                let insertedMembers = azurduy.subtracting(buenosAires).map(insertInBuenosAires) +
                    guemes.subtracting(buenosAires).map(insertInBuenosAires)
                
                let deletedMembers = buenosAires.filter { !azurduy.contains($0) && !guemes.contains($0) }
                    .map(deleteFromBuenosAires)
                
                return  SignalProducer.merge(insertedMembers).collect()
                        .zip(with:
                        SignalProducer.merge(deletedMembers).collect())
            }
    }
 
    public func members(in group: EveryOne) -> SignalProducer<[Member], GoogleAPI.RequestError> {
        
        func fetchMembersPage(pageToken: String? = .none) -> SignalProducer<[Member], GoogleAPI.RequestError> {
            var options = ListMembersOptions()
            options.pageToken = pageToken
            return GoogleAPI.directory
                .members(for: group.email)
                .list(options: options)
                .execute(using: token)
                .flatMap(.concat) { memberList -> SignalProducer<[Member], GoogleAPI.RequestError> in
                    if let nextPageToken = memberList.nextPageToken {
                        return fetchMembersPage(pageToken: nextPageToken).map { memberList.members + $0 }
                    } else {
                        return .init(value: memberList.members)
                    }
                }
        }
        
        return fetchMembersPage()

    }
}