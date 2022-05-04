require "json"
require "active_record"
require "sqlite3"
require 'fileutils'
# Require models
Dir[File.join(__dir__, "models", "*.rb")].each { |file| require_relative file }

# event:
# {
#   "queryStringParameters": 
#     { 
#       "query": "Director.first.movies",
#       "database": "msm",
#       "level": "one"
#     }
#   }
def lambda_handler(event:, context:)
  query_string = event["queryStringParameters"]
  db_query = "Movie.all"
  database = "msm"
  level = "one"
  if !query_string.nil?
    db_query = query_string.fetch("query", db_query)
    database = query_string.fetch("database", database)
    level = query_string.fetch("level", level)
  end
  # It appears I need to freshly copy the db to the /tmp/ folder at runtime
  # The file from the image doesn't register
  FileUtils.cp("#{database}.sqlite3", "/tmp/")
  ActiveRecord::Base.establish_connection(
    adapter: "sqlite3",
    database: "/tmp/#{database}.sqlite3",
  )

  result = eval(db_query)
  test_output = `QUERY='#{db_query}' ruby test/level_#{level}_tests.rb`
  {
    statusCode: 200,
    body: {
      query: db_query,
      return_value: result,
      test_results: JSON.parse(test_output)
    }.to_json,
  }
end
