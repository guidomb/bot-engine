import Foundation
import Commandant
import BotEngineKit

internal typealias CLIError = CommandantError<BotEngineCLI.CommandLineError>

public struct BotEngineCLI {
    
    public enum CommandLineError: Error, CustomStringConvertible {
        
        case cannotBootstrapDependencies
        case cannotStartHTTPServer
        case cannotObtainGoogleAPIAccessToken
        
        public var description: String {
            switch self {
            case .cannotBootstrapDependencies:
                return "Unable to bootstrap dependencies"
            case .cannotStartHTTPServer:
                return "Unable to start HTTP server"
            case .cannotObtainGoogleAPIAccessToken:
                return "Unable to obtain Google API OAuth access token"
            }
        }
        
        var code: Int32 {
            return Int32((self as NSError).code)
        }
        
    }
    
    public struct Configuration {
        
        public typealias ObjectRepositoryBuilder = (GoogleAPIResourceExecutor) -> ObjectRepository
        
        public struct GoogleAuth {
            
            public let scopes: [String]
            public let credentialsFilename: String
            
            public init(scopes: [String], credentialsFilename: String = "botcredentials.json") {
                self.scopes = scopes
                self.credentialsFilename = credentialsFilename
            }
            
        }
        
        public let googleAuth: GoogleAuth
        public let environment: [String : String]
        public let repositoryBuilder: ObjectRepositoryBuilder
        
        public init(
            googleAuth: GoogleAuth,
            environment: [String : String],
            repositoryBuilder: @escaping ObjectRepositoryBuilder) {
            self.googleAuth = googleAuth
            self.environment = environment
            self.repositoryBuilder = repositoryBuilder
        }
        
    }
    
    public typealias BotBuilder = (BotEngine) -> Void

    private let commands = CommandRegistry<CommandLineError>()
    
    public init(configuration: Configuration, botBuilder: @escaping BotBuilder) {
        commands.register(StartCommand(configuration: configuration, botBuilder: botBuilder))
    }
 
    public func run(with arguments: [String] = CommandLine.arguments) {
        commands.main(
            arguments: arguments,
            defaultVerb: "start",
            errorHandler: { error in
                var errorStream = StderrOutputStream()
                print("Error: \(error.description).", to: &errorStream)
                exit(error.code)
            }
        )
    }
}
