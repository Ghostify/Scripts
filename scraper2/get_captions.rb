# bin/phantomjs --webdriver=9999

require 'selenium-webdriver'
require 'nokogiri'
require 'uri'
require 'json'

# supply video ID or full YouTube URL from command line
arg = ARGV[0]
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

overflow_button = driver.find_element(:id, 'action-panel-overflow-button')
overflow_button.click

begin
  transcript_button = driver.find_element(:class, 'action-panel-trigger-transcript')
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

  begin
    file_name = arg[arg.rindex("=") + 1, arg.size] + "-transcript.txt"
    if File.write(file_name, parsed_transcript)
      puts "TRANSCRIPT-SUCCESS (#{file_name})"
    else
      puts "Error writing"
    end
  rescue IOError => e
    puts "Write failed"
  end
rescue Exception => e
  puts e
  puts "ERROR: No transcript available"
end

driver.quit
