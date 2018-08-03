//
//  Helpers.swift
//  WotServer
//
//  Created by Guido Marucci Blas on 8/2/18.
//

import Foundation
import BotEngineKit
import WoloxKit

typealias MemberWithSubscriptions = (member: Member, subscriptions: [MailGroupService.EveryOne])

func fetchUserInfo(userId: String, using slackService: SlackServiceProtocol) -> BotEngine.Producer<SKCore.User> {
    return slackService.fetchUserInfo(userId: userId)
        .mapError(BotEngine.ErrorMessage.init(error:))
}

func asMember(_ user: SKCore.User) -> BotEngine.Producer<Member> {
    guard let email = user.profile?.email else {
        return .init(error: "")
    }
    return  .init(value: Member(email: email, role: .member))
}

func fetchMemberSubscriptions(using service: MailGroupService)
    -> (Member) -> BotEngine.Producer<MemberWithSubscriptions> {
        return { member in
            service.subscriptions(for: member)
                .mapError(BotEngine.ErrorMessage.init(error:))
                .map { (member: member, subscriptions: $0) }
        }
}
