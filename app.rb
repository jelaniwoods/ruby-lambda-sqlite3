require "json"
require "active_record"
require "sqlite3"
require 'fileutils'
# Require models
Dir[File.join(__dir__, "models", "*.rb")].each { |file| require_relative file }

# event:
# {
#   "payload": 
#     { 
#       "query": "Director.first.movies",
#       "database": "msm",
#       "level": "one",
#       "specs": [
#         {
#          "name": "uuid",
#           "body": "it \"should do include a Movie from the first Director\" do               expect(results).to include Movie.find_by(director_id: 1)             end"
#         }
#       ]
#     }
#   }
def lambda_handler(event:, context:)
  payload = event["payload"]
  keys = %w{query database level specs models}
  query, database, level, specs, models = payload.values_at(*keys)

  # It appears I need to freshly copy the db to the /tmp/ folder at runtime
  # The file from the image doesn't register
  FileUtils.cp("#{database}.sqlite3", "/tmp/")
  ActiveRecord::Base.establish_connection(
    adapter: "sqlite3",
    database: "/tmp/#{database}.sqlite3",
  )

  # Create spec and models folders
  Dir.mkdir('/tmp/spec') #unless Dir.exist?('/tmp/spec')
  Dir.mkdir('/tmp/models')# unless Dir.exist?('/tmp/models/')
  write_spec_helper
  specs.each do |spec|
    filename = spec["name"]
    body = spec["body"]
    write_spec(filename, body)
  end

  models.each do |model|
    filename, body = model.values_at("name", "body")
    write_model(filename, body)
  end
  result = eval(query)
  # minitest_output = `QUERY='#{query}' ruby test/level_#{level}_tests.rb`
  puts rspec_test_output = `QUERY='#{query}' bundle exec rspec /tmp/spec/ --format j`

  {
    statusCode: 200,
    body: {
      query: query,
      return_value: result,
      # minitest_results: JSON.parse(minitest_output),
      rspec_test_results: JSON.parse(rspec_test_output)
    }.to_json,
  }
end

def write_spec(filename, body)
  filename = "/tmp/spec/#{filename}_spec.rb"
  tmp_file = File.open(filename, "a")
  tmp_file.seek(0)
  tmp_file.write("require_relative './spec_helper.rb'\n")
  connect_to_db = <<-RUBY
describe "Level one" do
  before do
    ActiveRecord::Base.establish_connection(
      adapter: "sqlite3",
      database: File.join("/tmp", "msm.sqlite3")
    )
  end

  RUBY

  tmp_file.write(connect_to_db)
  tmp_file.write(eval_query)
  tmp_file.write(body)
  # close the "describe" block
  tmp_file.write("\nend")
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

def eval_query
  # TODO make sure multi-line queries work
  <<-RUBY
  query = ENV['QUERY']
  let(:results) { eval(query) }
  RUBY
end

def write_spec_helper
  content = <<~RUBY
  require 'active_record'
  require 'sqlite3'
  Dir[File.join("/var", "task", "models", "*.rb")].each do
    |file| require_relative file
  end
  RUBY
  filename = "/tmp/spec/spec_helper.rb"
  tmp_file = File.open(filename, "a")
  tmp_file.seek(0)
  tmp_file.write(content)
  tmp_file.close
end
