require "yaml"



def load_config(path)
	File.readable?(path) ? YAML.safe_load(File.read(path, mode: "rt"), aliases: true, fallback: {}, symbolize_names: true) || {} : {}
end
