require "json"
require "activerecord"

# Define the models
class Show < ActiveRecord::Base
  has_many :episodes, inverse_of: :show
end

class Episode < ActiveRecord::Base
  belongs_to :show, inverse_of: :episodes, required: true
end

def lambda_handler(event:, context:)
  require "sqlite3"
  require "activerecord"
  # Change working directory to /tmp so we can write files
  Dir.chdir("/tmp")
  db = SQLite3::Database.new "test.db"

  ActiveRecord::Base.establish_connection(
    adapter: "sqlite3",
    database: "/tmp/test.db",
  )

  # Define a minimal database schema
  ActiveRecord::Schema.define do
    create_table :shows, force: true do |t|
      t.string :name
    end

    create_table :episodes, force: true do |t|
      t.string :name
      t.belongs_to :show, index: true
    end
  end

  # Create a few records...
  show = Show.create!(name: "Infinity Train")

  first_episode = show.episodes.create!(name: "Infinity Train")
  second_episode = show.episodes.create!(name: "The Number Car")

  episode_names = show.episodes.pluck(:name)

  result = "#{show.name} has #{show.episodes.size} episodes named #{episode_names.join(", ")}."

  {
    statusCode: 200,
    body: {
      message: "Hello World!",
      out: result,
    }.to_json,
  }
end
