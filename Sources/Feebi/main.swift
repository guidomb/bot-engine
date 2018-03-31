import Foundation
import OAuth2
import FeebiKit

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
    print("Invalid spread sheet range")
    exit(1)
}
let service = GoogleSpreadSheetsService(token: GoogleAPIResource.Token(type: token.TokenType!, value: token.AccessToken!))
let semaphore = DispatchSemaphore(value: 0)
service.getValues(
    spreadSheetId: spreadsheetId,
    range: range,
    options: GetValuesOptions(majorDimension: .rows)).startWithResult { result in
        switch result {
        case .success(let response):
            print(response.values)
        case .failure(let error):
            print("Get values for spread sheet with ID '\(spreadsheetId)' failed.")
            print(error)
        }
        semaphore.signal()
}
_ = semaphore.wait(timeout: DispatchTime.distantFuture)
