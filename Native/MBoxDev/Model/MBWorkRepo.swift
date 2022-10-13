//
//  MBConfig.Repo.swift
//  MBoxDev
//
//  Created by Whirlwind on 2019/11/17.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxDependencyManager

var MBWorkRepoManifest: UInt8 = 0

extension MBWorkRepo {
    public var manifestPath: String? {
        return self.path.appending(pathComponent: "manifest.yml")
    }

    public var manifest: MBPluginPackage? {
        return associatedObject(base: self, key: &MBWorkRepoManifest) {
            guard let path = self.manifestPath else { return nil }
            return MBPluginPackage.load(fromFile: path)
        }
    }

    public func createManifest(name: String) -> MBPluginPackage {
        var package = MBPluginPackage(dictionary: ["NAME": name])
        package.version = "1.0"
        package.filePath = self.manifestPath!
        if let author = self.authorInfo {
            package.authors = [author]
        }
        return package
    }

    public var authorInfo: String? {
        guard let author = self.git?.authorName else {
            return nil
        }
        if let email = self.git?.authorEmail {
            return "\(author) (\(email))"
        } else {
            return author
        }
    }

    public func productDir(_ dir: String) -> String {
        return dir.appending(pathComponent: manifest!.name)
    }

    public func productManifest(_ dir: String) -> MBPluginPackage {
        return MBPluginPackage.load(fromFile: self.productDir(dir).appending(pathComponent: "manifest.yml"))
    }

    // MARK: - Version
    public func nextVersion() throws -> (current: String?, next: String) {
        guard let manifest = self.manifest else {
            throw RuntimeError("There is not a manifest.yml, skip!")
        }
        guard let git = self.git,
              let currentCommit = git.currentCommit else {
                  throw RuntimeError("Git status error, skip!")
        }
        let maxVersion = git.maxVersionTag()
        let curVersion: String? = maxVersion?.name.deletePrefix("v")

        if currentCommit == maxVersion?.oid {
            return (curVersion, curVersion!)
        }

        var number = 0
        if let maxVersion = maxVersion?.name.deletePrefix("v") {
            var versions = maxVersion.split(separator: ".")
            number = Int(String(versions.popLast()!)) ?? 0
            if versions.joined(separator: ".") == manifest.version {
                number += 1
            } else {
                number = 0
            }
        }
        let nextVersion = "\(manifest.version).\(number)"
        return (curVersion, nextVersion)
    }

    public func updateMajorVersion(_ version: String) throws {
        guard let manifest = self.manifest else {
            throw RuntimeError("There is not a manifest.yml!")
        }
        if manifest.version == version {
            UI.log(verbose: "Version is already \(version).")
            return
        }
        UI.log(verbose: "Update version \(manifest.version) -> \(version).")
        manifest.version = version
        manifest.save()
    }

    @_dynamicReplacement(for: fetchPackageNames())
    public func dev_fetchPackageNames() -> [String] {
        var names = self.fetchPackageNames()
        if let manifest = self.manifest {
            names.append(manifest.name)
        }
        return names
    }
}
