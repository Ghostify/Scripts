require 'httparty'
require 'json'
require 'rufus-scheduler'
require 'open-uri'
require 'nokogiri'
require_relative '../management.rb'

@mgt = Management.new(ARGV[0])
puts @mgt.inspect

work_queue = []
def start
  response = HTTParty.get(@mgt.get_channels_url)
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

def upload_links(data)
    base_link_url = "#{@mgt.post_new_link}&full_link="
    data["urls"].each do |url|
      puts post_url = "#{base_link_url}#{url}"
      HTTParty.post(post_url)
    end

    base_channel_url = "#{@mgt.post_new_channel}&url="
    data["ids"].each do |id|
      puts post_url = "#{base_channel_url}#{id}"
      HTTParty.post(post_url)
    end
  # data = JSON.parse(dataAsString)
end

def execute_scraping (array)
  count = 0
  while (count < array.length)
    id = array[count]["url"]
    channel_url = "https://www.youtube.com/channel/#{id}"
    puts "Scraping (#{count+1}/#{array.count}) #{channel_url}"
    result = execute_scraper1(channel_url)
    # puts result
    upload_links(result)
    count = count + 1
  end
  return true
end

def execute_scraper1(link)
  starting_url = link
  channel_ids=[]
  video_urls=[]
  temp=[]
  hold=""
  url_string = ""
  page_source = Nokogiri::HTML(open(starting_url))
  page_source.css("a").each do |url|
  	if url["href"]
  		if url["href"].include? '/watch?v='
  			url_string = url["href"]
  			if url["href"].start_with? '/watch?v='
  				url_string = 'https://www.youtube.com' + url["href"]
  			end
  			video_urls << url_string
  		end
  		if url["href"].include? '/channel/'
  			hold = url["href"].slice(url["href"].index("/channel")..-1)
  			temp = hold.split('/')
  			channel_ids << temp[2]
  		end
  	end
  end
  page_source.css("link").each do |url|
  	if url["href"]
  		if url["href"].include? '/watch?v='
  			url_string = url["href"]
  			if url["href"].start_with? '/watch?v='
  				url_string = 'https://www.youtube.com' + url["href"]
  			end
  			video_urls << url_string
  		end
  		if url["href"].include? '/channel/'
  			hold = url["href"].slice(url["href"].index("/channel")..-1)
  			temp = hold.split('/')
  			channel_ids << temp[2]
  		end
  	end
  end
  page_source.css("span").each do |url|
  	if url["data-channel-external-id"]
  		channel_ids << url["data-channel-external-id"]
  	end
  end
  page_source.css("meta").each do |url|
  	if url["itemprop"]
  		if url["itemprop"].include? "channelId"
  			channel_ids << url["content"]
  		end
  	end
  end
  hash = {}
  hash["urls"] = video_urls.uniq
  hash["ids"] = channel_ids.uniq
  return hash
end

puts @mgt.get_channels_url
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
