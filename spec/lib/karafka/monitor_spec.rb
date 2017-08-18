# frozen_string_literal: true

RSpec.describe Karafka::Monitor do
  subject(:monitor) { described_class.instance }

  MonitorWithSuper = ClassBuilder.inherit(described_class) do
    def notice(klass, options)
      super
    end
  end

  describe '#notice' do
    let(:options) { { rand => rand } }
    let(:caller_label) { 'block (3 levels) in <top (required)>' }
    let(:called_label_jruby) { 'block in (root)' }

    it 'expect to log a proper info' do
      label = jruby? ? called_label_jruby : caller_label

      expect(Karafka.logger)
        .to receive(:info)
        .with("#{self.class}##{label} with #{options}")

      monitor.notice self.class, options
    end
  end

  describe '#notice_error' do
    let(:error) { StandardError }

    [
      Karafka::Connection::MessagesProcessor,
      Karafka::Connection::Listener,
      Karafka::Params::Params
    ].each do |caller_class|
      context "when caller class is #{caller_class}" do
        it 'expec to log with error' do
          expect(Karafka.logger).not_to receive(:info)
          expect(Karafka.logger).to receive(:error).with(error)
          monitor.notice_error(caller_class, error)
        end
      end
    end

    [
      Karafka::Fetcher
    ].each do |caller_class|
      context "when caller class is #{caller_class}" do
        it 'expec to log with fatal' do
          expect(Karafka.logger).not_to receive(:info)
          expect(Karafka.logger).to receive(:fatal).with(error)
          monitor.notice_error(caller_class, error)
        end
      end
    end

    context 'any other class' do
      it 'expec to log with info' do
        expect(Karafka.logger).to receive(:info).with(error)
        monitor.notice_error(Karafka, error)
      end
    end
  end

  describe '#caller_label' do
    it { expect(monitor.send(:caller_label)).to eq 'instance_exec' }

    context 'when it is called from the base monitor' do
      let(:monitor_runner) do
        ClassBuilder.build do
          def check
            Karafka::Monitor.instance.notice(self.class, 'test')
          end
        end
      end

      it 'expect logger to receive proper details with caller_label' do
        expect(Karafka.logger)
          .to receive(:info)
          .with("#{monitor_runner}#check with test")

        monitor_runner.new.check
      end
    end

    context 'when is is called from subclass' do
      let(:monitor_runner) do
        ClassBuilder.build do
          def check
            ClassBuilder.inherit(Karafka::Monitor).instance.notice(self.class, 'test')
          end
        end
      end

      it 'expect logger to receive proper details with caller_label' do
        expect(Karafka.logger)
          .to receive(:info)
          .with("#{monitor_runner}#check with test")

        monitor_runner.new.check
      end
    end

    context 'when is is called from subclass super' do
      let(:monitor_runner) do
        ClassBuilder.build do
          def check
            MonitorWithSuper.instance.notice(self.class, 'test')
          end
        end
      end

      it 'expect logger to receive proper details with caller_label' do
        expect(Karafka.logger)
          .to receive(:info)
          .with("#{monitor_runner}#check with test")

        monitor_runner.new.check
      end
    end
  end

  describe '#logger' do
    it 'expect to return logger' do
      expect(monitor.send(:logger)).to eq Karafka.logger
    end
  end

  describe '#caller_exceptions_map' do
    it { expect(monitor.send(:caller_exceptions_map).keys).to eq %i[error fatal] }

    let(:error_callers) do
      [
        Karafka::Connection::MessagesProcessor,
        Karafka::Connection::Listener,
        Karafka::Params::Params
      ]
    end

    let(:fatal_callers) do
      [
        Karafka::Fetcher
      ]
    end

    it 'expect to have proper classes on error' do
      expect(monitor.send(:caller_exceptions_map)[:error]).to eq error_callers
    end

    it 'expect to have proper classes on fatal' do
      expect(monitor.send(:caller_exceptions_map)[:fatal]).to eq fatal_callers
    end
  end
end
