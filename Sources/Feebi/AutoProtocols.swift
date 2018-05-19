//
//  AutoProtocols.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/20/18.
//

import Foundation

protocol AutoDecodable: Decodable {}
protocol AutoEncodable: Encodable {}
protocol AutoCodable: AutoDecodable, AutoEncodable {}
