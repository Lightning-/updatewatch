#!/usr/bin/env ruby

require "optparse"
require_relative "lib/load_config"
require_relative "lib/render_template"



helpme = ARGV.empty? ? true : false



options = {
	query: "default",
	config: "config.yaml",
	project: 11600,
	issuetype: 3
}

oparser = OptionParser.new do |opts|
	opts.on("-h", "--help", "show this help")
	opts.on("-q", "--query STR", String, "query template to use [name] (default: \"default\")")
	opts.on("-b", "--bulk", "create a bulk request (default: false)")
	opts.on("-c", "--config STR", String, "config file to use [path] (default: \"config.yaml\")")
	opts.on("-p", "--project STR", String, "project to create task in [id] (default: 11600)")
	opts.on("-i", "--issuetype INT", Integer, "issue type for the task to use [id] (default: 3)")
	opts.on("-s", "--source STR", String, "source file to work through [path]")
	opts.on("-d", "--description [STR]", String, "task description [text] (don't pass a description to clear config setting)")
	opts.on("-u", "--url [STR]", String, "release notes/news page/changelog/... address [url] (don't pass a url to clear config setting)")
	opts.on("-f", "--filter [STR]", String, "filter tool version to match regex [regex] (don't pass a filter to clear config setting)")
end

oparser.parse!(into: options)



if helpme || options[:help]
	puts oparser
	exit 1
end

unless options.has_key?(:source)
	puts "ERROR: option [-s|--source] is required"
	exit 1
end

unless File.readable?(options[:source])
	puts "ERROR: source file '%s' not readable" % options[:source]
	exit 2
end



yaml = load_config(options[:config])
toolyaml = yaml.filter{|key, value| value.has_key?(:file) && value[:file].eql?(options[:source])}
queries = []



if toolyaml.empty?
	puts "ERROR: no configuration for source file '%s' found in '%s'" % [options[:source], options[:config]]
	exit 3
end



source = load_config(options[:source])
osource = load_config("tmp/%s" % File.basename(options[:source]))
vdiff = source[:versions].to_h.reject{|key, value| osource[:versions].to_h.has_key?(key)}
rdiff = source[:releases].to_h.reject{|key, value| osource[:releases].to_h.has_key?(key)}



toolyaml.each do |tkey, tvalue|
	toolconfig = tvalue.merge(options.reject{|key, value| [:help, :query, :bulk, :config, :source].include?(key)}).compact

	vdiff.each do |dkey, dvalue|
		if toolconfig.has_key?(:filter)
			[toolconfig[:filter]].flatten.each do |filter|
				if dvalue[:name].match?(filter.to_s)
					queries.push("{%s}" % render_template("qry_%s" % options[:query], toolconfig.merge({tool: tkey, version: dvalue[:name]})))
					break
				end
			end
		else
			queries.push("{%s}" % render_template("qry_%s" % options[:query], toolconfig.merge({tool: tkey, version: dvalue[:name]})))
		end
	end

	rdiff.each do |dkey, dvalue|
		queries.push("{%s}" % render_template("qry_%s" % options[:query], toolconfig.merge({tool: tkey, version: dvalue[:name], release: true})))
	end
end

if queries.empty?
	puts "no updates available"
else
	if osource.empty?
		puts queries.first
	else
		if options[:bulk]
			puts "{\"issueUpdates\": [%s]}" % queries.join(",")
		else
			queries.each do |query|
				print "%s\0" % query
			end
		end
	end
end
