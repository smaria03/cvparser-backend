class AddGoogleDriveFileIdToCvUploads < ActiveRecord::Migration[6.1]
  def change
    add_column :cv_uploads, :google_drive_file_id, :string
  end
end
