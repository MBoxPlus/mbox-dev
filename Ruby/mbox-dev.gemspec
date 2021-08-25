
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "mbox-dev/version"

Gem::Specification.new do |spec|
  spec.name          = "mbox-dev"
  spec.version       = MBoxDev::VERSION
  spec.authors       = [`git config user.name`.strip]
  spec.email         = [`git config user.email`.strip]

  spec.summary       = %q{Plugin for MBox.}
  spec.description   = %q{Plugin for MBox.}
  spec.homepage      = "https://github.com/MBoxSpace/mbox-dev"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  # spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_dependency "rake", "~> 10.0"
  spec.add_dependency "minitest"
  spec.add_dependency "minitest-hooks"
  spec.add_dependency "minitest-rg"
end
