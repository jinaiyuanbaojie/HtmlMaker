//
//  main.swift
//  htmlmaker
//
//  Created by jinaiyuan on 2018/9/20.
//  Copyright © 2018年 jinaiyuan. All rights reserved.
//

import Foundation
import WCDBSwift

class AppInfo: TableCodable {
    var identifier: Int? = nil
    var version: String? = nil
    var date: Date? = nil
    var platform: String? = nil
    var link: String? = nil
    
    func formatDateString() -> String {
        guard let current = date else {
            return "1970-01-01 00:00:00"
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY-MM-dd HH:mm:ss"
        return dateFormatter.string(from: current)
    }
    
    func downloadLink() -> String {
        guard let currentLink = link else {
            return "nil link"
        }
        
        if platform == "iOS" {
            return "itms-services://?action=download-manifest&url=\(currentLink)"
        }
        
        if platform == "Android" {
            return currentLink
        }
        
        return "Miss platform info"
    }

    enum CodingKeys: String, CodingTableKey {
        typealias Root = AppInfo
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        case identifier
        case version
        case date
        case platform
        case link
        
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                identifier: ColumnConstraintBinding(isPrimary: true, isAutoIncrement: true),
            ]
        }
    }
}

func getAppInfoArray(database: Database, tableName: String, platform: String) -> [AppInfo] {
    let maxNumberOfItems = 10
    return try! database.getObjects(on: AppInfo.Properties.all, fromTable: tableName, where: AppInfo.Properties.platform == platform, orderBy: [AppInfo.Properties.date.asOrder(by: .descending)], limit: maxNumberOfItems, offset: nil)
}

// MARK: - read input
let arguments = CommandLine.arguments
assert(arguments.count == 4)
let appInfo = AppInfo()
appInfo.platform = arguments[1]
appInfo.version = arguments[2]
appInfo.link = arguments[3]
appInfo.date = Date()

// MARK: - WCDB
let databasePath = "/Users/jinaiyuan/Documents/MyProject/iOS/HtmlMaker/hcc_app.db"
let database = Database(withPath: databasePath)
let tableName = "smt_table"
try database.create(table: tableName, of: AppInfo.self)
try database.insert(objects: appInfo, intoTable: tableName)
let appInfoArray: [AppInfo] = getAppInfoArray(database: database, tableName: tableName, platform: appInfo.platform!)

// MARK: - text replace
let htmlSinppet = "<div class=\"container\"><div class=\"item\">$VERSION</div><div class=\"item\">$DATE</div><a class=\"item\" href=\"$LINK\">Download</a></div>"
let replaceString = appInfoArray.reduce("") { (lastResult: String, appInfo: AppInfo) -> String in
    let currentReplaceString = htmlSinppet.replacingOccurrences(of: "$VERSION", with: (appInfo.version ?? "undefined")).replacingOccurrences(of: "$DATE", with: appInfo.formatDateString()).replacingOccurrences(of: "$LINK", with: appInfo.downloadLink())
    return lastResult + currentReplaceString;
}
let sourceHtmlPath = "/Users/jinaiyuan/Documents/MyProject/iOS/HtmlMaker/index.html"
let sourceHtmlString = try String(contentsOfFile: sourceHtmlPath)
let targetHtmlString = sourceHtmlString.replacingOccurrences(of: "<!--Replace-->", with: replaceString)

// MARK: - output
let outputName = "smt_\(appInfo.platform ?? "error")_uat.html"
let outputDirectory = "/Users/jinaiyuan/Documents/MyProject/iOS/HtmlMaker/"
let outputPath = outputDirectory + outputName
if FileManager.default.fileExists(atPath: outputPath) {
    try FileManager.default.removeItem(atPath: outputPath)
}
FileManager.default.createFile(atPath: outputPath, contents: targetHtmlString.data(using: .utf8), attributes: nil)
