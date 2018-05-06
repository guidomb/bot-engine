//
//  OutputRenderer.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/6/18.
//

import Foundation

protocol OutputRendererProtocol {
    
    func render(output: Behavior.Output, forChannel channel: ChannelId)
    
}

struct SlackOutputRenderer: OutputRendererProtocol {
    
    let slackService: SlackServiceProtocol
    
    func render(output: Behavior.Output, forChannel channel: ChannelId) {
        switch output {
        case .textMessage(let message):
            slackService.sendMessage(channel: channel, text: message).startWithFailed { error in
                print("Error sending message:")
                print("\tChannel: \(channel)")
                print("\tMessage: \(message)")
                print("\tError: \(error)")
                print("")
            }
        
        case .confirmationQuestion(let yesMessage, let noMessage):
            slackService.sendMessage(channel: channel, text: "I need confirmation bitch!").startWithFailed { error in
                print("Error sending message:")
                print("\tChannel: \(channel)")
                print("\tError: \(error)")
                print("")
            }
        }
    }
    
}

struct ConsoleOutputRenderer: OutputRendererProtocol {
    
    func render(output: Behavior.Output, forChannel channel: ChannelId) {
        switch output {
        case .textMessage(let message):
            print("Output - \(message)")
        case .confirmationQuestion(let yesMessage, let noMessage):
            print("Output - Need confirmation. Enter:")
            print("\t 'y' - \(yesMessage)")
            print("\t 'n' - \(noMessage)")
        }
    }
    
}
