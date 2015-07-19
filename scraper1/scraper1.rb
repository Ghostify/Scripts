require 'open-uri'
require 'nokogiri'

starting_url = ARGV[0]
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
return
