require "json"
require "active_record"
require "sqlite3"
require 'fileutils'
# Require models
Dir[File.join(__dir__, "models", "*.rb")].each { |file| require_relative file }

# choose db, query to eval
def lambda_handler(event:, context:)
  query_string = event["queryStringParameters"]
  db_query = "Movie.all"
  database = "msm"
  if !query_string.nil?
    db_query = query_string["query"]
    database = query_string["database"]
  end
  # It appears I need to freshly copy the db to the /tmp/ folder at runtime
  # The file from the image doesn't register
  FileUtils.cp("#{database}.sqlite3", "/tmp/")
  ActiveRecord::Base.establish_connection(
    adapter: "sqlite3",
    database: "/tmp/#{database}.sqlite3",
  )

  result = eval(db_query)
  {
    statusCode: 200,
    body: {
      message: "Hello World!",
      out: result,
    }.to_json,
  }
end
