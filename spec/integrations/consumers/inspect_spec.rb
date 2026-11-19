# frozen_string_literal: true

# A consumer should be inspectable both before it is attached to a coordinator (when built by hand
# in a console or a spec) and while it consumes, so `p`, IRB and error messages never raise.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:inspect] << inspect
  end
end

unattached = Consumer.new.inspect

assert unattached.include?("topic=nil partition= used=false messages_count= revoked=>")

assert Class.new(Karafka::ShareConsumer).new.inspect.include?("topic=nil partition=")

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT[:inspect].size >= 1
end

assert DT[:inspect].first.include?(%(topic="#{DT.topic}" partition=0 used=true))
assert DT[:inspect].first.include?("revoked=false")
