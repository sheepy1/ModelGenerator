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
            .map { (self.convertToJSON(from: $0.json), $0.modelName) }
            .map(convert)
            .subscribe(onNext: {
                self.resultText.string = $0
            })
            .addDisposableTo(bag)
    }

    func convertToJSON(from text: String) -> Any? {
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
            var key = $0.key
            if key.contains(underline) {
                let words = key.components(separatedBy: underline)
                key = ""
                words.forEach { key += $0.capitalized }
            }

            var value = $0.value
            // String
            if value is String {
                value = "\"\""
            }
            // TODO: Number(contains bool), NSNull
            if let number = value as? NSNumber, number.isBool {
                value = number.boolValue
            }
            // Object
            if let dictValue = value as? [String: Any] {
                let model = key.capitalized
                nestedModel += "\n\n// MARK: - \(model)\n\n\(convert(dictValue, to: model))"
                // Declare an optional object
                modelDefine += "\(indentation)var \(key): \(model)?\n"
            } else if let array = value as? [[String: Any]] {
                // Array
                var model = key
                if key.contains(listFlag) {
                    model = key.replacingOccurrences(of: listFlag, with: "")
                }
                if String(key.characters.last!) == pluralFlag {
                    model = String(key.characters.dropLast())
                }
                model = model.capitalized
                value = "[\(model)]()\n"
                if !array.isEmpty {
                    nestedModel += "\n\n// MARK: - \(model)\n\n\(convert(array.first, to: model))"
                }
                modelDefine += "\(indentation)var \(key): [\(model)] = []\n"
            } else {
                // Declare with initial value
                modelDefine += "\(indentation)var \(key) = \(value)\n"
            }

            modelExtension += "\(indentation)\(indentation)\(key) <- map[\"\(key)\"]\n"
        }

        modelDefine += "\n\(initFunc)\n}"
        modelExtension += "\(indentation)}\n}"
        result += "\(modelDefine)\n\n\(modelExtension)\(nestedModel)"
        return result
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
