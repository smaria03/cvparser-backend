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

  path '/api/cvs/{id}/extract_summary' do
    get 'Extract structured summary from a CV PDF' do
      tags 'CVs'
      produces 'application/json'
      parameter name: :id, in: :path, type: :string, required: true, description: 'CV ID'

      response '200', 'Summary extracted successfully' do
        let(:id) do
          cv = CvUpload.create!
          cv.file.attach(
            io: Rails.root.join('spec/fixtures/files/sample_cv.pdf').open,
            filename: 'sample_cv.pdf',
            content_type: 'application/pdf'
          )
          cv.id
        end

        schema type: :object,
               properties: {
                 name: { type: :string },
                 email: { type: :string },
                 experiences: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       job_details: { type: :string },
                       period: { type: :string }
                     }
                   }
                 },
                 current_job: {
                   type: :object,
                   nullable: true,
                   properties: {
                     job_details: { type: :string },
                     period: { type: :string }
                   }
                 },
                 total_experience_years: { type: :string },
                 skills: { type: :string }
               }

        run_test!
      end

      response '404', 'CV not found' do
        let(:id) { 'invalid' }

        run_test!
      end
    end
  end

  path '/api/cvs/{id}/extract_text' do
    get 'Extract raw text from a CV PDF' do
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

        schema type: :object,
               properties: {
                 text: { type: :string }
               }

        run_test!
      end

      response '404', 'CV not found' do
        let(:id) { 'invalid' }
        run_test!
      end
    end
  end

  path '/api/cvs/{id}/extract_sections' do
    get 'Extract structured sections from a CV PDF' do
      tags 'CVs'
      produces 'application/json'
      parameter name: :id, in: :path, type: :string, required: true, description: 'CV ID'

      response '200', 'Sections extracted successfully' do
        let(:id) do
          cv = CvUpload.create!
          cv.file.attach(
            io: Rails.root.join('spec/fixtures/files/sample_cv.pdf').open,
            filename: 'sample_cv.pdf',
            content_type: 'application/pdf'
          )
          cv.id
        end

        schema type: :object,
               properties: {
                 section_hint: {
                   type: :object,
                   nullable: true,
                   properties: {
                     text: { type: :string },
                     font: { type: :integer }
                   }
                 },
                 font_id: { type: :integer, nullable: true },
                 section_blocks: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       title: { type: :string },
                       text_nodes: {
                         type: :array,
                         items: {
                           type: :object,
                           properties: {
                             text: { type: :string },
                             top: { type: :integer },
                             left: { type: :integer },
                             font: { type: :integer }
                           }
                         }
                       }
                     }
                   }
                 }
               }

        run_test!
      end

      response '404', 'CV not found' do
        let(:id) { 'invalid' }
        run_test!
      end
    end
  end

  path '/api/cvs/save_to_sheet' do
    post 'Save extracted CV summary to Google Sheets' do
      tags 'CVs'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :summary, in: :body, required: true, schema: {
        type: :object,
        properties: {
          summary: {
            type: :object,
            required: %w[name email total_experience_years applied_for sheet],
            properties: {
              name: { type: :string, example: 'Maria Silaghi' },
              email: { type: :string, example: 'smaria.oana@yahoo.com' },
              total_experience_years: { type: :string, example: '2.5y' },
              applied_for: {
                type: :string,
                example: 'Internship',
                enum: ['Full Stack Software Engineer', 'Internship', 'QA']
              },
              sheet: {
                type: :string,
                example: 'Internship',
                description: 'The name of the sheet where the row should be saved'
              }
            }
          }
        }
      }

      response '200', 'Saved to Google Sheets successfully' do
        before do
          allow_any_instance_of(GoogleSheetsWriter)
            .to receive(:append_row)
                  .and_return(true)
        end
        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        example 'application/json', :success_example, {
          message: 'Saved to Google Sheets successfully'
        }
        let(:summary) do
          {
            summary: {
              name: 'Maria Silaghi',
              email: 'smaria.oana@yahoo.com',
              total_experience_years: '2.5y',
              applied_for: 'Internship',
              sheet: 'Internship'
            }
          }
        end

        run_test!
      end

      response '422', 'Validation failed' do
        before do
          allow_any_instance_of(GoogleSheetsWriter)
            .to receive(:append_row)
                  .and_raise(ArgumentError, 'Sheet does not exist.')
        end
        schema type: :object,
               properties: {
                 error: { type: :string }
               },
               required: ['error']

        example 'application/json', :invalid_job_example, {
          error: 'Invalid job title'
        }

        example 'application/json', :invalid_sheet_example, {
          error: 'Sheet does not exist.'
        }

        let(:summary) do
          {
            summary: {
              name: 'Maria Silaghi',
              email: 'smaria.oana@yahoo.com',
              total_experience_years: '2.5y',
              applied_for: 'InvalidRole',
              sheet: 'DoesNotExist'
            }
          }
        end

        run_test!
      end
    end
  end

  path '/api/cvs/sheets' do
    get 'List available sheets' do
      tags 'CVs'
      produces 'application/json'

      response '200', 'Sheets listed successfully' do
        before do
          allow_any_instance_of(GoogleSheetsWriter)
            .to receive(:list_sheets)
                  .and_return(['Internship', 'QA', 'Full Stack Software Engineer'])
        end
        schema type: :object,
               properties: {
                 sheets: {
                   type: :array,
                   items: { type: :string }
                 }
               }

        run_test!
      end
    end
  end
end
