# frozen_string_literal: true

# For development and test we can raise an error
Karafka.env = 'test'

detected = false

begin
  setup_karafka do |config|
    config.license.token = <<~TOKEN
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
rescue Karafka::Errors::ExpiredLicenseTokenError
  detected = true
end

assert detected
