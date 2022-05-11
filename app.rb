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
  payload = event.fetch("payload")
  keys = %w{query database level specs models}
  query, database, level, specs, models = payload.values_at(*keys)

  connect_to_db(database)

  # Create spec and models folders
  Dir.mkdir("/tmp/spec") unless Dir.exist?('/tmp/spec')
  Dir.mkdir("/tmp/models") unless Dir.exist?('/tmp/models/')
  write_spec_helper

  specs.each do |spec|
    filename, body = spec.values_at("name", "body")
    write_spec(filename, body)
  end

  models.each do |model|
    filename, body = model.values_at("name", "body")
    write_model(filename, body)
  end

  Dir[File.join("/tmp", "models", "*.rb")].each do |file|
    require_relative file
  end

  result = eval(query)
  # minitest_output = minitest_output(query)
  rspec_test_output = rspec_output(query)

  # TODO maybe extract this as well
  {
    statusCode: 200,
    body: {
      query: query,
      return_value: result,
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
    Dir[File.join("/tmp", "models", "*.rb")].each do
      |file| require_relative file
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
  # It appears I need to freshly copy the db to the /tmp/ folder at runtime
  FileUtils.cp("#{database}.sqlite3", "/tmp/")
  # TODO Why is this required in the function?
  # shouldn't it just need to be in the spec file?
  ActiveRecord::Base.establish_connection(
    adapter: "sqlite3",
    database: "/tmp/#{database}.sqlite3",
  )
end
