# frozen_string_literal: true

require "test_helper"

class Brevo::Extras::DeliveryJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @data = {
      templateId: 42,
      to: [{ email: "user@example.com", name: "User" }],
      params: { first_name: "Bruno" }
    }
  end

  test "inherits from ApplicationJob" do
    assert_operator Brevo::Extras::DeliveryJob, :<, Brevo::Extras::ApplicationJob
  end

  test "perform calls Brevo TransactionalEmailsApi with SendSmtpEmail" do
    mock_api = Minitest::Mock.new
    mock_api.expect(:send_transac_email, nil) do |smtp_email|
      smtp_email.is_a?(Brevo::SendSmtpEmail)
    end

    Brevo::TransactionalEmailsApi.stub(:new, mock_api) do
      Brevo::Extras::DeliveryJob.perform_now(@data)
    end

    assert mock_api.verify
  end

  test "perform passes data to SendSmtpEmail" do
    received_data = nil
    mock_api = Minitest::Mock.new
    mock_api.expect(:send_transac_email, nil) do |_smtp_email|
      true
    end

    Brevo::SendSmtpEmail.stub(:new, ->(data) { received_data = data; Brevo::SendSmtpEmail.allocate }) do
      Brevo::TransactionalEmailsApi.stub(:new, mock_api) do
        Brevo::Extras::DeliveryJob.perform_now(@data)
      end
    end

    assert_equal @data, received_data
  end

  test "job is enqueued via perform_later" do
    assert_enqueued_with(job: Brevo::Extras::DeliveryJob) do
      Brevo::Extras::DeliveryJob.perform_later(@data)
    end
  end

  test "retries on Brevo::ApiError" do
    mock_api = Minitest::Mock.new
    mock_api.expect(:send_transac_email, nil) do
      raise Brevo::ApiError, "API failure"
    end

    Brevo::TransactionalEmailsApi.stub(:new, mock_api) do
      assert_enqueued_with(job: Brevo::Extras::DeliveryJob) do
        Brevo::Extras::DeliveryJob.perform_now(@data)
      end
    end
  end

  test "does not retry on StandardError" do
    mock_api = Minitest::Mock.new
    mock_api.expect(:send_transac_email, nil) do
      raise StandardError, "unexpected error"
    end

    Brevo::TransactionalEmailsApi.stub(:new, mock_api) do
      assert_raises(StandardError) do
        Brevo::Extras::DeliveryJob.perform_now(@data)
      end
    end
  end

  test "has Brevo::ApiError in rescue handlers" do
    error_classes = Brevo::Extras::DeliveryJob.rescue_handlers.map(&:first)
    assert_includes error_classes, "Brevo::ApiError"
  end
end
