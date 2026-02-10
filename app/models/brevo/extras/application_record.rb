module Brevo
  module Extras
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
    end
  end
end
