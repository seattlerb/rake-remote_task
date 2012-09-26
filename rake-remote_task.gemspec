# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rake-remote_task/version'

Gem::Specification.new do |gem|
  gem.name = "rake-remote_task"
  gem.version = Rake::RemoteTaskGem::VERSION
  gem.authors = ["Ryan Davis", "Eric Hodel", "Wilson Bilkovich"]
  gem.email = ["ryand-ruby@zenspider.com", "drbrain@segment7.net", "wilson@supremetyrant.com"]
  gem.description = %q{Vlad the Deployer's sexy brainchild is rake-remote_task, extending
Rake with remote task goodness.}
  gem.summary = %q{Vlad the Deployer's sexy brainchild is rake-remote_task, extending Rake with remote task goodness.}
  gem.homepage = %q{http://rubyhitsquad.com/}

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.rdoc_options = ["--main", "README.txt"]
  gem.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.txt"]

   gem.add_runtime_dependency("rake", ["~> 0.8"])
   gem.add_runtime_dependency("open4", ["~> 1.0"])

   gem.add_development_dependency("minitest", ["~> 1.7.0"])
   gem.add_development_dependency("hoe", [">= 2.9.1"])
end
