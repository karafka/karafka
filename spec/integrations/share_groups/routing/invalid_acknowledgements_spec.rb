# frozen_string_literal: true

# The share group (KIP-932) acknowledgements routing settings should be validated: only
# :release, :accept and :reject are accepted for records left unacknowledged, while the valid
# values are applied to the topic.

setup_karafka

Consumer = Class.new(Karafka::ShareConsumer)

[:drop, "accept", nil, true].each do |invalid|
  failed = false

  begin
    draw_routes(create_topics: false) do
      share_group "sg" do
        topic "t" do
          consumer Consumer
          acknowledgements(unacknowledged: invalid)
        end
      end
    end
  rescue Karafka::Errors::InvalidConfigurationError => e
    assert e.message.include?("routes.sg.t.acknowledgements.unacknowledged"), e.message

    failed = true
  end

  assert failed, invalid

  clear_app_draws
end

%i[release accept reject].each do |valid|
  draw_routes(create_topics: false) do
    share_group "sg" do
      topic "t" do
        consumer Consumer
        acknowledgements(unacknowledged: valid)
      end
    end
  end

  topic = Karafka::App.routes.share_groups.first.topics.first

  assert topic.acknowledgements?
  assert_equal valid, topic.acknowledgements.unacknowledged

  clear_app_draws
end

# By default records left unacknowledged are released
draw_routes(create_topics: false) do
  share_group "sg" do
    topic "t" do
      consumer Consumer
    end
  end
end

assert_equal :release, Karafka::App.routes.share_groups.first.topics.first.acknowledgements.unacknowledged
