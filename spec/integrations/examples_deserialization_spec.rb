# frozen_string_literal: true

# All our examples should be valid.

require 'json'

json_examples = File.join(Karafka.gem_root, 'examples', '**/**/*.json')

Dir[json_examples].each do |example_file|
  puts "Parsing #{example_file}"
  JSON.parse(File.read(example_file))
end
