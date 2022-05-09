# require 'rspec/autorun'
# -> no longer required if we run via `bundle exec rspec`
require 'active_record'
require 'sqlite3'
Dir[File.join("var", "task", "models", "*.rb")].each { |file| require_relative file }
