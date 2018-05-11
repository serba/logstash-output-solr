Gem::Specification.new do |s|
  s.name = 'logstash-output-custom-solr'
  s.version = "0.1.3"
  s.licenses = ["Apache License (2.0)"]
  s.summary = "Logstash output plugin for sending data to Solr."
  s.description = "Logstash output plugin for sending data to Solr. It supports SolrCloud, not only Standalone Solr."
  s.authors = ["Minoru Osuka"]
  s.email = "minoru.osuka@gmail.com"
  s.homepage = "https://github.com/mosuka/logstash-output-solr"
  s.require_paths = ["lib"]

  # Files
  s.files = Dir['lib/**/*','spec/**/*','vendor/**/*','*.gemspec','*.md','CONTRIBUTORS','Gemfile','LICENSE']
   # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "output" }

  # Gem dependencies
  s.add_runtime_dependency "logstash-core-plugin-api", ">= 1.60", "<= 2.99"
  s.add_runtime_dependency "logstash-codec-plain"
  
  s.add_runtime_dependency 'rsolr', '~> 1.1.2'
  s.add_runtime_dependency 'zk'
  s.add_runtime_dependency 'rsolr-cloud'
  s.add_runtime_dependency 'stud'

  s.add_development_dependency "logstash-core", ">= 1.60", "<= 2.99"
  s.add_development_dependency "logstash-devutils"
  s.add_development_dependency 'rake', '~> 10.5.0'
  s.add_development_dependency 'zk-server', '~> 1.1.8' 
end
