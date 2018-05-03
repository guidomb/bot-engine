import Foundation
import OAuth2
import FeebiKit
import ReactiveSwift
import Result

extension Token {
    
    var asGoogleToken: GoogleAPI.Token? {
        guard let tokenType = self.TokenType, let tokenValue = self.AccessToken else {
            return nil
        }
        return GoogleAPI.Token(type: tokenType, value: tokenValue)
    }
    
}

func encodeAbilities(_ abilities: [Ability]) -> SignalProducer<Data, AnyError> {
    return SignalProducer {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(abilities)
    }
}

let tokenFilename = ".feebi-token"
let credentialsFilename = "feebi.json"
let scopes = [
    "https://www.googleapis.com/auth/spreadsheets.readonly",
    "https://www.googleapis.com/auth/forms"
]

guard let tokenProvider = BrowserTokenProvider(credentials: credentialsFilename, token: tokenFilename) else {
    fatalError("Unable to create token provider")
}

guard let token = tokenProvider.token else {
    print("Loging in ...")
    do {
        try tokenProvider.signIn(scopes: scopes)
        try tokenProvider.saveToken(tokenFilename)
        print(tokenProvider.token?.AccessToken ?? "")
    } catch let error {
        print(error)
        exit(1)
    }
    exit(0)
}

let spreadsheetId = "1AFGIF5oSiCfJ6UspooxuxBfCQ7Zyfqbbd3ltjZidqzk"
guard let range = SpreadSheetRange(from: "'Performance-1-18'!B25:K26") else {
    print("Error: Invalid spread sheet range")
    exit(1)
}
guard let googleToken = token.asGoogleToken else {
    print("Error: Cannot create GoogleAPI.Token")
    exit(1)
}

let semaphore = DispatchSemaphore(value: 0)

GoogleAPI.shared.printDebugCurlCommand = true
GoogleAPI.shared.printRequest = true

func render(choice: Form.ChoiceItem, index: Int) {
    print("\t\t\(index + 1) - \(choice.value)")
}

func render(formItem item: Form.Item, index: Int) {
    print("\tQ\(index + 1 ): [\(item.isRequired ? "required" : "optional")] \(item.title) - \(item.itemType.key)")
    switch item.itemType {
    case .text, .paragraphText, .date, .dateTime:
        break
    case .list(_, let choices):
        choices.enumerated().forEach { render(choice: $0.1, index: $0.0) }
    case .multipleChoice(_, let choices):
        choices.enumerated().forEach { render(choice: $0.1, index: $0.0) }
    case .checkbox(_, let choices):
        choices.enumerated().forEach { render(choice: $0.1, index: $0.0) }
    }
}

GoogleAPI.forms(usingScript: "MVbVyOJOsJhw-DI-J2sAJjzv1HmwoNCeA", devMode: true)
    .fetchForm(byId: "1mlteVfq46HlO4VPR4LQjUKAqGS8f8fE7AtqWapqoM3w")
    .execute(using: googleToken)
    .startWithResult { result in
        switch result {
        case .success(let form):
            print("Title: \(form.title)")
            for (index, item) in form.supportedItems.enumerated() {
                render(formItem: item, index: index)
            }
        case .failure(let error):
            print("Error fetching form : ")
            print(error)
        }
        semaphore.signal()
    }

//let mapper = UniversalAbilityGroupMapper(spreadSheetName: "Universales-1-18")
//AbilityScraper(abilityGroupMapper: mapper)
//    .scrap(spreadSheetId: spreadsheetId, token: googleToken)
//    .mapError(AnyError.init)
//    .flatMap(.concat, encodeAbilities)
//    .startWithResult { result in
//        switch result {
//        case .success(let abilities):
//            if let json = String(data: abilities, encoding: .utf8) {
//                print(json)
//            } else {
//                print("Cannot transform JSON data to String!")
//            }
//        case .failure(let error):
//            print("Error scraping ability for spread sheet '\(spreadsheetId)':")
//            print(error)
//        }
//        semaphore.signal()
//    }

_ = semaphore.wait(timeout: DispatchTime.distantFuture)
