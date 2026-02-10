# frozen_string_literal: true

module Brevo
  module Extras
    class Base
      class << self
        def call(params)
          new(params).call
        end
      end

      def initialize(params)
        @params = params
      end

      def call
        raise NotImplementedError, "Subclasses must implement #call"
      end

      protected

      def send_email(template_id:, to:, reply_to: nil)
        data = build_email_data(template_id:, to:, reply_to:)
        data[:to] = safe_mode_recipients(data[:to])
        data[:headers] = { "X-Sib-Sandbox" => "drop" } if sandbox_mode?
        deliver_later(data)
      end

      private

      def build_email_data(template_id:, to:, reply_to:)
        {
          templateId: template_id,
          to: to,
          replyTo: reply_to,
          params: @params
        }.tap do |data|
          data.delete(:replyTo) if reply_to.nil?
        end
      end

      def safe_mode_recipients(recipients)
        return recipients unless safe_mode?

        recipients = recipients.is_a?(Array) ? recipients : [ recipients ]
        recipients.select do |recipient|
          email = recipient[:email].to_s.gsub(/\s/, "").downcase
          safe_mode_domains.any? { |domain| email.end_with?("@#{domain}") }
        end
      end

      def sandbox_mode?
        ActiveModel::Type::Boolean.new.cast(
          ENV.fetch("BREVO_SANDBOX_MODE", "1")
        )
      end

      def safe_mode_domains
        ENV.fetch("BREVO_SAFE_MODE_ALLOWED_DOMAINS", "").split(",").map(&:strip)
      end

      def safe_mode?
        ActiveModel::Type::Boolean.new.cast(
          ENV.fetch("BREVO_SAFE_MODE", "1")
        ) || Rails.env.local?
      end

      def deliver_later(data)
        DeliveryJob.perform_later(data)
      end
    end
  end
end
