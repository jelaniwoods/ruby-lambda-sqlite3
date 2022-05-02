require "json"

def lambda_handler(event:, context:)
  require "sqlite3"
  # Change working directory to /tmp so we can write files
  Dir.chdir("/tmp")
  db = SQLite3::Database.new "test.db"

  # Create a table
  rows = db.execute <<-SQL
    create table numbers (
      name varchar(30),
      val int
    );
  SQL

  # Execute a few inserts
  {
    "one" => 1,
    "two" => 2,
  }.each do |pair|
    db.execute "insert into numbers values ( ?, ? )", pair
  end
  result = db.execute("select * from numbers")
  {
    statusCode: 200,
    body: {
      message: "Hello World!",
      out: result
    }.to_json
  }
end
