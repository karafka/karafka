# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# It should not be possible to use same named pattern with different name but same pattern in
# the same consumer group

setup_karafka

guarded = []

begin
  draw_routes(create_topics: false) do
    subscription_group :a do
      pattern('super-name1', /non-existing-ever-na/) do
        consumer Class.new
      end
    end

    subscription_group :b do
      pattern('super-name2', /non-existing-ever-na/) do
        consumer Class.new
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << 1
end

assert_equal [1], guarded
