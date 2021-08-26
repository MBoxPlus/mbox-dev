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
import MBoxWorkspaceCore

public protocol DevTemplate: CustomStringConvertible {
    static var name: String { get }
    static var dirName: String { get }
    static var path: String? { get }

    static func updateManifest(_ manifest: MBPluginPackage) throws
}

public let DevTemplateKeys = ["__project_name__", "__ProjectName__", "__project-name__", "__mbox_latest_version__"]

extension DevTemplate {
    public static var dirName: String {
        return self.name
    }

    public static func updateManifest(_ manifest: MBPluginPackage) throws {
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

    public static func format(_ name: String, template: String) -> String {
        switch template {
        case "__project_name__":
            return name.convertSnakeCased()
        case "__ProjectName__":
            return name.convertCamelCased()
        case "__project-name__":
            return name.convertKebabCased()
        case "__mbox_latest_version__":
            return MBoxCore.latestVersion ?? Bundle.app?.shortVersion ?? "2.4.0"    // default version
        default:
            return name
        }
    }
    public static func replace(_ string: String, with name: String) -> (String, Bool) {
        var content = string
        var changed = false
        for template in DevTemplateKeys {
            if content.contains(template) {
                changed = true
                content = content.replacingOccurrences(of: template, with: format(name, template: template))
            }
        }
        return (content, changed)
    }

    public static func apply(with name: String, in directory: String) throws {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(atPath: directory)
        for filename in contents {
            let path = directory.appending(pathComponent: filename)
            if path.isSymlink {
                // Do nothing
            } else if path.isFile {
                if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                    let (content, changed) = replace(content, with: name)
                    if changed {
                        try content.write(toFile: path, atomically: true, encoding: .utf8)
                    }
                }
            } else if path.isDirectory {
                try self.apply(with: name, in: path)
            }
            let (content, changed) = replace(filename, with: name)
            if changed {
                let target = directory.appending(pathComponent: content)
                try fm.moveItem(atPath: path, toPath: target)
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
