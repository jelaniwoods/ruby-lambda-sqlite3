require "json"
require "active_record"
require "sqlite3"
require "fileutils"

# event:
# {
#   "payload":
#     {
#       "query": "Director.first.movies",
#       "database": "msm",
#       "level": "one",
#       "specs": [
#         {
#           "name": "uuid",
#           "body": "it \"should do include a Movie from the first Director\" do\n    expect(results).to include Movie.find_by(director_id: 1)\n  end"
#         }
#       ],
#       "models": [
#         {
#           "name": "movie.rb",
#           "body": "class Movie < ActiveRecord::Base\n belongs_to :director\n has_many :characters\n end"
#         }
#       ]
#     }
#   }
def lambda_handler(event:, context:)
  # TODO: Handle this gracefully
  payload = {}
  if event.has_key?("payload")
    puts "Running in development environment"
    payload = event.fetch("payload")
  else
    puts "Running in production environment"
    body = event["body"]
    json = JSON.parse(body)
    payload = json.fetch("payload")
  end
  keys = %w{query database level specs models}
  query, database, level, specs, models = payload.values_at(*keys)

  recreate_directories
  connect_to_db(database)

  # Broken in Ruby 3.2
  write_appdev_overrides
  write_spec_helper

  specs.each do |spec|
    filename, body = spec.values_at("name", "body")
    write_spec(filename, body, level)
  end

  models.each do |model|
    filename, body = model.values_at("name", "body")
    write_model(filename, body)
  end

  Dir[File.join("/tmp", "models", "*.rb")].each do |file|
    require_relative file
  end

  result, return_class = evaluate_query(query, models)
  # minitest_output = minitest_output(query)
  rspec_test_output = rspec_output(query)

  {
    statusCode: 200,
    body: {
      query: query,
      return_value: result,
      return_class: return_class,
      # minitest_output: JSON.parse(minitest_output),
      rspec_test_output: JSON.parse(rspec_test_output),
    }.to_json,
  }
end

def write_spec(filename, body, level)
  filename = "/tmp/spec/#{filename}_spec.rb"
  tmp_file = File.open(filename, "a")
  tmp_file.seek(0)
  # TODO use specified database
  content = <<~RUBY
    # require "/tmp/appdev_overrides.rb"
    require_relative './spec_helper.rb'
    describe "Level #{level}" do
      before do
        ActiveRecord::Base.establish_connection(
          adapter: "sqlite3",
          database: File.join("/tmp", "msm.sqlite3")
        )
      end
      query = ENV['QUERY']
      let(:results) { eval(query) }
      #{body}
    end
  RUBY

  tmp_file.write(content)
  tmp_file.close
  filename
end

def write_model(filename, body)
  filename = "/tmp/models/#{filename}"
  tmp_file = File.open(filename, "a")
  tmp_file.seek(0)
  tmp_file.write(body)
  tmp_file.close
  filename
end

def evaluate_query(query, models)
  model_content = ""
  models.each do |model|
    model_content += model["body"] + "\n"
  end
  query = <<~STRING
  require "/tmp/appdev_overrides.rb"
  #{model_content}
  #{query}
  STRING

  puts "\n\nFull Query\n\n"
  puts query
  begin
    result, return_class = nil
    result = eval(query)
  rescue => exception
    result = exception.message.gsub(/for #<.*>/, "for main:Object")
    return_class = exception.class
  rescue SyntaxError => syntax_error
    result = syntax_error
    return_class = syntax_error.class
  end

  return_class = result.class.to_s if return_class.to_s.empty?

  if result.class.ancestors.include?(ActiveRecord::Base)
    return_class += "::ActiveRecord::Base"
  end
  [result, return_class]
end

def write_appdev_overrides
  content = <<~STRING
  module ActiveRecord
    module Delegation
      alias at []
    end
  end
  module ActiveRecord
    module Calculations
      alias map_relation_to_array pluck
    end
  end
  module ActiveRecord
    module AttributeMethods
      alias fetch []
      alias store []=
    end
  end
  STRING
  filename = "/tmp/appdev_overrides.rb"
  tmp_file = File.open(filename, "a")
  tmp_file.seek(0)
  tmp_file.write(content)
  tmp_file.close
end

def minitest_output(query)
  # `QUERY='#{query}' ruby test/level_#{level}_tests.rb`
end

def rspec_output(query)
  `QUERY='#{query}' bundle exec rspec /tmp/spec/ --format j`
end

def write_spec_helper
  # TODO: load models from /tmp/
  content = <<~STRING
    require 'active_record'
    require 'sqlite3'
    Dir[File.join("/tmp", "models", "*.rb")].each do
      |file| require_relative file
    end
    # ActiveRecord::Base.establish_connection(
    #   adapter: "sqlite3",
    #   database: File.join("/tmp", "msm.sqlite3")
    # )
  STRING
  filename = "/tmp/spec/spec_helper.rb"
  tmp_file = File.open(filename, "a")
  tmp_file.seek(0)
  tmp_file.write(content)
  tmp_file.close
end

def render_error(message)
  {
    statusCode: 500,
    error: message,
  }.to_json
end

def connect_to_db(database)
  File.delete("/tmp/#{database}.sqlite3") if File.exist?("/tmp/#{database}.sqlite3")
  FileUtils.cp("#{database}.sqlite3", "/tmp/")
  # TODO Why is this required in the function?
  # shouldn't it just need to be in the spec file?
  ActiveRecord::Base.establish_connection(
    adapter: "sqlite3",
    database: "/tmp/#{database}.sqlite3",
  )
end

def recreate_directories
  FileUtils.rm_rf("/tmp/spec")
  FileUtils.rm_rf("/tmp/models")
  Dir.mkdir("/tmp/spec")
  Dir.mkdir("/tmp/models")
end
