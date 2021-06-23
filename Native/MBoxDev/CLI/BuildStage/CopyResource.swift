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

    public static var dirName: String {
        return "Resources"
    }

    required public init(outputDir: String) {
        self.outputDir = outputDir
    }

    public var outputDir: String

    public static var path: String? { return nil }

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
        for (repo, _, nextVersion) in repos {
            try UI.log(verbose: "[\(repo)]") {
                var package = MBPluginPackage(dictionary: repo.manifest!.dictionary)
                package.path = self.outputDir.appending(pathComponent: repo.manifest!.name)
                package.filePath = package.path!.appending(pathComponent: "manifest.yml")

                try UI.log(verbose: "Save manifest: `\(Workspace.relativePath(package.filePath!))`") {
                    let head = try repo.git!.commit()
                    package.buildDate = commitDateFormatter.string(from: Date())
                    package.version = nextVersion
                    package.commitID = head.oid.desc(length: 7)
                    package.commitDate = commitDateFormatter.string(from: head.author.time)
                    package.buildNumber = buildNumberFormatter.string(from: head.author.time)
                    package.version = nextVersion
                    package.publisher = repo.git!.authorName
                    if package.gitURL == nil {
                        package.gitURL = repo.url
                    }
                    if package.homepage == nil {
                        package.homepage = repo.gitURL?.toHTTPStyle()
                    }
                    package.save()
                }

                if let icon = repo.manifest?.icon {
                    let iconAtPath = repo.path.appending(pathComponent: icon)
                    if FileManager.default.fileExists(atPath: iconAtPath) {
                        let iconToPath = package.path.appending(pathComponent: icon)
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
                    let dstPath = package.path.appending(pathComponent: settingFile.lastPathComponent)
                    if dstPath.isExists {
                        try FileManager.default.removeItem(atPath: dstPath)
                    }
                    try FileManager.default.copyItem(atPath: settingFile, toPath: dstPath)
                }

                let resourcesPath = repo.path.appending(pathComponent: "Resources")
                if resourcesPath.isExists {
                    let dstPath = package.path.appending(pathComponent: "Resources")
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
}
