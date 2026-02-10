Rails.application.routes.draw do
  mount Brevo::Extras::Engine => "/brevo-extras"
end
