require "yaml"



def load_config(path)
	if File.readable?(path)
		config = YAML.safe_load(File.read(path, mode: "rt"), aliases: true, fallback: {}, symbolize_names: true) || {}
	else
		config = {}
	end

	config
end
