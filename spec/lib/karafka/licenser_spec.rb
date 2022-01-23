# frozen_string_literal: true

RSpec.describe_current do
  subject(:verify) { described_class.new.verify(license_config) }

  let(:license_config) { Karafka::App.config.license.dup }

  context 'when there is no license token' do
    before { license_config.token = false }

    it { expect { verify }.not_to raise_error }
    it { expect { verify }.not_to change(license_config, :entity) }
    it { expect { verify }.not_to change(license_config, :expires_on) }
  end

  context 'when token is invalid' do
    before { license_config.token = rand.to_s }

    it { expect { verify }.to raise_error(Karafka::Errors::InvalidLicenseTokenError) }
  end

  context 'when token is valid and expired' do
    let(:expired_token) do
      <<~TOKEN
        i6OS4XMugYjTxPUm4IIjyejEhQXnS/tzz4eSRThV1ebEYLbA6Y1x53XXsbRG
        Zx+DhTdosjH3RFmuy1J9LKVlYBa2WX9QGk6SGxVCCMiLUESnAj0VawsT20o/
        0Z22EFGkgoz9E/t1XdFAmCwYJOrns5tVtFjXIaCnSEaDnweCxLGDrk6fVYfB
        fkemJzii64BwyPlEqehIsbcH0F5rdiTonDJPtIwu36S1nuHCU/C269RQeyMc
        6UQ0n+8YfYJu8QIb5R0rnRiZQwF1jdW8IfjLRuLKi+7HQiNMjbcKoQohufsX
        xhiRyMJjMtRQpkKsFR1wrSaVXVpKMklfagXuwGioqhuy0lzWdAhNg/Vb4asG
        7FP2WbbcKJ44r36LJrHEIX4t1nuy9/Ee8RxTPxFPbEiaauDuSO4Ytzi9OkAC
        pW5tWnTrG9b1ARoS3u6hDo+OmK2t4dmk1x9RolAMUex1lwfP4Jyjj9Ff8a8U
        151nzgnqP3S4mq5zgY7lduowAUaw+wZ6
      TOKEN
    end

    before { license_config.token = expired_token }

    it { expect { verify }.not_to raise_error }
    it { expect { verify }.to change(license_config, :entity).to('CI') }
    it { expect { verify }.to change(license_config, :expires_on).to(Date.parse('2021-01-01')) }

    it 'expect to print an error info' do
      allow(Karafka::App.logger).to receive(:error)
      verify
      expect(Karafka::App.logger).to have_received(:error)
    end
  end
end
