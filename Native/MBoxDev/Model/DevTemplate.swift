//
//  DevTemplate.swift
//  MBoxDev
//
//  Created by Whirlwind on 2019/12/1.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxGit

public protocol DevTemplate: CustomStringConvertible {
    static var name: String { get }
    static var dirName: String { get }
    static var path: String? { get }

    static var supportSubmodule: Bool { get }

    static func updateManifest(_ module: MBPluginModule) throws
}

public let DevTemplateKeys = [
    "__MBoxModuleName__",
    "__mbox_module_name__",
    "__mbox-module-name__",
    "__MBox/Module/Name__",

    "__MBoxPackageName__",
    "__mbox_package_name__",
    "__mbox-package-name__",

    "__MBoxModuleDir(RelativePackage)__",
    "__MBoxPackageDir(RelativeModule)__",
    "__mbox_latest_version__"
]

extension DevTemplate {
    public static var dirName: String {
        return self.name
    }

    public static var supportSubmodule: Bool {
        return true
    }

    public static func updateManifest(_ module: MBPluginModule) throws {
    }

    public static func copy(to directory: String) throws {
        try FileManager.default.createDirectory(atPath: directory.deletingLastPathComponent, withIntermediateDirectories: true, attributes: nil)
        if let path = self.path {
            try UI.log(verbose: "Copy `\(path)` -> `\(Workspace.relativePath(directory))`") {
                try FileManager.default.copyItem(atPath: path, toPath: directory)
            }
        } else {
            try UI.log(verbose: "Create `\(Workspace.relativePath(directory))`") {
                try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
            }
        }
    }

    public static var unusedFiles: [String] {
        return []
    }

    public static func cleanUnusedFiles(in directory: String) throws {
        for file in unusedFiles {
            let path = directory.appending(pathComponent: file)
            if path.isExists {
                try UI.log(verbose: "Removing file `\(file)` ...") {
                    try FileManager.default.removeItem(atPath: path)
                }
            }
        }
    }

    public static func format(template: String, with module: MBPluginModule) -> String {
        switch template {
        case "__MBoxModuleName__":
            return module.name
        case "__mbox_module_name__":
            return module.name.convertSnakeCased()
        case "__mbox-module-name__":
            return module.name.convertKebabCased()
        case "__MBox/Module/Name__":
            return module.nameWithGroup

        case "__MBoxPackageName__":
            return module.package!.name
        case "__mbox_package_name__":
            return module.package!.name.convertSnakeCased()
        case "__mbox-package-name__":
            return module.package!.name.convertKebabCased()

        case "__MBoxModuleDir(RelativePackage)__":
            let moduleName = module.relativeDir
            return moduleName.isEmpty ? "." : moduleName
        case "__MBoxPackageDir(RelativeModule)__":
            let count = module.name.split(separator: "/").count - 1
            return count == 0 ? "." : Array(repeating: "..", count: count).joined(separator: "/")
        case "__mbox_latest_version__":
            return MBoxCore.latestVersion ?? Bundle.app?.shortVersion ?? "2.4.0"    // default version
        default:
            return module.name
        }
    }

    public static func replace(_ string: String, with module: MBPluginModule) -> (String, Bool) {
        var content = string
        var changed = false
        for template in DevTemplateKeys {
            if content.contains(template) {
                changed = true
                content = content.replacingOccurrences(of: template, with: format(template: template, with: module))
            }
        }
        return (content, changed)
    }

    public static func apply(with module: MBPluginModule, in directory: String) throws {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(atPath: directory)
        for filename in contents {
            let path = directory.appending(pathComponent: filename)
            if path.isSymlink {
                // Do nothing
            } else if path.isFile {
                if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                    let (content, changed) = replace(content, with: module)
                    if changed {
                        try UI.log(verbose: "Update File Content: `\(path.relativePath(from: directory))`...") {
                            try content.write(toFile: path, atomically: true, encoding: .utf8)
                        }
                    }
                }
            } else if path.isDirectory {
                try self.apply(with: module, in: path)
            }
            let (content, changed) = replace(filename, with: module)
            if changed {
                let target = directory.appending(pathComponent: content)
                try UI.log(verbose: "Move `\(path.relativePath(from: directory))` -> `\(target.relativePath(from: directory))`") {
                    try fm.moveItem(atPath: path, toPath: target)
                }
            }
        }
    }

    public static func mergeConfig(from: String, target: MBWorkRepo) throws {
        guard let fromSetting = MBSetting.load(fromFile: from) else {
            return
        }
        let targetSetting = target.setting
        targetSetting.merge(fromSetting)
        if targetSetting.save() {
            try FileManager.default.removeItem(atPath: from)
        }
    }
}
