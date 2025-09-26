# frozen_string_literal: true

module GoogleDriveHelpers
  extend ActiveSupport::Concern

  private

  def build_drive_service
    token_store = Google::Auth::Stores::FileTokenStore.new(
      file: Rails.root.join('config/credentials/tokens.yaml')
    )
    client_id = Google::Auth::ClientId.from_file(
      Rails.root.join('config/credentials/oauth_client_secret.json')
    )
    authorizer = Google::Auth::UserAuthorizer
                 .new(client_id, Google::Apis::DriveV3::AUTH_DRIVE_FILE, token_store)
    credentials = authorizer.get_credentials('default')
    raise 'Not authorized with Google' unless credentials

    drive_service = Google::Apis::DriveV3::DriveService.new
    drive_service.authorization = credentials
    drive_service
  end

  def find_or_create_subfolder(service, parent_folder_id, folder_name)
    query = "mimeType = 'application/vnd.google-apps.folder' and name = '#{folder_name}' " \
            "and '#{parent_folder_id}' in parents and trashed = false"
    response = service.list_files(q: query, fields: 'files(id, name)', page_size: 1)

    return response.files.first.id if response.files.any?

    metadata = {
      name: folder_name,
      mime_type: 'application/vnd.google-apps.folder',
      parents: [parent_folder_id]
    }

    folder = service.create_file(metadata, fields: 'id')
    folder.id
  end

  def parse_cv_file(cv_id)
    cv = CvUpload.find_by(id: cv_id)
    if cv&.google_drive_file_id.blank?
      return render json: { error: 'CV not found' },
                    status: :not_found
    end

    drive_service = build_drive_service

    tempfile = Tempfile.new(['cv', '.pdf'], binmode: true)
    begin
      drive_service.get_file(cv.google_drive_file_id, download_dest: tempfile)

      result = yield tempfile
      render json: result
    ensure
      tempfile.close
      tempfile.unlink
    end
  end
end
