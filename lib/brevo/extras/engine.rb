module Brevo
  module Extras
    class Engine < ::Rails::Engine
      isolate_namespace Brevo::Extras
    end
  end
end
