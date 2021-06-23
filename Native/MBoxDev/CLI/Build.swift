//
//  Build.swift
//  MBoxDev
//
//  Created by 詹迟晶 on 2019/12/15.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspaceCore

public protocol BuildStage: DevTemplate {
    var name: String { get }
    
    init(outputDir: String)
    var outputDir: String { get }

    func validate(repos: [(repo: MBWorkRepo, curVersion: String?, nextVersion: String)]) throws
    func build(repos: [(repo: MBWorkRepo, curVersion: String?, nextVersion: String)]) throws
    func test(repos: [(repo: MBWorkRepo, curVersion: String?, nextVersion: String)]) throws

    func upgrade(repo: MBWorkRepo, nextVersion: String) throws
    func shouldBuild(repo: MBWorkRepo) -> Bool
}

extension BuildStage {
    public var name: String {
        return Self.name
    }
    public var description: String {
        return self.name
    }
    public func validate(repos: [(repo: MBWorkRepo, curVersion: String?, nextVersion: String)]) throws {
    }
    public func test(repos: [(repo: MBWorkRepo, curVersion: String?, nextVersion: String)]) throws {
    }
    public func shouldBuild(repo: MBWorkRepo) -> Bool {
        return false
    }
    public func upgrade(repo: MBWorkRepo, nextVersion: String) throws {
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
            flags << Flag("test", description: "Run the unit test. Defaults: YES")
            flags << Flag("clean", description: "Clean output directory. Defaults: YES if no stage options.")
            return flags
        }

        dynamic
        open class var stages: [BuildStage.Type] {
            return [LauncherStage.self, CopyResourceStage.self]
        }

        open override func setup() throws {
            self.test = self.shiftFlag("test", default: true)
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
        open var test: Bool = false
        open var clean: Bool = true
        open lazy var stages: [BuildStage] = Self.stages.map { $0.init(outputDir: self.outputDir) }
        open var outputDir: String!

        open override func validate() throws {
            try super.validate()
            if self.names.isEmpty {
                self.repos = self.config.currentFeature.repos.compactMap(\.workRepository)
            } else {
                self.repos = self.names.compactMap { name -> MBConfig.Repo? in
                    if let repo = self.config.currentFeature.findRepo(name: name).first {
                        return repo
                    }
                    UI.log(warn: "Could not find the repo: \(name)")
                    return nil
                }.compactMap(\.workRepository)
            }
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
                if !releaseRepos.isEmpty {
                    UI.log(info: "These repos will be upgraded:",
                                     items: self.releaseRepos.map { "\($0.repo.manifest!.name): \(($0.curVersion ?? "(none)").ANSI(.green)) -> \($0.nextVersion.ANSI(.yellow))" })
                }
            }

            if repos.isEmpty {
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
                try stage.validate(repos: self.releaseRepos)
            }

            try self.eachStage("Upgrade Version", skip: { stage in
                return !self.releaseRepos.contains { (repo: MBWorkRepo, curVersion: String?, nextVersion: String) in
                    stage.shouldBuild(repo: repo)
                }
            }) { stage in
                for (repo, _, nextVersion) in self.releaseRepos {
                    if !stage.shouldBuild(repo: repo) { continue }
                    try UI.log(verbose: "[\(repo.name)]") {
                        try stage.upgrade(repo: repo, nextVersion: nextVersion)
                    }
                }
            }

            try self.eachStage("Build Product") { stage in
                try stage.build(repos: releaseRepos)
            }

            if self.test {
                try self.eachStage("Test Product") { stage in
                    try stage.test(repos: releaseRepos)
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
                    guard self.force || repo.git?.currentBranch == "master" else {
                        UI.log(info: "The HEAD is NOT master, skip!")
                        return
                    }
                    guard let versions = try repo.nextVersion(force: force) else {
                        UI.log(verbose: "No need release new version.")
                        return
                    }

                    var info = "Will upgrade to v\(versions.next)"
                    if let curVersion = versions.current {
                        info.append(" from v\(curVersion)")
                    }
                    repos.append((repo: repo, curVersion: versions.current, nextVersion: versions.next))
                }
            }
            return repos
        }
    }
}
