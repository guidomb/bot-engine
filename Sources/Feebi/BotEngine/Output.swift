//
//  OutputRenderer.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/6/18.
//

import Foundation

protocol BehaviorOutputRenderer {
    
    func render(output: BehaviorOutput, forChannel channel: ChannelId)
    
}

enum BehaviorOutput {
    
    case textMessage(String)
    case confirmationQuestion(message: String, question: String)
    
}

struct ResponseTransform {
    
    static func messageTransform(expected: String, transformed: String, channel: ChannelId, sender: String) -> ResponseTransform {
        return .init(
            expectedResponse: .message(
                message: BehaviorMessage(channel: channel, senderId: sender, text: expected),
                context: .anyContext),
            transformedResponse: .message(
                message: BehaviorMessage(channel: channel, senderId: sender, text: transformed),
                context: .init()
            )
        )
    }
    
    let expectedResponse: BotEngine.Input
    let transformedResponse: BotEngine.Input
    
}

struct ChanneledBehaviorOutput  {
        
    let output: BehaviorOutput
    let channel: ChannelId
    let transforms: [ResponseTransform]
    
    init(output: BehaviorOutput, channel: ChannelId, transforms: [ResponseTransform] = []) {
        self.output = output
        self.channel = channel
        self.transforms = transforms
    }
    
    init(output: BehaviorOutput, channel: ChannelId, transform: ResponseTransform) {
        self.init(output: output, channel: channel, transforms: [transform])
    }
    
}

extension ChannelId {
    
    static let anyChannel = ""
    
}

extension BehaviorMessage.Context {
    
    static let anyContext = BehaviorMessage.Context()
    
}
