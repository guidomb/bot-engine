//
//  Helpers.swift
//  WotServer
//
//  Created by Guido Marucci Blas on 8/2/18.
//

import Foundation
import BotEngineKit
import WoloxKit

struct EveryoneMember {
    
    let email: String
    let subscriptions: [MailGroupService.EveryOne]
    
    init(member: Member, subscriptions: [MailGroupService.EveryOne]) {
        self.email = member.email
        if subscriptions.containsAnyBuenosAiresOffice() && !subscriptions.contains(.buenosAires) {
            self.subscriptions = subscriptions + [.buenosAires]
        } else {
            self.subscriptions = subscriptions
        }
    }
    
    func hasSubscriptions() -> Bool {
        return !subscriptions.isEmpty
    }
    
    func isSubscribed(to mailGroup: MailGroupService.EveryOne) -> Bool {
        return subscriptions.contains(mailGroup)
    }
    
    func isSubscribedToAnyBuenosAiresOffice() -> Bool {
        return isSubscribed(to: .azurduy) || isSubscribed(to: .guemes)
    }
    
}

func fetchUserInfo(userId: BotEngine.UserId, using slackService: SlackServiceProtocol) -> BotEngine.Producer<SKCore.User> {
    return slackService.fetchUserInfo(userId: userId.value)
        .mapError(BotEngine.ErrorMessage.init(error:))
}

func asMember(_ user: SKCore.User) -> BotEngine.Producer<Member> {
    guard let email = user.profile?.email else {
        return .init(error: "")
    }
    return  .init(value: Member(email: email, role: .member))
}

func fetchMemberSubscriptions(using service: MailGroupService)
    -> (Member) -> BotEngine.Producer<EveryoneMember> {
        return { member in
            service.subscriptions(for: member)
                .mapError(BotEngine.ErrorMessage.init(error:))
                .map { .init(member: member, subscriptions: $0) }
        }
}
