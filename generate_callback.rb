#!/usr/bin/env ruby

require "yaml"
require_relative "lib/render_template"



callback_template = ARGV.shift
results = []



if callback_template.nil?
	puts "ERROR: callback template parameter is required"
	exit 1
end



ARGV.reject{|item| item.empty?}.each do |arg|
	arg.gsub(/\}\s*\{/, "}\n{").each_line(chomp: true) do |line|
		results.push(YAML.safe_load(line, aliases: true, fallback: {}, symbolize_names: true) || {})
	end
end

if results.empty?
	puts "no updates available"
else
	if ENV.has_key?("TBASEURL") && ! ENV["TBASEURL"].empty?
		puts render_template("callback_%s" % callback_template, {results: results, baseurl: ENV["TBASEURL"]})
	else
		puts render_template("callback_%s" % callback_template, {results: results})
	end
end
