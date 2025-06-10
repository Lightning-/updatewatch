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
	opts.on("-c", "--config STR", String, "config file to use [path] (default: \"config.yaml\")")
	opts.on("-p", "--project STR", String, "project to create task in [id] (default: 11600)")
	opts.on("-i", "--issuetype INT", Integer, "issue type for the task to use [id] (default: 3)")
	opts.on("-t", "--tool STR", String, "tool name [name]")
	opts.on("-v", "--version STR", String, "tool version string [version]")
	opts.on("-r", "--release", "create a release task (default: false)")
	opts.on("-d", "--description [STR]", String, "task description [text] (don't pass a description to clear config setting)")
	opts.on("-u", "--url [STR]", String, "release notes/news page/changelog/... address [url] (don't pass a url to clear config setting)")
end

oparser.parse!(into: options)



if helpme || options[:help]
	puts oparser
	exit 1
end

unless options.has_key?(:tool)
	puts "ERROR: option [-t|--tool] is required"
	exit 1
end

unless options.has_key?(:version)
	puts "ERROR: option [-v|--version] is required"
	exit 1
end



yaml = load_config(options[:config])
toolconfig = yaml[options[:tool].to_sym].to_h.merge(options.reject{|key, value| [:help, :query, :config].include?(key)}).compact
puts "{%s}" % render_template("qry_%s" % options[:query], toolconfig)
