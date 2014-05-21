# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |gem|
  gem.name          = "fluent-plugin-splunkapi-ssln"
  gem.version       = "0.0.1"
  gem.authors       = ["Kristian Brimble"]
  gem.email         = ["kbrimble@sportingsolutions,com"]
  gem.summary       = %q{Splunk output plugin (REST API / Storm API) for Fluentd event collector}
  gem.description   = %q{Splunk output plugin (REST API / Storm API) for Fluentd event collector}
  gem.homepage      = "https://github.com/kbrimble/fluent-plugin-splunkapi"
  gem.license       = 'Apache License, Version 2.0'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.rubyforge_project = "fluent-plugin-splunkapi-ssln"
  gem.add_development_dependency "fluentd"
  gem.add_development_dependency "net-http-persistent"
  gem.add_runtime_dependency "fluentd"
  gem.add_runtime_dependency "net-http-persistent"
end
