Rails.application.routes.draw do

  mount ResqueWeb::Engine => "/resque_web"
end
