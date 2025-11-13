require "json"
request = `hurl examples/basic.hurl`
response = JSON.parse(request)
hash = JSON.parse(response["body"])
puts JSON.pretty_generate(hash)
