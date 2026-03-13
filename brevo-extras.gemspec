require_relative "lib/brevo/extras/version"

Gem::Specification.new do |spec|
  spec.name        = "brevo-extras"
  spec.version     = Brevo::Extras::VERSION
  spec.authors     = [ "Bruno Perles" ]
  spec.email       = [ "contact@atnos.com" ]
  spec.homepage    = "https://github.com/atnos/brevo-extras"
  spec.summary     = "A Rails engine for sending transactional emails via the Brevo API."
  spec.description = "A Rails engine that provides a clean abstraction layer for sending transactional emails via the Brevo API, with built-in sandbox and safe modes, async delivery via Active Job, and automatic retry with polynomial backoff."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/atnos/brevo-extras"
  # spec.metadata["changelog_uri"] = "https://github.com/atnos/brevo-extras/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 8.1.2"
  spec.add_dependency "brevo", "~> 4.0"
end
