# frozen_string_literal: true

RSpec.describe Karafka::CodeReloader do
  subject(:reloader) { described_class.new(code_reloader) }

  describe '#on_connection_listener_fetch_loop' do
    context 'when we have Rails reloaders' do
      let(:code_reloader) do
        ClassBuilder.build do
          attr_reader :executed

          def initialize
            @executed = false
          end

          def execute
            @executed = true
          end

          def updated?
            true
          end
        end.new
      end

      it 'expect to be executed' do
        expect { reloader.on_connection_listener_fetch_loop(nil) }
          .to change(code_reloader, :executed)
          .to(true)
      end
    end

    context 'when we have Zeitwerk reloader' do
      let(:code_reloader) do
        ClassBuilder.build do
          attr_reader :reloaded

          def initialize
            @reloaded = false
          end

          def reload
            @reloaded = true
          end
        end.new
      end

      it 'expect to be reloaded' do
        expect { reloader.on_connection_listener_fetch_loop(nil) }
          .to change(code_reloader, :reloaded)
          .to(true)
      end
    end
  end
end
