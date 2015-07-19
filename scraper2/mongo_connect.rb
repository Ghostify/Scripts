require "uri"
require "net/http"
require 'httparty'
require 'json'
require 'rufus-scheduler'
require 'open-uri'
require 'nokogiri'

# bin/phantomjs --webdriver=9999
require 'selenium-webdriver'

hash = {}
work_queue = []

def start
  response = HTTParty.get('http://ghostify.herokuapp.com/links/untouched')
  if response.code == 200
    body = response.body
    work_queue = JSON.parse(body)

    puts "Queue: #{work_queue.count}"
    if work_queue.count > 0
      if execute_scraping(work_queue)
        work_queue = []
      end
    end
  end
end


def execute_scraping (array)
  count = 0
  while (count < array.length)
    full_link = array[count]["full_link"]
    puts "Scraping (#{count+1}/#{array.count}) #{full_link}"
    result = execute_scraper2(full_link)

    send_post(result)

    # puts result
    # upload_links(result)
    count = count + 1
  end
  return true
end

def execute_scraper2(full_link)
  hash = {}
  hash["transcript"] = get_captions(full_link)
  return hash
end

def get_captions(full_link)
  # supply video ID or full YouTube URL from command line
  if ARGV[0] != nil
    arg = ARGV[0]
  else
    arg = full_link
  end
  if arg =~ /^#{URI::regexp}$/
    link = arg
  else
    link = "http://www.youtube.com/watch?v=#{arg}"
  end

  # PhantomJS server
  begin
    driver = Selenium::WebDriver.for(:remote, :url => "http://localhost:9999")
    wait = Selenium::WebDriver::Wait.new(:timeout => 10) # seconds
  rescue Exception => e
    puts "ERROR: Selenium Error"
    exit
  end

  driver.navigate.to link

  # wait.until { driver.find_element(:id, 'action-panel-overflow-button') }

  # overflow_button = driver.find_element(:id, 'action-panel-overflow-button')
  overflow_button = driver.find_element :id => "action-panel-overflow-button"

  overflow_button.click

  begin
    transcript_button = driver.find_element :class => "action-panel-trigger-transcript"
    transcript_button.click

    # wait for at least one transcript line
    wait.until { driver.find_element(:id => 'cp-1') }

    transcript_container = driver.find_element(:id, 'transcript-scrollbox')

    cc = Nokogiri::HTML(transcript_container.attribute('innerHTML'))

    transcript_arr = []
    cc.css('.caption-line').each do |line|
    	transcript_line = line.css('.caption-line-time').text.gsub("\n", " ") + " " + line.css('.caption-line-text').text.gsub("\n", " ")
    	transcript_arr << transcript_line
    end

    parsed_transcript = transcript_arr.to_json

    file_name = arg[arg.rindex("=") + 1, arg.size] + "-transcript.txt"
    puts "TRANSCRIPT-SUCCESS (#{file_name})"
    return parsed_transcript
    # if File.write(file_name, parsed_transcript)

  rescue Exception => e
    puts e
    puts "ERROR: No transcript available"
  end

  driver.quit
  return "No transcript error."
end

def send_post(hash)
  uri = URI('http://45.55.245.215:80/links/new')
  http = Net::HTTP.new(uri.host, uri.port)
  req = Net::HTTP::Post.new(uri.path, initheader = {'Content-Type' =>'application/json'})
  req.body = hash.to_json
  puts req.body
  res = http.request(req)
  puts "response #{res.body}"
end

scheduler = Rufus::Scheduler.new
scheduler.every '10s' do
  # do something in 10 days
  puts "Scheduler"
  if work_queue.count == 0
    puts "Starting..."
    start()
  end
end
scheduler.join
