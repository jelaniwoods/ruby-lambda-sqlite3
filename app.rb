require "json"
require "active_record"
require "sqlite3"
require "fileutils"
require "awesome_print"

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
  # TODO: if there's an error, it seems to just respond with "" until server restarts- Why?
  payload = event.fetch("payload")
  ap payload
  keys = %w{query database level specs models}
  query, database, level, specs, models = payload.values_at(*keys)

  recreate_directories
  connect_to_db(database)
  puts "Connected to DB\n\n"
  puts "Writing spec helper"
  write_spec_helper

  puts "Writing specs..."
  specs.each do |spec|
    filename, body = spec.values_at("name", "body")
    write_spec(filename, body)
  end

  puts "Writing models..."
  models.each do |model|
    filename, body = model.values_at("name", "body")
    write_model(filename, body)
  end

  puts "Loading models... #{ Dir[File.join("/tmp", "models", "*.rb")].length}"
  Dir[File.join("/tmp", "models", "*.rb")].each do |file|
    require_relative file
  end
  puts "======\n\n"
  Dir[File.join("/tmp", "models", "*.rb")].each do |file|
    p file
    puts "----"
    puts open(file).read
    puts "_____"*3
  end

  puts "evaluating query..."
  result = ""
  begin
    result = eval(query)

  rescue => exception
    result = exception.message
  end
  return_class = result.class.to_s
  if result.class.ancestors.include?(ActiveRecord::Base)
    return_class += "::ActiveRecord::Base"
  end
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

def write_spec(filename, body)
  filename = "/tmp/spec/#{filename}_spec.rb"
  tmp_file = File.open(filename, "a")
  tmp_file.seek(0)
  # TODO organize with level name
  # TODO use specified database
  content = <<~RUBY
    require_relative './spec_helper.rb'
    describe "Level one" do
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
  puts filename
  puts body
  puts "---------\n\n"
  filename
end

def minitest_output(query)
  # `QUERY='#{query}' ruby test/level_#{level}_tests.rb`
end

def rspec_output(query)
  `QUERY='#{query}' bundle exec rspec /tmp/spec/ --format j`
end

def write_spec_helper
  # TODO: load models from /tmp/
  content = <<~RUBY
    require 'active_record'
    require 'sqlite3'
    Dir[File.join("/tmp", "models", "*.rb")].each do |file|
      require_relative file
    end
    # ActiveRecord::Base.establish_connection(
    #   adapter: "sqlite3",
    #   database: File.join("/tmp", "msm.sqlite3")
    # )
  RUBY
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
  File.delete("/tmp/#{database}.sqlite3") if File.exists?("/tmp/#{database}.sqlite3")
  FileUtils.cp("#{database}.sqlite3", "/tmp/")
  # TODO Why is this required in the function?
  # shouldn't it just need to be in the spec file?
  ActiveRecord::Base.establish_connection(
    adapter: "sqlite3",
    database: "/tmp/#{database}.sqlite3",
  )
end

def recreate_directories
  puts "recreatings..."
  Dir[File.join("/tmp", "models", "*.rb")].each do |file|
    puts file
    puts open(file).read
  end

  FileUtils.rm_rf("/tmp/spec")
  FileUtils.rm_rf("/tmp/models")
  Dir.mkdir("/tmp/spec")
  Dir.mkdir("/tmp/models")
  puts "should be empty"
  Dir[File.join("/tmp", "models", "*.rb")].each do |file|
    puts file
    puts open(file).read
  end
end
