# frozen_string_literal: true

require "test_helper"

class Brevo::Extras::BaseTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # NOTE: Rails.env.local? is true in test env, so safe_mode? is always true.
  # Tests that don't focus on safe mode must set BREVO_SAFE_MODE_ALLOWED_DOMAINS
  # to include the test email domains so recipients pass through.

  class TestMailer < Brevo::Extras::Base
    def call
      send_email(
        template_id: 42,
        to: [{ email: "user@example.com", name: "User" }]
      )
    end
  end

  class TestMailerWithReplyTo < Brevo::Extras::Base
    def call
      send_email(
        template_id: 42,
        to: [{ email: "user@example.com", name: "User" }],
        reply_to: { email: "reply@example.com", name: "Reply" }
      )
    end
  end

  setup do
    @original_env = ENV.to_h.slice(
      "BREVO_SANDBOX_MODE",
      "BREVO_SAFE_MODE",
      "BREVO_SAFE_MODE_ALLOWED_DOMAINS"
    )
  end

  teardown do
    ENV["BREVO_SANDBOX_MODE"] = @original_env["BREVO_SANDBOX_MODE"]
    ENV["BREVO_SAFE_MODE"] = @original_env["BREVO_SAFE_MODE"]
    ENV["BREVO_SAFE_MODE_ALLOWED_DOMAINS"] = @original_env["BREVO_SAFE_MODE_ALLOWED_DOMAINS"]
  end

  # --- .call class method ---

  test ".call instantiates and calls" do
    assert_raises(NotImplementedError) { Brevo::Extras::Base.call(name: "test") }
  end

  test ".call delegates to new(params).call" do
    ENV["BREVO_SANDBOX_MODE"] = "1"
    ENV["BREVO_SAFE_MODE_ALLOWED_DOMAINS"] = "example.com"

    assert_enqueued_with(job: Brevo::Extras::DeliveryJob) do
      TestMailer.call(first_name: "Bruno")
    end
  end

  # --- #call ---

  test "#call raises NotImplementedError on base class" do
    error = assert_raises(NotImplementedError) do
      Brevo::Extras::Base.new({}).call
    end
    assert_equal "Subclasses must implement #call", error.message
  end

  # --- #send_email / #build_email_data ---

  test "send_email builds correct data with template_id, to, and params" do
    ENV["BREVO_SANDBOX_MODE"] = "0"
    ENV["BREVO_SAFE_MODE_ALLOWED_DOMAINS"] = "example.com"

    params = { first_name: "Bruno" }

    performed_args = nil
    Brevo::Extras::DeliveryJob.stub(:perform_later, ->(data) { performed_args = data }) do
      TestMailer.call(params)
    end

    assert_equal 42, performed_args[:templateId]
    assert_equal [{ email: "user@example.com", name: "User" }], performed_args[:to]
    assert_equal({ first_name: "Bruno" }, performed_args[:params])
  end

  test "send_email includes replyTo when reply_to is provided" do
    ENV["BREVO_SANDBOX_MODE"] = "0"
    ENV["BREVO_SAFE_MODE_ALLOWED_DOMAINS"] = "example.com"

    performed_args = nil
    Brevo::Extras::DeliveryJob.stub(:perform_later, ->(data) { performed_args = data }) do
      TestMailerWithReplyTo.call({})
    end

    assert_equal({ email: "reply@example.com", name: "Reply" }, performed_args[:replyTo])
  end

  test "send_email omits replyTo when reply_to is nil" do
    ENV["BREVO_SANDBOX_MODE"] = "0"
    ENV["BREVO_SAFE_MODE_ALLOWED_DOMAINS"] = "example.com"

    performed_args = nil
    Brevo::Extras::DeliveryJob.stub(:perform_later, ->(data) { performed_args = data }) do
      TestMailer.call({})
    end

    assert_not_includes performed_args.keys, :replyTo
  end

  # --- sandbox mode ---

  test "send_email adds sandbox header when BREVO_SANDBOX_MODE is 1" do
    ENV["BREVO_SANDBOX_MODE"] = "1"
    ENV["BREVO_SAFE_MODE_ALLOWED_DOMAINS"] = "example.com"

    performed_args = nil
    Brevo::Extras::DeliveryJob.stub(:perform_later, ->(data) { performed_args = data }) do
      TestMailer.call({})
    end

    assert_equal({ "X-Sib-Sandbox" => "drop" }, performed_args[:headers])
  end

  test "send_email does not add sandbox header when BREVO_SANDBOX_MODE is 0" do
    ENV["BREVO_SANDBOX_MODE"] = "0"
    ENV["BREVO_SAFE_MODE_ALLOWED_DOMAINS"] = "example.com"

    performed_args = nil
    Brevo::Extras::DeliveryJob.stub(:perform_later, ->(data) { performed_args = data }) do
      TestMailer.call({})
    end

    assert_nil performed_args[:headers]
  end

  test "sandbox mode defaults to true when env var is not set" do
    ENV.delete("BREVO_SANDBOX_MODE")
    ENV["BREVO_SAFE_MODE_ALLOWED_DOMAINS"] = "example.com"

    performed_args = nil
    Brevo::Extras::DeliveryJob.stub(:perform_later, ->(data) { performed_args = data }) do
      TestMailer.call({})
    end

    assert_equal({ "X-Sib-Sandbox" => "drop" }, performed_args[:headers])
  end

  # --- safe mode ---

  test "safe mode is always active in local Rails environments" do
    # Rails.env.local? is true in test env, so safe_mode? is true
    # regardless of BREVO_SAFE_MODE setting
    ENV["BREVO_SANDBOX_MODE"] = "0"
    ENV["BREVO_SAFE_MODE"] = "0"
    ENV["BREVO_SAFE_MODE_ALLOWED_DOMAINS"] = "allowed.com"

    mailer_class = Class.new(Brevo::Extras::Base) do
      def call
        send_email(
          template_id: 1,
          to: [{ email: "user@notallowed.com", name: "User" }]
        )
      end
    end

    performed_args = nil
    Brevo::Extras::DeliveryJob.stub(:perform_later, ->(data) { performed_args = data }) do
      mailer_class.call({})
    end

    # Recipients filtered out because safe mode is active via Rails.env.local?
    assert_equal [], performed_args[:to]
  end

  test "safe mode filters recipients to allowed domains" do
    ENV["BREVO_SANDBOX_MODE"] = "0"
    ENV["BREVO_SAFE_MODE"] = "1"
    ENV["BREVO_SAFE_MODE_ALLOWED_DOMAINS"] = "example.com"

    performed_args = nil
    Brevo::Extras::DeliveryJob.stub(:perform_later, ->(data) { performed_args = data }) do
      TestMailer.call({})
    end

    assert_equal [{ email: "user@example.com", name: "User" }], performed_args[:to]
  end

  test "safe mode rejects recipients from non-allowed domains" do
    ENV["BREVO_SANDBOX_MODE"] = "0"
    ENV["BREVO_SAFE_MODE"] = "1"
    ENV["BREVO_SAFE_MODE_ALLOWED_DOMAINS"] = "safe.com"

    mailer_class = Class.new(Brevo::Extras::Base) do
      def call
        send_email(
          template_id: 1,
          to: [
            { email: "user@safe.com", name: "Safe" },
            { email: "user@unsafe.com", name: "Unsafe" }
          ]
        )
      end
    end

    performed_args = nil
    Brevo::Extras::DeliveryJob.stub(:perform_later, ->(data) { performed_args = data }) do
      mailer_class.call({})
    end

    assert_equal [{ email: "user@safe.com", name: "Safe" }], performed_args[:to]
  end

  test "safe mode supports multiple allowed domains" do
    ENV["BREVO_SANDBOX_MODE"] = "0"
    ENV["BREVO_SAFE_MODE"] = "1"
    ENV["BREVO_SAFE_MODE_ALLOWED_DOMAINS"] = "example.com, atnos.com"

    mailer_class = Class.new(Brevo::Extras::Base) do
      def call
        send_email(
          template_id: 1,
          to: [
            { email: "user@example.com", name: "A" },
            { email: "user@atnos.com", name: "B" },
            { email: "user@other.com", name: "C" }
          ]
        )
      end
    end

    performed_args = nil
    Brevo::Extras::DeliveryJob.stub(:perform_later, ->(data) { performed_args = data }) do
      mailer_class.call({})
    end

    assert_equal(
      [{ email: "user@example.com", name: "A" }, { email: "user@atnos.com", name: "B" }],
      performed_args[:to]
    )
  end

  test "safe mode filters out all recipients when no domains are allowed" do
    ENV["BREVO_SANDBOX_MODE"] = "0"
    ENV["BREVO_SAFE_MODE"] = "1"
    ENV["BREVO_SAFE_MODE_ALLOWED_DOMAINS"] = ""

    performed_args = nil
    Brevo::Extras::DeliveryJob.stub(:perform_later, ->(data) { performed_args = data }) do
      TestMailer.call({})
    end

    assert_equal [], performed_args[:to]
  end

  test "safe mode defaults to true when env var is not set" do
    ENV.delete("BREVO_SAFE_MODE")
    ENV["BREVO_SANDBOX_MODE"] = "0"
    ENV["BREVO_SAFE_MODE_ALLOWED_DOMAINS"] = "example.com"

    performed_args = nil
    Brevo::Extras::DeliveryJob.stub(:perform_later, ->(data) { performed_args = data }) do
      TestMailer.call({})
    end

    assert_equal [{ email: "user@example.com", name: "User" }], performed_args[:to]
  end

  # --- deliver_later ---

  test "deliver_later enqueues a DeliveryJob" do
    ENV["BREVO_SANDBOX_MODE"] = "0"
    ENV["BREVO_SAFE_MODE_ALLOWED_DOMAINS"] = "example.com"

    assert_enqueued_with(job: Brevo::Extras::DeliveryJob) do
      TestMailer.call({})
    end
  end
end
