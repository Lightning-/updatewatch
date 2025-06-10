#!/usr/bin/env ruby

require "rss"
require "json"



url = ARGV[0].nil? ? nil : ARGV[0]
data = {
	releases: {},
	versions: {}
}



if url.nil?
	puts "ERROR: URL parameter is required"
	exit 1
end



case url
	when %r{\Ahttps?://(?:www\.)?github\.com/(.*)/releases\.atom\z}
		outfile = "feed-data/github.com_%s.json" % $1.downcase.gsub("/", "_")

		begin
			feed = RSS::Parser.parse(url)
		rescue
			nil
		else
			feed.items.each do |item|
				version = item.id.content[%r{\Atag:github\.com.*/v?(.*?)\z}, 1]
				data[:versions][version.to_sym] = {name: version}
			end
		end
end

unless data[:versions].empty? && data[:releases].empty?
	File.open(outfile, "wt") do |file|
		file.puts JSON.pretty_generate(data)
	end
end
