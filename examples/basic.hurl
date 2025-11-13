POST http://localhost:9000/2015-03-31/functions/function/invocations
Content-Type: application/json

{
  "payload":
    {
      "query": "Director.all.at(0).movies",
      "database": "msm",
      "level": "one",
      "specs": [
        {
          "name": "uuid",
          "body": "it \"should do include a Movie from the first Director\" do\n    expect(results).to include Movie.find_by(director_id: 1)\n  end"
        }
      ],
      "models": [
        {
          "name": "movie.rb",
          "body": "class Movie < ActiveRecord::Base\n belongs_to :director\n has_many :characters\nend"
        },
        {
          "name": "director.rb",
          "body": "class Director < ActiveRecord::Base\n has_many :movies\nend"
        }
      ]
  }
}
