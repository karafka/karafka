# frozen_string_literal: true

RSpec.describe Karafka::CodeReloader do
  subject(:reloader) { described_class.new }

  describe '#on_connection_listener_fetch_loop' do
    context 'when we have Rails reloaders' do
      pending
    end

    context 'when we have Zeitwerk reloader' do
      pending
    end
  end
end
