import SwiftSyntax
import SwiftFormat
import Foundation

struct CodegenService: Codable {
    let type: String
    let json: String
}

var snakeDecoder = JSONDecoder()
snakeDecoder.keyDecodingStrategy = .convertFromSnakeCase

let codegenData = try! Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let codegenServices = try! JSONDecoder().decode([CodegenService].self, from: codegenData)
let services = codegenServices.map { (codegen) -> Service in
    switch codegen.type {
    case "query":
        return try! snakeDecoder.decode(QueryService.self, from: codegen.json.data(using: .utf8)!)
    case "statement":
        return try! snakeDecoder.decode(StatementService.self, from: codegen.json.data(using: .utf8)!)
    default:
        fatalError()
    }
}

let sourceFile = SyntaxFactory.makeSourceFile(
    statements: SyntaxFactory.makeCodeBlockItemList(services.map { $0.generateCode() }.reduce([], +)),
    eofToken: SyntaxFactory.makeToken(.eof, presence: .present)
)

var result = ""
try! SwiftFormatter(configuration: .init(), diagnosticEngine: nil)
    .format(syntax: sourceFile, assumingFileURL: nil, to: &result)
print(result)
