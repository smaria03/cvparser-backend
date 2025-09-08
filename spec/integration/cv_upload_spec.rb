# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'CV Upload API', type: :request do
  path '/api/cvs/upload' do
    post 'Upload a CV PDF file' do
      tags 'CVs'
      consumes 'multipart/form-data'
      produces 'application/json'

      parameter name: :file, in: :formData, type: :file, required: true,
                description: 'CV file in PDF format'

      response '200', 'CV uploaded successfully' do
        let(:file) do
          fixture_file_upload(
            Rails.root.join('spec/fixtures/files/sample_cv.pdf'),
            'application/pdf'
          )
        end

        run_test!
      end

      response '400', 'no file uploaded' do
        before do |example|
          example.metadata[:operation][:parameters] = []
        end

        run_test!
      end
    end
  end

  path '/api/cvs/{id}' do
    delete 'Delete a CV and its attached file' do
      tags 'CVs'
      produces 'application/json'

      parameter name: :id, in: :path, type: :string, required: true, description: 'CV ID'

      response '200', 'CV deleted successfully' do
        let(:id) do
          cv = CvUpload.create!
          cv.file.attach(
            io: Rails.root.join('spec/fixtures/files/sample_cv.pdf').open,
            filename: 'sample_cv.pdf',
            content_type: 'application/pdf'
          )
          cv.id
        end

        run_test!
      end

      response '404', 'CV not found' do
        let(:id) { 'invalid' }

        run_test!
      end
    end
  end

  path '/api/cvs/{id}/extract_text' do
    get 'Extract raw text from an uploaded CV PDF' do
      tags 'CVs'
      produces 'application/json'
      parameter name: :id, in: :path, type: :string, required: true, description: 'CV ID'

      response '200', 'Text extracted successfully' do
        let(:id) do
          cv = CvUpload.create!
          cv.file.attach(
            io: Rails.root.join('spec/fixtures/files/sample_cv.pdf').open,
            filename: 'sample_cv.pdf',
            content_type: 'application/pdf'
          )
          cv.id
        end

        run_test!
      end

      response '404', 'CV not found' do
        let(:id) { 'invalid' }

        run_test!
      end
    end
  end
end
