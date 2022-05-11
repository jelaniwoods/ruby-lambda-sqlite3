# Ruby Lambda sqlite3

This is a simple project to test running a Ruby AWS Lambda function that can use a sqlite3 database.

I was only able to get this to work using a custom container image.

## Test Locally
- Build image
   ```bash
   docker build -t ruby-lambda-sqlite3 .
   ```
- Run image
   ```bash
   docker run -p 9000:8080 ruby-lambda-sqlite3:latest
   ```
- Run test function call
   ```bash
   curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{}'
   ```

You can configure the structure of the test Event JSON with the last `{}` argument.

For example, if your Event looks like:

```json
{
  "payload":
    {
      "query": "Director.first.movies",
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
```

You can send the request like so:

```bash
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{
  "payload":
    {
      "query": "Director.first.movies",
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
}'
```
## Deploying

First you need to create an [ECR repository](http://console.aws.amazon.com/ecr/repositories) to host your image. You can create one with the default settings. To push your image, click the "View push commands" button and a popup should provide commands for you to copy-paste:
1. Authorize Docker to push to AWS.
2. Build Docker image.
3. Tag image to ECR repository name.
4. Push image to ECR repository.

Afterwards go to Lambda service and create function. When you do choose the "Container image" option and click "browse images", select the image you created, and click "Create Function". 

---
You can only write files that exist in the `/tmp` folder.

> Note that the /tmp is inside the function's execution environment and you do not have access to it from outside the function. If you want to save a file that you can access it externally, you should either save it to S3 or mount an EFS volume and write the file there.


### Main References
- [What is AWS Lambda Container Image?](https://aws.plainenglish.io/aws-lambda-container-image-a5eab06a445)
- [Using container images with AWS Lambda](https://hichaelmart.medium.com/using-container-images-with-aws-lambda-7ffbd23697f1)
- https://stackoverflow.com/questions/46282576/cannot-open-database-file-error-when-running-on-aws-lambda
- [Base Dockerfile from AWS](https://gallery.ecr.aws/lambda/ruby)
- [Testing Lambda container images locally](https://docs.aws.amazon.com/lambda/latest/dg/images-test.html)
- [ActiveRecord and sqlite3 : find does not accept any condition?](https://stackoverflow.com/questions/8329790/activerecord-and-sqlite3-find-does-not-accept-any-condition)
- [Install sqlite3 3.8 on CentOS](https://stackoverflow.com/a/70959361/10481804)
- [Save a file to a tmp folder lambda](https://repost.aws/questions/QUBy1WCApySnOYyMsXLLfNqg/how-to-save-a-file-to-a-tmp-temp-folder-in-lambda)
