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
    "https://www.googleapis.com/auth/spreadsheets.readonly"
]

guard let tokenProvider = BrowserTokenProvider(credentials: credentialsFilename, token: tokenFilename) else {
    fatalError("Unable to create token provider")
}

guard let token = tokenProvider.token else {
    print("Loging in ...")
    do {
        try tokenProvider.signIn(scopes: scopes)
        try tokenProvider.saveToken(tokenFilename)
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

let mapper = UniversalAbilityGroupMapper(spreadSheetName: "Universales-1-18")
AbilityScraper(abilityGroupMapper: mapper)
    .scrap(spreadSheetId: spreadsheetId, token: googleToken)
    .mapError(AnyError.init)
    .flatMap(.concat, encodeAbilities)
    .startWithResult { result in
        switch result {
        case .success(let abilities):
            if let json = String(data: abilities, encoding: .utf8) {
                print(json)
            } else {
                print("Cannot transform JSON data to String!")
            }
        case .failure(let error):
            print("Error scraping ability for spread sheet '\(spreadsheetId)':")
            print(error)
        }
        semaphore.signal()
    }

_ = semaphore.wait(timeout: DispatchTime.distantFuture)
