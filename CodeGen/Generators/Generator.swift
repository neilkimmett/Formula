//
// Created by Rheese Burgess on 15/03/2016.
// Copyright (c) 2016 Momentumworks. All rights reserved.
//

import Foundation
import SourceKittenFramework
import Stencil
import PathKit

public typealias GeneratedFunction = String

public protocol Generator {
  func filter(object: Type) -> Bool
  func generateFor(filteredObjects: [Type]) -> [Name: [GeneratedFunction]]
}

class CodeGenerator {
  static let Warning = "// THIS FILE HAS BEEN AUTO GENERATED AND MUST NOT BE ALTERED DIRECTLY\n"

  let templates: [Template]
  let infoHeader: String

  init(templates: [Template], infoHeader: String? = CodeGenerator.Warning) {
    self.templates = templates
    self.infoHeader = infoHeader ?? ""
  }

  func generateForFiles(files: [File]) -> String {
    let types = Extractor.extractTypes(files).values.map(StencilType.init).sort(sortByName)
    let imports = Extractor.extractImports(files).sort()
    
    let extensions = types
      .splitBy { $0.extensions }
      .mapValues { $0.sort(sortByName) }

    let context = Context(dictionary: [
        "types": types,
        "structs": types.filter { $0.isStruct },
        "enums" : types.filter { $0.isEnum },
        "classes" : types.filter { $0.isClass },
        "extensions": extensions
    ])

    let namespace = Namespace()
    namespace.registerSimpleTag("comma", handler: { context in
      guard let last = (context["forloop"] as? [String: Any])?["last"] as? Bool else {
        return ""
      }
      return last ? "" : ", "
    })
    
    namespace.registerSimpleTag("andSymbol", handler: { context in
      guard let last = (context["forloop"] as? [String: Any])?["last"] as? Bool else {
        return ""
      }
      return last ? "" : "&& "
    })
    
    let generated = templates.reduce("") { accumulated, template in
      do {
        let result = try template.render(context, namespace: namespace)
        
        return accumulated + result
      } catch {
        print("Failed to render template \(error)")
        return accumulated
      }
    }

    var header = infoHeader + imports.map { "import \($0)" }.joinWithSeparator("\n")
    
    if !header.isEmpty {
        header += "\n"
    }
    return header + generated.trimWithNewLines()
}

  func generateForDirectory(directory: String) -> String {
    let filePaths = Utils.fullPathForAllFilesAt(directory, withExtension: "swift", ignoreSubdirectory: GeneratedCodeDirectory)
    let files = filePaths.map { File(path: $0)! }
    return generateForFiles(files)
  }
}


private func sortByName(lhs: StencilType, rhs: StencilType) -> Bool {
  return lhs.name < rhs.name
}
