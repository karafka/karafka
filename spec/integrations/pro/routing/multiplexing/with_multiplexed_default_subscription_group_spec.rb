# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should allow for multiplexing of the default anonymous subscription group

setup_karafka do |config|
  config.strict_topics_namespacing = false
end

failed = false

SG_UUID = SecureRandom.uuid

begin
  draw_routes(create_topics: false) do
    subscription_group SG_UUID do
      multiplexing(min: 2, max: 5)

      topic 'namespace_collision' do
        consumer Class.new
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert_equal 5, Karafka::App.routes.first.subscription_groups.size

Karafka::App.routes.first.subscription_groups.each_with_index do |sg, i|
  assert sg.id.include?("#{SG_UUID}_#{i}")
  assert_equal sg.name, SG_UUID
end

assert !failed
