# frozen_string_literal: true

Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  namespace :api do
    post 'cvs/upload', to: 'cvs#upload'
    delete 'cvs/:id', to: 'cvs#destroy'
    get 'cvs/:id/extract_text', to: 'cvs#extract_text'
  end
end
