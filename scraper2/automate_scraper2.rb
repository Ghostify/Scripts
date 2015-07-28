
# phantomjs --webdriver=9999 --ignore-ssl-errors=true

require "uri"
require "net/http"
require 'httparty'
require 'json'
require 'rufus-scheduler'
require 'open-uri'
require 'nokogiri'
require_relative '../management.rb'
require 'colorize'

# bin/phantomjs --webdriver=9999
# jobs -p | xargs kill -9

require 'selenium-webdriver'

@mgt = Management.new(ARGV[0])
puts @mgt.inspect

hash = {}
work_queue = []

def start
  response = HTTParty.get(@mgt.get_links_url, timeout: 10)
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

def ensure_phantom
  cmd = `pgrep phantomjs`
  if cmd != ""
    return true
  else
    return false
  end
end


def execute_scraping (array)
  count = 0
  if not ensure_phantom
    puts `phantomjs --webdriver=9999 --ignore-ssl-errors=true &`
  end

  while (count < array.length)
    full_link = array[count]["full_link"]
    short_link = array[count]["youtube_link"]

    puts "Scraping (#{ (count + 1) }/#{array.count}) #{full_link}"
    result = execute_scraper2(full_link, short_link)

    count = count + 1
    if result["transcript"] != nil and result["details"] != nil
      send_post(result)
    end
  end
  return true
end

def execute_scraper2(full_link, short_link)
  hash = {}
  hash["transcript"] = get_captions(full_link, short_link)
  hash["full_link"] = full_link
  if hash["transcript"] != "" or hash["transcript"] != nil
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
    puts e.backtrace.red
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
  puts "Link: (#{link})".yellow

  # PhantomJS server
  total = ""
  driver = Selenium::WebDriver.for(:remote, :url => "http://localhost:9999")
  driver.manage.window.resize_to 1280, 800
  wait = Selenium::WebDriver::Wait.new(:timeout => 8) # seconds

  begin
    driver.navigate.to link
    driver.save_screenshot("pics/TO LINK-error.png")
    overflow_button = wait.until { driver.find_element(:id, 'action-panel-overflow-button') }
    driver.save_screenshot("pics/CLICK MORE-error.png")
    overflow_button.click
    driver.save_screenshot("pics/CLICKED MORE-error.png")

    transcript_button = driver.find_element(:class, 'action-panel-trigger-transcript')
    driver.save_screenshot("pics/ALMOST TRANS-error.png")
    transcript_button.click
    driver.save_screenshot("pics/CLICKED TRANS-error.png")

    # wait for at least one transcript line
    wait.until { driver.find_element(:id => 'cp-1') }
    driver.save_screenshot("pics/DONE WAITING FOR CP1-error.png")
    transcript_container = driver.find_element(:id, 'transcript-scrollbox')
    cc = Nokogiri::HTML(transcript_container.attribute('innerHTML'))

    cc.css('.caption-line').each do |line|
    	transcript_line = line.css('.caption-line-time').text.gsub("\n", " ") + " " + line.css('.caption-line-text').text.gsub("\n", " ") + " "
    	total += transcript_line
    end
    update_link(short_link, "transcript-success")
  rescue Exception => e
    puts e.message.red
    e = e.message
    if e.include? "action-panel-trigger-transcript"         # No transcript
      update_link(short_link, "transcript-unavailable")
    elsif e.include? "action-panel-overflow-button"         # Cant click button
      update_link(short_link, "button-unavailable")
    elsif e.include? "transcript-scrollbox"                 # Cant find scroll box
      update_link(short_link, "transcript-box-unavailable")
      driver.save_screenshot("pics/#{short_link}-box-error.png")
    elsif e.include? "manipulated"                # Something is not visible
      update_link(short_link, "transcript-action-failed")
      driver.save_screenshot("pics/#{short_link}-notvisible-error.png")
    elsif e.include? "id 'cp-1'"
      update_link(short_link, "transcript-cp1-unavailable")
      # driver.save_screenshot("#{short_link}-cp1-error.png")
    else
      update_link(short_link, "scraping-failed")
    end
  ensure
    driver.quit
  end

  return total
end

def update_link(short_link, progress)
  update_url = @mgt.update_link_progress + "?youtube=" + short_link + "&progress=" + progress
  res = HTTParty.post(update_url)
  puts "Response: #{res.to_s.green}"
  return res
end

def send_post(hash)
  uri = URI(@mgt.post_video_url)
  http = Net::HTTP.new(uri.host, uri.port)
  req = Net::HTTP::Post.new(uri.path, initheader = {'Content-Type' =>'application/json'})
  req.body = hash.to_json
  res = http.request(req)
  puts "Response: #{res.body}".green
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
    #
      puts "Start exeption: #{[e.backtrace, e.message, e.class].join("\n")}".red
    end
  end
  sleep(5)
end
