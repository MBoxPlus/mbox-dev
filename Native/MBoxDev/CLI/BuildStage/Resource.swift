//
//  CopyResource.swift
//  MBoxDev
//
//  Created by Whirlwind on 2021/5/31.
//  Copyright © 2021 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspaceCore

public class ResourceStage: BuildStage {

    public static var name: String {
        return "Resource"
    }

    required public init(outputDir: String) {
        self.outputDir = outputDir
    }

    public var outputDir: String

    lazy var commitDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return dateFormatter
    }()

    lazy var buildNumberFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyMMddHHmmss"
        return dateFormatter
    }()

    public func buildStep(for repo: MBWorkRepo) -> [BuildStep] {
        var v: [BuildStep] = [.validate, .updateManifest]
        if self.hasResource(for: repo) {
            v.append(.build)
        }
        return v
    }

    public func validate(repo: MBWorkRepo, curVersion: String?, nextVersion: String) throws {
        guard let manifest = repo.manifest else {
            throw UserError("[\(repo)] `manifest.yml` missing.")
        }
        if manifest.authors?.isEmpty != false {
            throw UserError("[\(repo)] Require `AUTHORS` in the `manifest.yml`.")
        }
    }

    public func hasResource(for repo: MBWorkRepo) -> Bool {
        return repo.manifest?.icon != nil ||
        repo.path.appending(pathComponent: "Resources").isExists
    }

    public func build(repo: MBWorkRepo, curVersion: String?, nextVersion: String) throws {
        let productDir = repo.productDir(self.outputDir)

        if let icon = repo.manifest?.icon {
            let iconAtPath = repo.path.appending(pathComponent: icon)
            if FileManager.default.fileExists(atPath: iconAtPath) {
                let iconToPath = productDir.appending(pathComponent: icon)
                try UI.log(verbose: "Copy `\(Workspace.relativePath(iconAtPath))` -> `\(Workspace.relativePath(iconToPath))`.") {
                    if iconToPath.isExists {
                        try FileManager.default.removeItem(atPath: iconToPath)
                    }
                    try FileManager.default.copyItem(atPath: iconAtPath, toPath: iconToPath)
                }
            }
        }

        let resourcesPath = repo.path.appending(pathComponent: "Resources")
        if resourcesPath.isExists {
            let dstPath = productDir.appending(pathComponent: "Resources")
            try UI.log(verbose: "Copy `\(Workspace.relativePath(resourcesPath))` -> `\(Workspace.relativePath(dstPath))`.") {
                if dstPath.isExists {
                    try FileManager.default.removeItem(atPath: dstPath)
                }
                try FileManager.default.copyItem(atPath: resourcesPath, toPath: dstPath)
            }
        }
    }

    public func update(manifest: MBPluginPackage, repo: MBWorkRepo) throws {
        let head = try repo.git!.commit()
        manifest.buildDate = commitDateFormatter.string(from: Date())
        manifest.commitID = head.oid.desc(length: 7)
        manifest.commitDate = commitDateFormatter.string(from: head.author.time)
        manifest.buildNumber = buildNumberFormatter.string(from: head.author.time)
        manifest.publisher = repo.authorInfo
        if manifest.gitURL == nil {
            manifest.gitURL = repo.url
        }
        if manifest.homepage == nil {
            manifest.homepage = repo.gitURL?.toHTTPStyle()
        }
    }
}

extension ResourceStage: DevTemplate {
    public static var dirName: String {
        return "Resources"
    }

    public static var supportSubmodule: Bool {
        return false
    }

    public static var path: String? { return nil }
}
