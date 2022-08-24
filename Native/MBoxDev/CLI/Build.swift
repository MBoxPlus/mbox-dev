//
//  Build.swift
//  MBoxDev
//
//  Created by Whirlwind on 2019/12/15.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspaceCore

public enum BuildStep {
    case validate
    case upgrade
    case build
    case updateManifest
}

public protocol BuildStage {    
    static var name: String { get }
    init(outputDir: String)
    var outputDir: String { get }

    func buildStep(for repo: MBWorkRepo) -> [BuildStep]

    func validate(repos: [(repo: MBWorkRepo, curVersion: String?, nextVersion: String)]) throws
    func validate(repo: MBWorkRepo, curVersion: String?, nextVersion: String) throws

    func upgrade(repos: [(repo: MBWorkRepo, curVersion: String?, nextVersion: String)]) throws
    func upgrade(repo: MBWorkRepo, curVersion: String?, nextVersion: String) throws

    func build(repos: [(repo: MBWorkRepo, curVersion: String?, nextVersion: String)]) throws
    func build(repo: MBWorkRepo, curVersion: String?, nextVersion: String) throws

    func update(manifests: [MBWorkRepo: MBPluginPackage]) throws
    func update(manifest: MBPluginPackage, repo: MBWorkRepo) throws
}

extension BuildStage {
    public var name: String {
        return Self.name
    }
    public var description: String {
        return Self.name
    }

    public func shouldRun(step: BuildStep, repo: MBWorkRepo) -> Bool {
        return self.buildStep(for: repo).contains(step)
    }

    public func validate(repos: [(repo: MBWorkRepo, curVersion: String?, nextVersion: String)]) throws {
        try self.each(repos: repos, title: "Validate Project") { (repo, curVersion, nextVersion) in
            try self.validate(repo: repo, curVersion: curVersion, nextVersion: nextVersion)
        }
    }
    public func validate(repo: MBWorkRepo, curVersion: String?, nextVersion: String) throws { }

    public func upgrade(repos: [(repo: MBWorkRepo, curVersion: String?, nextVersion: String)]) throws {
        try self.each(repos: repos, title: "Upgrade Version") { (repo, curVersion, nextVersion) in
            try self.upgrade(repo: repo, curVersion: curVersion, nextVersion: nextVersion)
        }
    }
    public func upgrade(repo: MBWorkRepo, curVersion: String?, nextVersion: String) throws { }

    public func build(repos: [(repo: MBWorkRepo, curVersion: String?, nextVersion: String)]) throws {
        try self.each(repos: repos, title: "Build Product") { (repo, curVersion, nextVersion) in
            try self.build(repo: repo, curVersion: curVersion, nextVersion: nextVersion)
        }
    }
    public func build(repo: MBWorkRepo, curVersion: String?, nextVersion: String) throws { }

    public func update(manifests: [MBWorkRepo: MBPluginPackage]) throws {
        try self.each(repos: manifests, title: "Update Manifest") { (repo, manifest) in
            try self.update(manifest: manifest, repo: repo)
        }
    }
    public func update(manifest: MBPluginPackage, repo: MBWorkRepo) throws { }

    public func each(repos: [(repo: MBWorkRepo, curVersion: String?, nextVersion: String)],
                     title: String,
                     block: @escaping ((repo: MBWorkRepo, curVersion: String?, nextVersion: String)) throws -> Void) throws {
        for item in repos {
            try UI.allowAsyncExec(title: "[\(Self.name)] \(title) [\(item.repo.name)]") {
                try block(item)
            }
        }
        try UI.wait()
    }

    public func each<T>(repos: [MBWorkRepo: T],
                        title: String,
                        block: @escaping (_ repo: MBWorkRepo, _ object: T) throws -> Void) throws {
        for (repo, obj) in repos {
            try UI.allowAsyncExec(title: "[\(Self.name)] \(title) [\(repo.name)]") {
                try block(repo, obj)
            }
        }
        try UI.wait()
    }
}

extension MBCommander.Plugin {
    open class Build: Plugin {

        open class override var description: String? {
            return "Build the development plugin(s)"
        }

        open class override var arguments: [Argument] {
            var arguments = super.arguments
            arguments << Argument("name", description: "Plugin Names, otherwise will release all plugins.", required: false, plural: true)
            return arguments
        }

        open override class var options: [Option] {
            var options = super.options
            options << Option("stage", description: "The build stage", values: Self.stages.map { $0.name })
            options << Option("output-dir", description: "The directory for the output")
            return options
        }

        open override class var flags: [Flag] {
            var flags = super.flags
            flags << Flag("force", description: "Force release exists version")
            flags << Flag("clean", description: "Clean output directory. Defaults: YES if no stage options.")
            return flags
        }

        dynamic
        open class var stages: [BuildStage.Type] {
            return [LauncherStage.self, ResourceStage.self, SettingStage.self]
        }

        open override func setup() throws {
            self.force = self.shiftFlag("force")
            let clean = self.shiftFlag("clean")
            self.outputDir = self.shiftOption("output-dir") ?? self.workspace.releaseDirectory
            if let stages: [String] = self.shiftOptions("stage") {
                let allStages = self.stages
                self.stages = try stages.map { stage in
                    guard let v = allStages.first(where: { $0.name.lowercased() == stage.lowercased()
                    }) else {
                        throw UserError("No stage named `\(stage)`.")
                    }
                    return v
                }
                self.clean = clean ?? false
            } else {
                self.clean = clean ?? true
            }
            self.names = self.shiftArguments("name")
            try super.setup()
        }

        open var names: [String] = []
        open var repos: [MBWorkRepo] = []
        open var force: Bool = false
        open var clean: Bool = true
        open lazy var stages: [BuildStage] = Self.stages.map { $0.init(outputDir: self.outputDir) }.sorted(by: \.name)
        open var outputDir: String!

        open override func validate() throws {
            try super.validate()
            let repos: [MBConfig.Repo]
            if self.names.isEmpty {
                repos = self.config.currentFeature.repos
            } else {
                repos = self.names.compactMap { name -> MBConfig.Repo? in
                    if let repo = self.config.currentFeature.findRepo(name: name).first {
                        return repo
                    }
                    UI.log(warn: "Could not find the repo: \(name)")
                    return nil
                }
            }
            self.repos = repos.compactMap(\.workRepository).sorted(by: \.name)
        }

        open var releaseRepos: [(repo: MBWorkRepo, curVersion: String?, nextVersion: String)] = []

        open func eachStage(_ title: String,
                            skip: ((BuildStage) -> Bool)? = nil,
                            block: (BuildStage) throws -> Void) rethrows {
            try UI.section(title) {
                for stage in self.stages {
                    if let skip = skip, skip(stage) {
                        continue
                    }
                    try UI.section("[\(stage.name)]") {
                        try block(stage)
                    }
                }
            }
        }

        open override func run() throws {
            try super.run()
            try UI.section("List Upgrade Repos") {
                self.releaseRepos = try upgradeRepos()
            }

            if releaseRepos.isEmpty {
                UI.log(info: "No plugin to upgrade.")
                return
            }

            if self.clean && self.outputDir.isExists {
                try FileManager.default.removeItem(atPath: self.outputDir)
            }

            if !self.outputDir.isExists {
                try FileManager.default.createDirectory(atPath: self.outputDir, withIntermediateDirectories: true)
            }

            try self.eachStage("Validate Inforamtion") { stage in
                let repos = self.releaseRepos.filter { stage.shouldRun(step: .validate, repo: $0.repo) }
                try stage.validate(repos: repos)
            }

            try self.eachStage("Upgrade Version") { stage in
                let repos = self.releaseRepos.filter { stage.shouldRun(step: .upgrade, repo: $0.repo) }
                try stage.upgrade(repos: repos)
            }

            try UI.section("Copy Manifest") {
                try self.copyManifests(repos: self.releaseRepos.map(\.repo))
            }

            var manifests: [MBWorkRepo: MBPluginPackage] = [:]
            for (repo, _, version) in self.releaseRepos {
                let manifest = repo.productManifest(self.outputDir)
                manifest.version = version
                manifests[repo] = manifest
            }
            try self.eachStage("Update Manifest") { stage in
                let repos = manifests.filter { stage.shouldRun(step: .updateManifest, repo: $0.key) }
                try stage.update(manifests: repos)
            }

            try self.eachStage("Build Product") { stage in
                let repos = self.releaseRepos.filter { stage.shouldRun(step: .build, repo: $0.repo) }
                try stage.build(repos: repos)
            }

            UI.section("Save Manifest") {
                manifests.values.flatMap(\.allModules).forEachInParallel {
                    $0.save() }
            }
        }

        open func copyManifests(repos: [MBWorkRepo]) throws {
            try MBWorkspace.eachRepos(repos, title: "Copy Manifest") { repo in
                let dir = repo.productDir(self.outputDir)
                for module in repo.manifest!.allModules {
                    let targetPath = dir.appending(pathComponent: module.relativeDir).appending(pathComponent: module.filePath!.lastPathComponent)
                    let sourcePath = module.filePath!
                    try UI.log(verbose: "Copy `\(Workspace.relativePath(sourcePath))` -> `\(Workspace.relativePath(targetPath))`") {
                        if targetPath.isExists {
                            try? FileManager.default.removeItem(atPath: targetPath)
                        } else {
                            try? FileManager.default.createDirectory(atPath: targetPath.deletingLastPathComponent, withIntermediateDirectories: true, attributes: nil)
                        }
                        try FileManager.default.copyItem(atPath: sourcePath, toPath: targetPath)
                    }
                }
            }
        }

        open func upgradeRepos() throws -> [(repo: MBWorkRepo, curVersion: String?, nextVersion: String)] {
            var repos = [(repo: MBWorkRepo, curVersion: String?, nextVersion: String)]()
            for repo in self.repos {
                try UI.log(verbose: "[\(repo)]") {
                    guard repo.manifest != nil else {
                        UI.log(verbose: "There is not a manifest.yml, skip!")
                        return
                    }
                    let versions = try self.fetchNextVersion(repo: repo)
                    guard self.shouldUpgrade(repo: repo, curVersion: versions.current, nextVersion: versions.next) else {
                        UI.log(verbose: "Skip upgrade.")
                        return
                    }
                    repos.append((repo: repo, curVersion: versions.current, nextVersion: versions.next))
                }
            }
            if !repos.isEmpty {
                UI.log(info: "These repos will be upgraded:",
                       items: repos.map { "\($0.repo.manifest!.name): \(($0.curVersion ?? "(none)").ANSI(.green)) -> \($0.nextVersion.ANSI(.yellow))" })
            }
            return repos
        }

        open func fetchNextVersion(repo: MBWorkRepo) throws -> (current: String?, next: String) {
            guard self.force || ["master", "main", "develop"].contains(repo.git?.currentBranch ?? "") else {
                throw UserError("The HEAD is NOT main/master!")
            }
            return try repo.nextVersion()
        }

        open func shouldUpgrade(repo: MBWorkRepo, curVersion: String?, nextVersion: String) -> Bool {
            if curVersion == nextVersion, !self.force {
                return false
            }
            var info = "Will upgrade to v\(nextVersion)"
            if let curVersion = curVersion {
                info.append(" from v\(curVersion)")
            }
            if self.force {
                info.append(" (Force)")
            }
            return true
        }
    }
}
