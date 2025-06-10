#!/usr/bin/env ruby

require_relative "lib/load_config"



config = ARGV[0].nil? ? "config.yaml" : ARGV[0]
field = ARGV[1].nil? ? :file : ARGV[1]



load_config(config).filter{|key, value| value.has_key?(field.to_sym)}.each_value{|value| puts value[field.to_sym] unless value[field.to_sym].nil?}
