# frozen_string_literal: true

# Karafka::Admin#close is a no-op that exists to normalize the API surface so that callers
# can treat an admin instance like any other closeable resource. This spec verifies that:
# 1. close does not raise on a fresh instance
# 2. close does not raise after performing real operations
# 3. close can be called multiple times safely

setup_karafka

topic_name = DT.topics[0]
Karafka::Admin.create_topic(topic_name, 1, 1)

# Test 1: close on a fresh instance
admin = Karafka::Admin.new
begin
  admin.close
  DT[:results] << { test: :close_fresh_instance, success: true }
rescue => e
  DT[:results] << { test: :close_fresh_instance, success: false, error: e.message }
end

# Test 2: close after performing operations
admin = Karafka::Admin.new
admin.topic_info(topic_name)
admin.cluster_info

begin
  admin.close
  DT[:results] << { test: :close_after_operations, success: true }
rescue => e
  DT[:results] << { test: :close_after_operations, success: false, error: e.message }
end

# Test 3: close called multiple times on the same instance
admin = Karafka::Admin.new
begin
  3.times { admin.close }
  DT[:results] << { test: :close_idempotent, success: true }
rescue => e
  DT[:results] << { test: :close_idempotent, success: false, error: e.message }
end

assert_equal 3, DT[:results].size

DT[:results].each do |result|
  assert result[:success], "#{result[:test]} failed: #{result[:error]}"
end
