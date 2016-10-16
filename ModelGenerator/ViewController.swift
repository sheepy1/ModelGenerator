//
//  ViewController.swift
//  ModelGenerator
//
//  Created by 杨洋 on 10/5/16.
//  Copyright © 2016 Sheepy. All rights reserved.
//

import Cocoa
import RxCocoa
import RxSwift

private let listFlag = "List"
private let pluralFlag = "s"
private let underline = "_"
private let indentation = "    "

class ViewController: NSViewController {

    @IBOutlet weak var modelNameText: NSTextField!
    @IBOutlet var sourceText: NSTextView!
    @IBOutlet var resultText: NSTextView!

    let bag = DisposeBag()
    let source = PublishSubject<String>()
    let modelName = PublishSubject<String>()

    override func viewDidLoad() {
        super.viewDidLoad()
        disableSmartQuotes()
        parse()
    }
}

private extension ViewController {

    func disableSmartQuotes() {
        sourceText.isAutomaticQuoteSubstitutionEnabled = false
        resultText.isAutomaticQuoteSubstitutionEnabled = false
    }

    func parse() {
        Observable
            .combineLatest(source, modelName) { (json: $0.0, modelName: $0.1) }
            .map { (self.json(with: $0.json), $0.modelName) }
            .map(convert)
            .subscribe(onNext: {
                self.resultText.string = $0
            })
            .addDisposableTo(bag)
    }

    func json(with text: String) -> Any? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: [])
    }

    func convert(_ json: Any?, to model: String) -> String {
        guard let dict = json as? [String: Any] else { return "Please format your input as JSON ：）" }

        var result = ""
        var nestedModel = ""
        let initFunc = "\(indentation)init?(_ map: Map) {}"
        var modelDefine = "struct \(model) {\n"
        var modelExtension = "extension \(model): Mappable {\n"
        modelExtension += "\(indentation)mutating func mapping(map: Map) {\n"

        dict.forEach {
            let variableName = normalizeVariableName(key: $0.key)
            let value = $0.value

            switch value {
            case is String:

                modelDefine += "\(indentation)var \(variableName) = \"\"\n"

            case let number as NSNumber:

                if number.isBool {
                    modelDefine += "\(indentation)var \(variableName) = false\n"
                } else {
                    modelDefine += "\(indentation)var \(variableName) = 0\n"
                }

            case let dict as [String: Any]:

                let model = variableName.capitalized
                nestedModel += "\n\n// MARK: - \(model)\n\n\(convert(dict, to: model))"
                // Declare an optional object
                modelDefine += "\(indentation)var \(variableName): \(model)?\n"

            case let array as [Any]:

                var type = "Any"
                if let element = array.first {
                    switch element {
                    case is String:
                        type = "String"
                    case let number as NSNumber:
                        if number.isBool {
                            type = "Bool"
                        } else {
                            type = "Int"
                        }
                    case let dict as [String: Any]:
                        type = normalizeArrayElement(variableName: variableName)
                        nestedModel += "\n\n// MARK: - \(type)\n\n\(convert(dict, to: type))"
                    default:
                        break
                    }
                }
                // Declare an array
                modelDefine += "\(indentation)var \(variableName): [\(type)] = []\n"

            default:
                // If value is NSNull or whatever
                modelDefine += "\(indentation)var \(variableName): Any?\n"
            }

            modelExtension += "\(indentation)\(indentation)\(variableName) <- map[\"\($0.key)\"]\n"
        }

        modelDefine += "\n\(initFunc)\n}"
        modelExtension += "\(indentation)}\n}"
        result += "\(modelDefine)\n\n\(modelExtension)\(nestedModel)"
        return result
    }

    func normalizeVariableName(key: String) -> String {
        var name = key
        if name.contains(underline) {
            var words = name.components(separatedBy: underline)
            name = words.removeFirst()
            words.forEach { name += $0.capitalized }
        }
        return name
    }

    func normalizeArrayElement(variableName: String) -> String {
        var model = variableName
        if variableName.contains(listFlag) {
            model = variableName.replacingOccurrences(of: listFlag, with: "")
        }
        if String(variableName.characters.last!) == pluralFlag {
            model = String(variableName.characters.dropLast())
        }
        return model.capitalized
    }
}

extension ViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        source.onNext(sourceText.string ?? "")
    }
}

extension ViewController: NSTextFieldDelegate {
    override func controlTextDidChange(_ obj: Notification) {
        let model = modelNameText.stringValue.isEmpty ? "Model" : modelNameText.stringValue
        modelName.onNext(model)
    }
}

