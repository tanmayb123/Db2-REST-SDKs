//
//  Service.swift
//  Db2RESTNative-CodeGen-Swift
//
//  Created by Tanmay Bakshi on 2022-01-19.
//

import SwiftSyntax

protocol Service {
    var formalName: String { get }
    var formalVersion: String { get }
    
    var requestName: String { get }
    var parameters: [Parameter] { get }
    
    func generateCode() -> [CodeBlockItemSyntax]
}

extension Service {
    func generateParameterClause(withDb: Bool) -> ParameterClauseSyntax {
        var parameters: [FunctionParameterSyntax] = []
        if withDb {
            parameters.append(getDbParameter(comma: !self.parameters.isEmpty))
        }
        for (idx, parameter) in self.parameters.enumerated() {
            var paramType = parameter.sqlType.swiftType()
            if parameter.nullable {
                paramType = TypeSyntax(SyntaxFactory.makeOptionalType(
                    wrappedType: paramType,
                    questionMark: SyntaxFactory.makeInfixQuestionMarkToken()
                ))
            }
            let parameter = SyntaxFactory.makeFunctionParameter(
                attributes: nil,
                firstName: SyntaxFactory.makeIdentifier(parameter.name),
                secondName: nil,
                colon: SyntaxFactory.makeColonToken(),
                type: paramType, ellipsis: nil, defaultArgument: nil,
                trailingComma: idx == (self.parameters.count - 1) ? nil : SyntaxFactory.makeCommaToken()
            )
            parameters.append(parameter)
        }
        
        return SyntaxFactory.makeParameterClause(
            leftParen: SyntaxFactory.makeLeftParenToken(),
            parameterList: SyntaxFactory.makeFunctionParameterList(parameters),
            rightParen: SyntaxFactory.makeRightParenToken()
        )
    }
    
    func generateParameterElementList() -> TupleExprElementListSyntax {
        SyntaxFactory.makeTupleExprElementList(parameters.enumerated().map { (idx, parameter) in
            SyntaxFactory.makeTupleExprElement(
                label: SyntaxFactory.makeIdentifier(parameter.name),
                colon: SyntaxFactory.makeColonToken(),
                expression: ExprSyntax(SyntaxFactory.makeIdentifierExpr(
                    identifier: SyntaxFactory.makeIdentifier(parameter.name),
                    declNameArguments: nil
                )),
                trailingComma: idx == (self.parameters.count - 1) ? nil : SyntaxFactory.makeCommaToken()
            )
        })
    }
    
    func generateParameterConversionCode() -> [CodeBlockItemSyntax] {
        var codeComponents = parameters.map { parameter in
            Syntax(SyntaxFactory.makeVariableDecl(
                attributes: nil,
                modifiers: nil,
                letOrVarKeyword: SyntaxFactory.makeLetKeyword(),
                bindings: SyntaxFactory.makePatternBindingList([
                    SyntaxFactory.makePatternBinding(
                        pattern: PatternSyntax(SyntaxFactory.makeIdentifierPattern(
                            identifier: SyntaxFactory.makeIdentifier(parameter.name)
                        )),
                        typeAnnotation: SyntaxFactory.makeTypeAnnotation(
                            colon: SyntaxFactory.makeColonToken(),
                            type: parameter.swiftType(kind: .json)
                        ),
                        initializer: SyntaxFactory.makeInitializerClause(
                            equal: SyntaxFactory.makeEqualToken(),
                            value: ExprSyntax(parameter.converterFunctionCall(withSelf: false))
                        ),
                        accessor: nil,
                        trailingComma: nil
                    )
                ])
            ))
        }
        codeComponents.append(
            Syntax(SyntaxFactory.makeVariableDecl(
                attributes: nil,
                modifiers: nil,
                letOrVarKeyword: SyntaxFactory.makeLetKeyword(),
                bindings: SyntaxFactory.makePatternBindingList([
                    SyntaxFactory.makePatternBinding(
                        pattern: PatternSyntax(SyntaxFactory.makeIdentifierPattern(
                            identifier: SyntaxFactory.makeIdentifier("parameters")
                        )),
                        typeAnnotation: SyntaxFactory.makeTypeAnnotation(
                            colon: SyntaxFactory.makeColonToken(),
                            type: getParametersDictionaryType()
                        ),
                        initializer: SyntaxFactory.makeInitializerClause(
                            equal: SyntaxFactory.makeEqualToken(),
                            value: ExprSyntax(SyntaxFactory.makeDictionaryExpr(
                                leftSquare: SyntaxFactory.makeLeftSquareBracketToken(),
                                content: self.parameters.isEmpty ? Syntax(SyntaxFactory.makeColonToken()) : Syntax(SyntaxFactory.makeDictionaryElementList(parameters.enumerated().map { (idx, parameter) in
                                    SyntaxFactory.makeDictionaryElement(
                                        keyExpression: ExprSyntax(SyntaxFactory.makeStringLiteralExpr(parameter.formalName)),
                                        colon: SyntaxFactory.makeColonToken(),
                                        valueExpression: ExprSyntax(SyntaxFactory.makeVariableExpr(parameter.name)),
                                        trailingComma: idx == (parameters.count - 1) ? nil : SyntaxFactory.makeCommaToken()
                                    )
                                })),
                                rightSquare: SyntaxFactory.makeRightSquareBracketToken()
                            ))
                        ),
                        accessor: nil,
                        trailingComma: nil
                    )
                ])
            ))
        )
        codeComponents.append(
            Syntax(SyntaxFactory.makeReturnStmt(
                returnKeyword: SyntaxFactory.makeReturnKeyword(),
                expression: ExprSyntax(SyntaxFactory.makeVariableExpr("parameters"))
            ))
        )
        return codeComponents.map { decl in
            SyntaxFactory.makeCodeBlockItem(
                item: decl,
                semicolon: nil,
                errorTokens: nil
            )
        }
    }
    
    func generateParametersFunction() -> FunctionDeclSyntax {
        SyntaxFactory.makeFunctionDecl(
            attributes: nil,
            modifiers: nil,
            funcKeyword: SyntaxFactory.makeFuncKeyword(),
            identifier: SyntaxFactory.makeIdentifier("\(requestName)_paramConversion"),
            genericParameterClause: nil,
            signature: SyntaxFactory.makeFunctionSignature(
                input: generateParameterClause(withDb: false),
                asyncOrReasyncKeyword: nil,
                throwsOrRethrowsKeyword: nil,
                output: SyntaxFactory.makeReturnClause(
                    arrow: SyntaxFactory.makeArrowToken(),
                    returnType: getParametersDictionaryType()
                )
            ),
            genericWhereClause: nil,
            body: SyntaxFactory.makeCodeBlock(
                leftBrace: SyntaxFactory.makeLeftBraceToken(),
                statements: SyntaxFactory.makeCodeBlockItemList(generateParameterConversionCode()),
                rightBrace: SyntaxFactory.makeRightBraceToken()
            )
        )
    }
}
