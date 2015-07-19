require "uri"
require "net/http"
require 'json'
data = {}
data["data"] = "awesome"

def send_post(hash)
  uri = URI('http://localhost:3000/api/videos/create')
  http = Net::HTTP.new(uri.host, uri.port)
  req = Net::HTTP::Post.new(uri.path, initheader = {'Content-Type' =>'application/json'})
  req.body = hash.to_json
  puts req.body
  res = http.request(req)
  puts "response #{res.body}"
end

send_post(data)
