//
//  Spreadsheets.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 3/30/18.
//

import Foundation
import ReactiveSwift
import Result

public extension GoogleAPI {
    
    public struct SpreadSheets {
        
        static let rootPath = "spreadsheets"
        
        static let shared = SpreadSheets()
        
        private let baseURL = "https://sheets.googleapis.com"
        private let version = "v4"
        
        private var basePath: String {
            return "\(baseURL)/\(version)/spreadsheets"
        }
        
        private init() {}
        
        public struct Values {
            
            private let basePath: String
            
            fileprivate init(basePath: String) {
                self.basePath = basePath
            }
            
            // https://developers.google.com/sheets/api/reference/rest/v4/spreadsheets.values/get
            public func get(range: SpreadSheetRange, options: GetValuesOptions) -> Resource<ValueRange> {
                return Resource(path: "\(basePath)/\(range.urlEncoded)", queryParameters: options, method: .get)
            }
            
            public func get(range: SpreadSheetRange, majorDimension: SpreadSheet.Dimension) -> Resource<ValueRange> {
                return get(range: range, options: GetValuesOptions(majorDimension: majorDimension))
            }
            
            // https://developers.google.com/sheets/api/reference/rest/v4/spreadsheets.values/batchGet
            public func batchGet(ranges: [SpreadSheetRange], options: GetValuesOptions) -> Resource<BatchValueRange> {
                return Resource(
                    path: "\(basePath):batchGet",
                    queryParameters: "\(ranges.makeQueryString(withKey: "ranges"))&\(options.asQueryString)",
                    method: .get
                )
            }
            
            public func batchGet(ranges: [SpreadSheetRange], majorDimension: SpreadSheet.Dimension) -> Resource<BatchValueRange>{
                return batchGet(ranges: ranges, options: GetValuesOptions(majorDimension: majorDimension))
            }
            
        }
        
        public func values(spreadSheetId: String) -> Values {
            return Values(basePath: resourceBasePath(resource: "values", spreadSheetId: spreadSheetId))
        }
        
        // https://developers.google.com/sheets/api/reference/rest/v4/spreadsheets/get
        public func get(spreadSheetId: String, ranges: [SpreadSheetRange] = [],
                        includeGridData: Bool = false) -> Resource<SpreadSheet> {
            return Resource(
                path: resourceBasePath(resource: "get", spreadSheetId: spreadSheetId),
                queryParameters: "\(ranges.makeQueryString(withKey: "ranges"))&includeGridData=\(includeGridData)"
            )
        }
        
    }
    
    public static var spreadSheets: SpreadSheets { return .shared }
    
}

fileprivate extension GoogleAPI.SpreadSheets {
    
    func resourceBasePath(resource: String, spreadSheetId: String) -> String {
        return "\(basePath)/\(spreadSheetId)/\(resource)"
    }
    
}

// MARK: - Data models

public struct SpreadSheet: Decodable {
    
    public enum Dimension: String, Decodable {
        
        case rows = "ROWS"
        case columns = "COLUMNS"
        case unspecified = "DIMENSION_UNSPECIFIED"
        
    }
    
    public struct DimensionRange: Decodable {
        
        public let sheetId: Double
        public let dimension: Dimension
        public let startIndex: Double
        public let endIndex: Double
        
    }
    
    public struct DimensionProperties: Decodable {
        
        public let hiddenByFilter: Bool
        public let hiddenByUser: Bool
        public let pixelSize: Double
        public let developerMetadata: [DeveloperMetadata]
        
    }
    
    public struct DeveloperMetadata: Decodable {
        
        public enum Visibility: String, Decodable {
            
            case unspecified = "DEVELOPER_METADATA_VISIBILITY_UNSPECIFIED"
            case document = "DOCUMENT"
            case project = "PROJECT"
            
        }
        
        public struct Location: Decodable {
            
            public enum LocationType: String, Decodable {
                
                case unspecified = "DEVELOPER_METADATA_LOCATION_TYPE_UNSPECIFIED"
                case row = "ROW"
                case column = "COLUMN"
                case sheet = "SHEET"
                case spreadSheet = "SPREADSHEET"
                
            }
            
            public enum Value: Decodable {
                
                enum CodingKeys: String, CodingKey {
                    
                    case spreadsheet
                    case sheetId
                    case dimensionRange
                    
                }
                
                public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    if let spreadsheet = try container.decodeIfPresent(Bool.self, forKey: .spreadsheet) {
                        self = .spreadsheet(spreadsheet)
                    } else if let sheetid = try container.decodeIfPresent(Double.self, forKey: .sheetId) {
                        self = .sheetId(sheetid)
                    } else {
                        self = .dimensionRange(try container.decode(DimensionRange.self, forKey: .dimensionRange))
                    }
                }
                
                case spreadsheet(Bool)
                case sheetId(Double)
                case dimensionRange(DimensionRange)
                
            }
            
            public let locationType: LocationType
            public let value: Value
            
        }
        
        public let metadataId: Double
        public let metadataKey: String
        public let metadataValue: String
        public let location: Location
        public let visibility: Visibility
        
    }
    
    public struct Properties: Decodable {
        
        public enum RecalculationInterval: String, Decodable {
            
            case unspecified    = "RECALCULATION_INTERVAL_UNSPECIFIED"
            case onChange       = "ON_CHANGE"
            case minute         = "MINUTE"
            case hour           = "HOUR"
            
        }
        
        public struct IterativeCalculationSettings: Decodable {
            
            public let maxIterations: Double
            public let convergenceThreshold: Double
            
        }
        
        public let title: String
        public let locale: String
        public let autoRecalc: RecalculationInterval
        public let defaultFormat: CellFormat
        public let iterativeCalculationSettings: IterativeCalculationSettings
        
    }
    
    public struct TextFormat: Decodable {
        
        public let foregroundColor: Color
        public let fontFamily: String
        public let fontSize: Double
        public let bold: Bool
        public let italic: Bool
        public let strikethrough: Bool
        public let underline: Bool
        
    }
    
    public struct CellFormat: Decodable {
        
        public struct NumberFormat: Decodable {
            
            public enum NumberFormatType: String, Decodable {
                
                case unspecified = "NUMBER_FORMAT_TYPE_UNSPECIFIED"
                case text = "TEXT"
                case number = "NUMBER"
                case percent = "PERCENT"
                case currency = "CURRENCY"
                case date = "DATE"
                case time = "TIME"
                case dateTime = "DATE_TIME"
                case scientific = "SCIENTIFIC"
                
            }
            
            public let type: String
            public let pattern: String
            
        }
        
        public struct Borders: Decodable {
            
            public let top: Border
            public let botton: Border
            public let left: Border
            public let right: Border
            
        }
        
        public struct Border: Decodable {
            
            public enum Style: String, Decodable {
                
                case unspecified = "STYLE_UNSPECIFIED"
                case dotted = "DOTTED"
                case dashed = "DASHED"
                case solid = "SOLID"
                case solidMedium = "SOLID_MEDIUM"
                case solidThick = "SOLID_THICK"
                case none = "NONE"
                case double = "DOUBLE"
                
            }
            
            public let style: Style
            public let color: Color
            
        }
        
        public struct Padding: Decodable {
            
            public let top: Double
            public let botton: Double
            public let left: Double
            public let right: Double
            
        }
        
        public enum HorizontalAlign: String, Decodable {
            
            case unspecified = "HORIZONTAL_ALIGN_UNSPECIFIED"
            case left = "LEFT"
            case center = "CENTER"
            case right = "RIGHT"
            
        }
        
        public enum VerticalAlign: String, Decodable {
            
            case unspecified = "VERTICAL_ALIGN_UNSPECIFIED"
            case top = "TOP"
            case middle = "MIDDLE"
            case bottom = "BOTTOM"
            
        }
        
        public enum WrapStrategy: String, Decodable {
            
            case unspecified = "WRAP_STRATEGY_UNSPECIFIED"
            case overflowCell = "OVERFLOW_CELL"
            case legacyWrap = "LEGACY_WRAP"
            case clip = "CLIP"
            case wrap = "WRAP"
            
        }
        
        public enum TextDirection: String, Decodable {
            
            case unspecified = "TEXT_DIRECTION_UNSPECIFIED"
            case leftToRight = "LEFT_TO_RIGHT"
            case rightToLeft = "RIGHT_TO_LEFT"
            
        }
        
        public enum HyperlinkDisplayType: String, Decodable {
            
            case unspecified = "HYPERLINK_DISPLAY_TYPE_UNSPECIFIED"
            case linked = "LINKED"
            case plainText = "PLAIN_TEXT"
            
        }
        
        public enum TextRotation: Decodable {
            
            enum CodingKeys: String, CodingKey {
                
                case angle
                case vertical
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                if let angle = try container.decodeIfPresent(Double.self, forKey: .angle) {
                    self = .angle(angle)
                } else {
                    self = .vertical(try container.decode(Bool.self, forKey: .vertical))
                }
            }
            
            
            case angle(Double)
            case vertical(Bool)
            
        }
        
        public let numberFormat: NumberFormat
        public let backgroundColor: Color
        public let borders: Borders
        public let padding: Padding
        public let horizontalAlignment: HorizontalAlign
        public let verticalAlignment: VerticalAlign
        public let wrapStrategy: WrapStrategy
        public let textDirection: TextDirection
        public let textFormat: TextFormat
        public let hyperlinkDisplayType: HyperlinkDisplayType
        public let textRotation: TextRotation
        
    }
    
    public struct NamedRange: Decodable {
        
        public let nameRangedId: String
        public let name: String
        public let range: GridRange
        
    }
    
    public struct GridRange: Decodable {
        
        public let sheetId: Double
        public let startRowIndex: Double
        public let endRowIndex: Double
        public let startColumnIndex: Double
        public let endColumnIndex: Double
        
    }
    
    public struct GridProperties: Decodable {
        
        public let rowCount: Double
        public let columnCount: Double
        public let frozenRowCount: Double
        public let frozenColumnCount: Double
        public let hideGridlines: Bool
        
    }
    
    public struct GridData: Decodable {
        
        public let startRow: Double
        public let startColumn: Double
        public let rowData: [RowData]
        public let rowMetadata: [DimensionProperties]
        public let columnMetadata: [DimensionProperties]
        
    }
    
    public struct RowData: Decodable {
        
        public let values: [CellData]
        
    }
    
    public struct CellData: Decodable {
        
        public enum ExtendedValue: Decodable {
        
            public struct ErrorValue: Decodable {
                
                public enum ErrorType: String, Decodable {
                    
                    case unspecified = "ERROR_TYPE_UNSPECIFIED"
                    case error = "ERROR"
                    case nullValue = "NULL_VALUE"
                    case divideByZero = "DIVIDE_BY_ZERO"
                    case value = "VALUE"
                    case ref = "REF"
                    case name = "NAME"
                    case num = "NUM"
                    case nA = "N_A"
                    case loading = "LOADING"
                    
                }
                
                public let type: ErrorType
                public let message: String
                
            }
            
            enum CodingKeys: String, CodingKey {
                
                case numberValue
                case stringValue
                case boolValue
                case formulaValue
                case errorValue
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                if let number = try container.decodeIfPresent(Double.self, forKey: .numberValue) {
                    self = .number(number)
                } else if let string = try container.decodeIfPresent(String.self, forKey: .stringValue) {
                    self = .string(string)
                } else if let bool = try container.decodeIfPresent(Bool.self, forKey: .boolValue) {
                    self = .bool(bool)
                } else if let formula = try container.decodeIfPresent(String.self, forKey: .formulaValue) {
                    self = .formula(formula)
                } else {
                    self = .error(try container.decode(ErrorValue.self, forKey: .errorValue))
                }
            }
            
            case number(Double)
            case string(String)
            case bool(Bool)
            case formula(String)
            case error(ErrorValue)
            
        }
        
        public struct TextFormatRun: Decodable {
            
            public let startIndex: Int
            public let format: TextFormat
            
        }
        
//        public struct DataValidationRule: Decodable {
//            
//            public struct BooleanCondition {
//                
//                public enum ConditionType: String, Decodable {
//                    
//                    case unspecified = "CONDITION_TYPE_UNSPECIFIED"
//                
//                }
//                
//                enum CondingKeys: String, CodingKey {
//                    
//                    case conditionType = "type"
//                    case values = "values"
//                    
//                }
//                
//                public let conditionType: ConditionType
//                public let values: [ConditionValue]
//                
//            }
//            
//            public let condition: BooleanCondition
//            public let inputMessage: String
//            public let strict: Bool
//            public let showCustomUi: Bool
//            
//        }
        
        public let userEnteredValue: ExtendedValue
        public let effectiveValue: ExtendedValue
        public let formattedValue: String
        public let userEnteredFormat: CellFormat
        public let effectiveFormat: CellFormat
        public let hyperlink: String
        public let note: String
        public let textFormatRuns: [TextFormatRun]
//        public let dataValidation: DataValidationRule
//        public let pivotTable: PivotTable
        
    }
    
    public struct Color: Decodable {
        
        public let red: Double
        public let blue: Double
        public let green: Double
        public let alpha: Double
        
    }
    
    public struct Sheet: Decodable {
        
        public enum SheetType: String, Decodable {
            
            case unspecified = "SHEET_TYPE_UNSPECIFIED"
            case grid = "GRID"
            case object = "OBJECT"
            
        }

        public struct Properties: Decodable {
            
            
            let sheetId: Double
            let title: String
            let index: Double
            let sheetType: SheetType
            let gridProperties: GridProperties
            let hidden: Bool
            let tabColor: Color
            let rightToLeft: Bool
            
        }
        
        public let properties: Properties
        public let data: [GridData]
//        public let merges: [GridRange]
//        public let conditionalFormats: [ConditionalFormatRule]
//        public let filterViews: [FilterView]
//        public let protectedRanges: [ProtectedRange]
//        public let basicFilter: BasicFilter
//        public let charts: [EmbeddedChart]
//        public let bandedRanges: [BandedRange]
        public let developerMetadata: [DeveloperMetadata]
        
    }
    
    public let spreadsheetId: String
    public let properties: Properties
    public let sheets: [Sheet]
    public let namedRanges: [NamedRange]
    public let spreadsheetUrl: URL
    public let developerMetadata: [DeveloperMetadata]
    
}

public enum ValueRenderOption: String {
    
    case formattedValue = "FORMATTED_VALUE"
    case unformattedValue = "UNFORMATTED_VALUE"
    case formula = "FORMULA"
    
}

public enum DateTimeRenderOption: String {
    
    case serialNumber = "SERIAL_NUMBER"
    case formattedString = "FORMATTED_STRING"
    
}

public struct ValueRange: Decodable {
    
    public let range: String
    public let majorDimension: SpreadSheet.Dimension
    public let values: [[String]]
}

public struct BatchValueRange: Decodable {
    
    public let spreadsheetId: String
    public let valueRanges: [ValueRange]
    
    var count: Int {
        return valueRanges.count
    }
    
    subscript(index: Int) -> [[String]] {
        return self.valueRanges[index].values
    }
    
}

public struct GetValuesOptions {
    
    public let majorDimension: SpreadSheet.Dimension
    public let valueRenderOption: ValueRenderOption
    public let dateTimeRenderOption: DateTimeRenderOption
    
    public init(
        majorDimension: SpreadSheet.Dimension,
        valueRenderOption: ValueRenderOption = .formattedValue,
        dateTimeRenderOption: DateTimeRenderOption = .serialNumber) {
        self.majorDimension = majorDimension
        self.valueRenderOption = valueRenderOption
        self.dateTimeRenderOption = dateTimeRenderOption
    }
    
}

extension GetValuesOptions: QueryStringConvertible {
    
    public var asQueryString: String {
        return  "majorDimension=\(majorDimension)"              +
                "&valueRenderOption=\(valueRenderOption.rawValue)" +
                "&dateTimeRenderOption=\(dateTimeRenderOption.rawValue)"
    }
    
}

extension SpreadSheetRange {
    
    var urlEncoded: String {
        return self.description.urlEncoded
    }
    
}
