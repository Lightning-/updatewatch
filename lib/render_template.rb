require "erb"



def render_template(template, tvars)
	if File.readable?("templates/%s.erb" % template)
		ERB.new(File.read("templates/%s.erb" % template, mode: "rt"), trim_mode: "-").result_with_hash(tvars)
	else
		puts "ERROR: template file 'templates/%s.erb' not readable" % template
		exit 2
	end
end
