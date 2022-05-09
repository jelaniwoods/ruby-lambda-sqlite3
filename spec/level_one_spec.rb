require_relative './spec_helper.rb'

describe "Level one" do
  before do
    ActiveRecord::Base.establish_connection(
      adapter: "sqlite3",
      database: File.join(File.expand_path("..", __dir__), "msm.sqlite3")
    )
  end
  # p ARGV
  query = ENV['QUERY']
  # TODO make sure multi-line queries work
  let(:results) { eval(query) }

  it "should do include a Movie from the first Director" do
    expect(results).to include Movie.find_by(director_id: 1)
  end
end
