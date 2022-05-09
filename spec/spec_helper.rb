# require 'rspec/autorun'
require 'active_record'
require 'sqlite3'
Dir[File.join("var", "task", "models", "*.rb")].each { |file| require_relative file }
