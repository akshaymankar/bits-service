require_relative './base'

module BitsService
  module Routes
    class Buildpacks < Base
      put '/buildpacks/:guid' do |guid|
        begin
          uploaded_filepath = upload_params.upload_filepath('buildpack')
          original_filename = upload_params.original_filename('buildpack')
          fail Errors::ApiError.new_from_details('BuildpackBitsUploadInvalid', 'a file must be provided') if uploaded_filepath.to_s == ''

          buildpack_blobstore.cp_to_blobstore(uploaded_filepath, guid)

          status 201
        ensure
          FileUtils.rm_f(uploaded_filepath) if uploaded_filepath
        end
      end

      get '/buildpacks/:guid' do |guid|
        blob = buildpack_blobstore.blob(guid)
        fail Errors::ApiError.new_from_details('NotFound', guid) unless blob

        if buildpack_blobstore.local?
          if use_nginx?
            return [200, { 'X-Accel-Redirect' => blob.internal_download_url }, nil]
          else
            return send_file blob.local_path
          end
        else
          return [302, { 'Location' => blob.public_download_url }, nil]
        end
      end

      delete '/buildpacks/:guid' do |guid|
        blob = buildpack_blobstore.blob(guid)
        fail Errors::ApiError.new_from_details('NotFound', guid) unless blob
        buildpack_blobstore.delete_blob(blob)
        status 204
      end
    end
  end
end
