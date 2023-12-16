# frozen_string_literal: true

# This spec iterates over all lib/karafka nested directories and makes sure that each directory
# that would be a module has a module.rb referencing file
#
# In some Ruby versions with certain Bundler and Zeitwerk we get a crash when module file is not
# defined even despite the fact that it should work as expected due to Zeitwerk dynamically
# creating the needed reference.
#
# Since I was not able to figure out exact reason it is better to just follow a convention of
# always having the module.rb file for stability.

# Do it for now for pro
lib_location = File.join(Karafka.gem_root, 'lib', 'karafka', '**/**')

failed = []

EXCLUSIONS = %w[
  karafka/templates
].freeze

Dir[lib_location].each do |path|
  next unless File.directory?(path)

  next if File.exist?("#{path}.rb")
  next if EXCLUSIONS.any? { |exclusion| path.end_with?(exclusion) }

  failed << path
end

assert_equal [], failed, failed
