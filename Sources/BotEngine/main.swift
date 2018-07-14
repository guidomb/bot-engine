import Foundation
import Commandant

let commands = CommandRegistry<CommandLineError>()
commands.register(StartCommand())

commands.main(
    arguments: CommandLine.arguments,
    defaultVerb: "start",
    errorHandler: { error in
        var errorStream = StderrOutputStream()
        print("Error: \(error.description).", to: &errorStream)
        exit(error.code)
    }
)

