# frozen_string_literal: true

RSpec.describe_current do
  subject(:lazy_file) { described_class.new(&opener) }

  let(:file) { instance_double(File) }
  let(:opener_calls) { [] }
  # What the opener resolves to (a file or nil when it cannot be opened)
  let(:opened) { file }
  let(:opener) { -> { opener_calls << true and opened } }

  before do
    allow(file).to receive(:write).and_return(10)
    allow(file).to receive(:close)
  end

  describe "#write" do
    it "does not open the underlying file until the first write" do
      lazy_file

      expect(opener_calls).to be_empty
    end

    it "opens the file lazily and writes the message" do
      expect(lazy_file.write("hello")).to eq(10)
      expect(file).to have_received(:write).with("hello")
    end

    it "opens the underlying file only once across multiple writes" do
      lazy_file.write("a")
      lazy_file.write("b")

      expect(opener_calls.size).to eq(1)
      expect(file).to have_received(:write).twice
    end

    context "when the file cannot be opened (opener returns nil)" do
      let(:opened) { nil }

      it "is a no-op and returns nil" do
        expect(lazy_file.write("x")).to be_nil
      end

      it "does not retry opening on subsequent writes" do
        lazy_file.write("a")
        lazy_file.write("b")

        expect(opener_calls.size).to eq(1)
      end
    end

    context "when writing raises a read-only filesystem error" do
      [Errno::EROFS, Errno::EACCES].each do |error|
        context "when it is #{error}" do
          before { allow(file).to receive(:write).and_raise(error) }

          it "does not raise and returns nil" do
            expect { lazy_file.write("x") }.not_to raise_error
            expect(lazy_file.write("x")).to be_nil
          end
        end
      end
    end
  end

  describe "#close" do
    it "does not open the underlying file just to close it" do
      lazy_file.close

      expect(opener_calls).to be_empty
      expect(lazy_file.close).to be_nil
    end

    it "closes the underlying file once it was opened" do
      lazy_file.write("a")
      lazy_file.close

      expect(file).to have_received(:close)
    end

    context "when closing raises a read-only filesystem error" do
      before do
        lazy_file.write("a")
        allow(file).to receive(:close).and_raise(Errno::EROFS)
      end

      it "does not raise" do
        expect { lazy_file.close }.not_to raise_error
      end
    end
  end
end
