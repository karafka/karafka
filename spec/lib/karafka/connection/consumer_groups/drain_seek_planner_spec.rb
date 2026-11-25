# frozen_string_literal: true

RSpec.describe_current do
  subject(:planner) { described_class.new }

  # Builds a buffer from offsets per partition per topic. An empty list of offsets is an eof
  def buffer(groups)
    Karafka::Connection::RawMessagesBuffer.new.tap do |buffer|
      groups.each do |topic_name, partitions|
        partitions.each do |partition, offsets|
          buffer.eof(topic_name, partition) if offsets.empty?

          offsets.each do |offset|
            buffer << build(
              :kafka_fetched_message, topic: topic_name, partition: partition, offset: offset
            )
          end
        end
      end
    end
  end

  def coordinates(seeks)
    seeks.map { |seek| [seek.topic, seek.partition, seek.offset] }
  end

  describe "#rewinds" do
    [
      [
        "nothing was revoked",
        { "a" => { 0 => [1, 2] } }, {}, {},
        []
      ],
      [
        "a partition was revoked and not assigned back",
        { "a" => { 0 => [1, 2] } }, { "a" => [0] }, {},
        []
      ],
      [
        "a partition was assigned without a revocation",
        { "a" => { 0 => [1, 2] } }, {}, { "a" => [0] },
        []
      ],
      [
        "a partition was revoked and assigned back",
        { "a" => { 0 => [1, 2], 1 => [0] } }, { "a" => [0] }, { "a" => [0] },
        [["a", 0, 1]]
      ],
      [
        "a drained message from before the revocation precedes lower ones",
        { "a" => { 0 => [6, 5, 6] } }, { "a" => [0] }, { "a" => [0] },
        [["a", 0, 5]]
      ],
      [
        "only the eof of a partition assigned back was drained",
        { "a" => { 0 => [], 1 => [1] } }, { "a" => [0] }, { "a" => [0] },
        []
      ],
      [
        "the same partition of another topic was revoked and assigned back",
        { "a" => { 0 => [1] }, "b" => { 0 => [3] } }, { "b" => [0] }, { "b" => [0] },
        [["b", 0, 3]]
      ],
      [
        "partitions of several topics were revoked and assigned back",
        { "a" => { 0 => [1] }, "b" => { 1 => [3, 4] } },
        { "a" => [0], "b" => [1] }, { "a" => [0], "b" => [1] },
        [["a", 0, 1], ["b", 1, 3]]
      ]
    ].each do |description, groups, revoked, assigned, expected|
      context "when #{description}" do
        it { expect(coordinates(planner.rewinds(buffer(groups), revoked, assigned))).to eq(expected) }
      end
    end
  end

  describe "#alignments" do
    [
      [
        "nothing was rewound",
        { "a" => { 0 => [1, 2] } }, {},
        []
      ],
      [
        "a partition was rewound",
        { "a" => { 0 => [0, 1], 1 => [5] } }, { "a" => [0] },
        [["a", 0, 2]]
      ],
      [
        "a rewound partition has no messages left in the buffer",
        { "a" => { 1 => [5] } }, { "a" => [0] },
        []
      ],
      [
        "only the eof of a rewound partition is in the buffer",
        { "a" => { 0 => [] } }, { "a" => [0] },
        []
      ],
      [
        "the same partition of another topic was rewound",
        { "a" => { 0 => [7] }, "b" => { 0 => [3] } }, { "b" => [0] },
        [["b", 0, 4]]
      ],
      [
        "two partitions of one topic were rewound",
        { "a" => { 0 => [1], 1 => [3, 4], 2 => [9] } }, { "a" => [0, 1] },
        [["a", 0, 2], ["a", 1, 5]]
      ],
      [
        "partitions of several topics were rewound",
        { "a" => { 0 => [7] }, "b" => { 1 => [3, 4] } }, { "a" => [0], "b" => [1] },
        [["a", 0, 8], ["b", 1, 5]]
      ]
    ].each do |description, groups, rewound, expected|
      context "when #{description}" do
        it { expect(coordinates(planner.alignments(buffer(groups), rewound))).to eq(expected) }
      end
    end
  end
end
