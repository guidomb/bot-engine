//
//  SpreadSheetsService.swift
//  AuthPackageDescription
//
//  Created by Guido Marucci Blas on 3/31/18.
//

import Foundation
import ReactiveSwift
import Result

public protocol SpreadSheetsService {
    
    func getValues(spreadSheetId: String, range: SpreadSheetRange,
                   options: GetValuesOptions) -> GoogleAPIResource.ResourceProducer<ValueRange>
    
}

public struct GoogleSpreadSheetsService: SpreadSheetsService {
    
    private let token: GoogleAPIResource.Token
    
    public init(token: GoogleAPIResource.Token) {
        self.token = token
    }
    
    public func getValues(spreadSheetId: String, range: SpreadSheetRange,
                          options: GetValuesOptions) -> GoogleAPIResource.ResourceProducer<ValueRange> {
        let resource = SpreadSheetsResource.values(
            spreadSheetId: spreadSheetId,
            method: .get(range: range, options: options)
        )
        return GoogleAPIResource.shared.execute(resource: resource, token: token)
    }
    
}
