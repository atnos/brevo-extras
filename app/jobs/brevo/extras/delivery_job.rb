# frozen_string_literal: true

module Brevo
  module Extras
    class DeliveryJob < ApplicationJob
      retry_on Brevo::ApiError, wait: :polynomially_longer, attempts: 5

      def perform(data)
        api_instance = Brevo::TransactionalEmailsApi.new
        api_instance.send_transac_email(
          Brevo::SendSmtpEmail.new(data)
        )
      end
    end
  end
end
