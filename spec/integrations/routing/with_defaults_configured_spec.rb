# frozen_string_literal: true

# Karafka should use the defaults if they were configured but only if the appropriate config
# setup was not executed

setup_karafka

draw_routes(create_topics: false) do
  defaults do
    manual_offset_management false
    config(replication_factor: 2, partitions: 5)
  end

  subscription_group do
    topic 'topic1' do
      consumer Class.new
      dead_letter_queue(topic: 'xyz', max_retries: 2)
      manual_offset_management true
      config(replication_factor: 12, partitions: 15)
    end
  end

  topic 'topic2' do
    consumer Class.new
  end
end

t1 = Karafka::App.consumer_groups.first.topics.first
t2 = Karafka::App.consumer_groups.first.topics.last
t3 = Karafka::App.consumer_groups.last.topics.last

assert t1.dead_letter_queue?
assert t1.manual_offset_management?
assert_equal 12, t1.declaratives.replication_factor
assert_equal 15, t1.declaratives.partitions

assert !t2.dead_letter_queue?
assert !t2.manual_offset_management?
assert_equal 2, t2.declaratives.replication_factor
assert_equal 5, t2.declaratives.partitions

assert !t3.dead_letter_queue?
assert !t3.manual_offset_management?
assert_equal 2, t3.declaratives.replication_factor
assert_equal 5, t3.declaratives.partitions
