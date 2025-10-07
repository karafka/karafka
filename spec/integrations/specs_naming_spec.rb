# frozen_string_literal: true

# This spec iterates over all the files in the `spec/integrations` and makes sure, that all
# specs containing specs end with `_spec.rb` to make sure they are executed.
#
# It happened to me few times already, that I would forget about the postfix and the spec would
# not run.

ALLOWED_NAMES = %w[
  Gemfile
  Gemfile.lock
  app.rb
  puma.rb
  assertions.rb
  config.ru
].freeze

# Special cases where multi-file setup was needed
SPECIAL_SPECS = %w[
  routing/consumer_group_reopening_pristine/consumers
  routing/consumer_group_reopening_pristine
].freeze

not_prefixed = []

specs_location = File.join(Karafka.gem_root, 'spec', 'integrations', '**/**')

Dir[specs_location].each do |path|
  next if SPECIAL_SPECS.any? { |spec| path.include?(spec) }
  next unless File.file?(path)
  next if path.end_with?('_spec.rb')

  basename = File.basename(path)

  next if ALLOWED_NAMES.include?(basename)

  not_prefixed << path
end

assert not_prefixed.empty?, not_prefixed
