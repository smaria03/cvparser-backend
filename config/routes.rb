# frozen_string_literal: true

Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  namespace :api do
    post 'cvs/upload', to: 'cvs#upload'
    delete 'cvs/:id', to: 'cvs#destroy'
    get 'cvs/:id/extract_text', to: 'cvs#extract_text'
    get 'cvs/:id/extract_sections', to: 'cvs#extract_sections'
    get 'cvs/:id/extract_summary', to: 'cvs#extract_summary'
    post 'cvs/save_to_sheet', to: 'cvs#save_to_sheet'
  end
end
