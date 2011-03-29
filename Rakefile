require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "chef_handler_splunk"
  gem.homepage = "http://github.com/adamhjk/chef_handler_splunk"
  gem.license = "Apache 2.0"
  gem.summary = %Q{Stores data about Chef runs for Splunk}
  gem.description = %Q{Stores data about Chef runs for Splunk}
  gem.email = "adam@opscode.com"
  gem.authors = ["Adam Jacob"]
  gem.add_runtime_dependency 'chef', '> 0.9'
end
Jeweler::RubygemsDotOrgTasks.new

require 'yard'
YARD::Rake::YardocTask.new
