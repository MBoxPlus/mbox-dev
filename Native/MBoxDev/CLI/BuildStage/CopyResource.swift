//
//  CopyResource.swift
//  MBoxDev
//
//  Created by 詹迟晶 on 2021/5/31.
//  Copyright © 2021 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspaceCore

public class CopyResourceStage: BuildStage {

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

    private func validateManifest(repo: MBWorkRepo) throws {
        guard let manifest = repo.manifest else {
            throw UserError("[\(repo)] `manifest.yml` missing.")
        }
        if manifest.authors?.isEmpty != false {
            throw UserError("[\(repo)] Require `AUTHORS` in the `manifest.yml`.")
        }
    }

    public func validate(repos: [(repo: MBWorkRepo, curVersion: String?, nextVersion: String)]) throws {
        for (repo, _, _) in repos {
            try UI.log(verbose: "[\(repo)]") {
                try self.validateManifest(repo: repo)
            }
        }
    }

    public func build(repos: [(repo: MBWorkRepo, curVersion: String?, nextVersion: String)]) throws {
        for (repo, _, _) in repos {
            try UI.log(verbose: "[\(repo)]") {
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

                let settingFile = repo.path.appending(pathComponent: "setting.schema.json")
                if settingFile.isExists {
                    let dstPath = productDir.appending(pathComponent: settingFile.lastPathComponent)
                    if dstPath.isExists {
                        try FileManager.default.removeItem(atPath: dstPath)
                    }
                    try FileManager.default.copyItem(atPath: settingFile, toPath: dstPath)
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
        }
    }

    public func update(manifest: MBPluginPackage, repo: MBWorkRepo, version: String) throws {
        let head = try repo.git!.commit()
        manifest.buildDate = commitDateFormatter.string(from: Date())
        manifest.version = version
        manifest.commitID = head.oid.desc(length: 7)
        manifest.commitDate = commitDateFormatter.string(from: head.author.time)
        manifest.buildNumber = buildNumberFormatter.string(from: head.author.time)
        manifest.publisher = repo.git!.authorName
        if manifest.gitURL == nil {
            manifest.gitURL = repo.url
        }
        if manifest.homepage == nil {
            manifest.homepage = repo.gitURL?.toHTTPStyle()
        }
    }
}

extension CopyResourceStage: DevTemplate {
    public static var dirName: String {
        return "Resources"
    }

    public static var path: String? { return nil }
}
