# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{appengine-apis}
  s.version = "0.0.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Ryan Brown"]
  s.date = %q{2009-05-06}
  s.description = %q{APIs and utilities for using JRuby on Google App Engine.  To load the API stubs in IRB simply require 'rubygems' require 'appengine-apis/local_boot'  This will configure access to the same Datastore as running  $ dev_appserver.sh .  See these classes for an overview of each API: - AppEngine::Logger - AppEngine::Testing - AppEngine::Users - AppEngine::Mail - AppEngine::Memcache - AppEngine::URLFetch - AppEngine::Datastore  Unless you're implementing your own ORM, you probably want to use the DataMapper API instead of the lower level AppEngine::Datastore API.}
  s.email = ["ribrdb@gmail.com"]
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.rdoc"]
  s.files = ["History.txt", "Manifest.txt", "README.rdoc", "Rakefile", "lib/appengine-apis.rb", "lib/appengine-apis/apiproxy.rb", "lib/appengine-apis/datastore.rb", "lib/appengine-apis/datastore_types.rb", "lib/appengine-apis/local_boot.rb", "lib/appengine-apis/logger.rb", "lib/appengine-apis/mail.rb", "lib/appengine-apis/memcache.rb", "lib/appengine-apis/merb-logger.rb", "lib/appengine-apis/sdk.rb", "lib/appengine-apis/testing.rb", "lib/appengine-apis/urlfetch.rb", "lib/appengine-apis/users.rb", "script/console", "script/destroy", "script/generate", "spec/datastore_spec.rb", "spec/datastore_types_spec.rb", "spec/logger_spec.rb", "spec/mail_spec.rb", "spec/memcache_spec.rb", "spec/spec.opts", "spec/spec_helper.rb", "spec/urlfetch_spec.rb", "spec/users_spec.rb", "tasks/rspec.rake"]
  s.homepage = %q{http://code.google.com/p/appengine-jruby}
  s.rdoc_options = ["--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{appengine-jruby}
  s.rubygems_version = %q{1.3.3}
  s.summary = %q{APIs and utilities for using JRuby on Google App Engine}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<newgem>, [">= 1.3.0"])
      s.add_development_dependency(%q<hoe>, [">= 1.8.0"])
    else
      s.add_dependency(%q<newgem>, [">= 1.3.0"])
      s.add_dependency(%q<hoe>, [">= 1.8.0"])
    end
  else
    s.add_dependency(%q<newgem>, [">= 1.3.0"])
    s.add_dependency(%q<hoe>, [">= 1.8.0"])
  end
end
