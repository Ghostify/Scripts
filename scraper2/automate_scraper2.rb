
# phantomjs --webdriver=9999
require "uri"
require "net/http"
require 'httparty'
require 'json'
require 'rufus-scheduler'
require 'open-uri'
require 'nokogiri'
require_relative '../management.rb'

# bin/phantomjs --webdriver=9999
# jobs -p | xargs kill -9

require 'selenium-webdriver'

@mgt = Management.new(ARGV[0])
puts @mgt.inspect

hash = {}
work_queue = []

def start
  response = HTTParty.get(@mgt.get_links_url)
  if response.code == 200
    body = response.body
    work_queue = JSON.parse(body)
    puts "Queue: #{work_queue}"

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
    short_link = array[count]["youtube_link"]

    puts "Scraping (#{ (count + 1) }/#{array.count}) #{full_link}"
    puts result = execute_scraper2(full_link, short_link)
    count = count + 1
    if result.has_key?("transcript") and result.hash_key?("details")
      send_post(result)
    end
  end
  return true
end

def execute_scraper2(full_link, short_link)
  hash = {}
  hash["transcript"] = get_captions(full_link, short_link)
  hash["full_link"] = full_link
  if hash["transcript"] != ""
    hash["details"] = getDetails(full_link, short_link)
  end
  return hash
end

def getDetails(full_link, short_link)
  begin
    hash = {}
    page = Nokogiri::HTML(open(full_link))
    hash["views"] = page.css(".watch-view-count").inner_html.gsub!(',','').to_i
    hash["thumbnail"] = page.css("link[itemprop=thumbnailUrl]").first.attributes["href"].value
    hash["title"] = page.css("#eow-title").inner_html.to_s.strip
    hash["owner"] = page.css(".yt-user-info > a").inner_html.to_s
    update_link(short_link, "details-success")
    return hash
  rescue Exception => e
    update_link(short_link, "details-failed")
    return hash
  end
end

def get_captions(full_link, short_link)
  # supply video ID or full YouTube URL from command line
  arg = full_link
  if arg =~ /^#{URI::regexp}$/
    link = arg
  else
    link = "http://www.youtube.com/watch?v=#{arg}"
  end
  puts "Link: (#{link})"

  # PhantomJS server
  driver = Selenium::WebDriver.for(:remote, :url => "http://localhost:9999")
  wait = Selenium::WebDriver::Wait.new(:timeout => 10) # seconds
  total = ""
  begin
    driver.navigate.to link
    overflow_button = driver.find_element(:id, 'action-panel-overflow-button')
    overflow_button.click
    transcript_button = driver.find_element(:class, 'action-panel-trigger-transcript')
    transcript_button.click

    # wait for at least one transcript line
    wait.until { driver.find_element(:id => 'cp-1') }
    transcript_container = driver.find_element(:id, 'transcript-scrollbox')
    cc = Nokogiri::HTML(transcript_container.attribute('innerHTML'))

    cc.css('.caption-line').each do |line|
    	transcript_line = line.css('.caption-line-time').text.gsub("\n", " ") + " " + line.css('.caption-line-text').text.gsub("\n", " ") + " "
    	total += transcript_line
    end
    update_link(short_link, "transcript-success")
  rescue Exception => e
    # driver.save_screenshot("#{link.split("=").last}.png")
    puts "Exception: #{e}"
    if e["errorMessage"].include? "action-panel-trigger-transcript"
      update_link(short_link, "transcript-unavailable")
    elsif e["errorMessage"].include? "action-panel-overflow-button"
      update_link(short_link, "button-unavailable")
    elsif e["errorMessage"].include? "transcript-scrollbox"
      update_link(short_link, "transcript-box-unavailable")
    else
      update_link(short_link, "scraping-failed")
    end
  end
  driver.quit
  return total
end

def update_link(short_link, progress)
  update_url = @mgt.update_link_progress + "?youtube=" + short_link + "&progress=" + progress
  return HTTParty.post(update_url)
end

def send_post(hash)
  uri = URI(@mgt.post_video_url)
  http = Net::HTTP.new(uri.host, uri.port)
  req = Net::HTTP::Post.new(uri.path, initheader = {'Content-Type' =>'application/json'})
  req.body = hash.to_json
  puts req.body
  res = http.request(req)
  puts "Response: #{res.body}"
end

# arg = ARGV[0]
# if arg
#   puts "Using command line argument (#{arg})"
#   puts "Results: #{get_captions(arg)}"
# else
while (true)
  if work_queue.count == 0
    puts "Working queue is empty... acquiring."
    begin
      start()
    rescue Exception => e
      puts "Start exeption: #{e.backtrace}"
    end
  end
  sleep(5)
end
