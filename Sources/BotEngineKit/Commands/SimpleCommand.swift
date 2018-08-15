//
//  SimpleCommand.swift
//  BotEngineKit
//
//  Created by Guido Marucci Blas on 8/4/18.
//

import Foundation
import ReactiveSwift
import Result

struct SimpleCommand: BotEngineCommand {

    let commandUsage: String
    let permission: BotEngine.ExecutionPermission
    private let action: (BotEngine.UserId) -> BotEngine.Producer<String>
    
    init(command: String, permission: BotEngine.ExecutionPermission = .all, action: @escaping (BotEngine.UserId) -> BotEngine.Producer<String>) {
        self.commandUsage = command
        self.action = action
        self.permission = permission
    }
    
    func parseInput(_ input: String) -> Optional<()> {
        return input == commandUsage ? () : nil
    }
    
    func execute(using services: BotEngine.Services, parameters: (), senderId: BotEngine.UserId) -> BotEngine.Producer<BotEngine.CommandOutput> {
        return action(senderId).map { .init(message: $0) }
    }
    
}
