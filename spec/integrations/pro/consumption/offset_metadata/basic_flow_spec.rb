# frozen_string_literal: true

# Karafka should be able to get offset metadata when non-existing, save it and force refresh
# with defaults and cache on
#
# @note We use mark_as_consumed! to instantly flush

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT.key?(:after4)

    DT[:before] = offset_metadata

    mark_as_consumed!(messages.last, 'metadata-store1')

    DT[:after1] = offset_metadata
    DT[:after2] = offset_metadata(cache: false)

    # Second write of the same offset will not update the already stored metadata
    # This is expected as offset store with data is immutable
    mark_as_consumed!(messages.last, 'metadata-store2')

    DT[:after3] = offset_metadata
    DT[:after4] = offset_metadata(cache: false)
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:after4)
end

assert_equal '', DT[:before]
assert_equal '', DT[:after1]
assert_equal 'metadata-store1', DT[:after2]
assert_equal 'metadata-store1', DT[:after3]
assert_equal 'metadata-store1', DT[:after4]
