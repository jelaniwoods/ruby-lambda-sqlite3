require 'minitest/autorun'
require 'minitest/reporters/json_reporter'
require 'active_record'
require 'sqlite3'
# Load models
Dir[File.join(File.expand_path("..", __dir__), "models", "*.rb")].each { |file| require_relative file }
Minitest::Reporters.use! [ Minitest::Reporters::JsonReporter.new ]
class QueryTests < Minitest::Test
  def setup
    ActiveRecord::Base.establish_connection(
      adapter: "sqlite3",
      database: File.join(File.expand_path("..", __dir__), "msm.sqlite3")
    )

    query = ENV['QUERY']
    # p "User query is: #{query}"
    # TODO make sure multi-line queries work
    @result = eval(query)
  end

  def test_filter
    assert_includes @result, Movie.find_by(director_id: 1)
  end
end
