
require 'yaml'
yaml = YAML.load_file('../manifest.yml')
name = yaml["NAME"]
name2 = name.sub('MBox', 'mbox').underscore
version = ENV["VERSION"] || yaml["VERSION"]

Pod::Spec.new do |spec|
  spec.name         = "#{name}"
  spec.version      = "#{version}"
  spec.summary      = "MBox Plugin for Plugin Development."
  spec.description  = <<-DESC
    Create a template for plugin development.
                   DESC

  spec.homepage     = "https://github.com/MBoxSpace/#{name2}"
  spec.license      = "MIT"
  spec.author       = { `git config user.name`.strip => `git config user.email`.strip }

  spec.platform     = :osx, '10.15'
  spec.source       = { :git => "git@github.com:MBoxSpace/#{name2}.git", :tag => "#{spec.version}" }
  spec.source_files = "#{name}/*.{h,m,swift}", "#{name}/**/*.{h,m,swift}"

  yaml['DEPENDENCIES'].each do |name|
    spec.dependency name
  end

end
