require_relative './base'
require 'fileutils'

module BitsService
  module Routes
    class AppStash < Base
      post '/app_stash/entries' do
        uploaded_filepath = upload_params.upload_filepath('application')
        fail Errors::ApiError.new_from_details(
          'AppBitsUploadInvalid',
          'missing key `application`') unless uploaded_filepath

        destination_path = Dir.mktmpdir('app_stash')

        begin
          SafeZipper.unzip!(uploaded_filepath, destination_path)
          app_stash_blobstore.cp_r_to_blobstore(destination_path)
          receipt = Receipt.new(destination_path)

          json 201, receipt.contents
        rescue SafeZipper::Error => e
          fail Errors::ApiError.new_from_details('AppBitsUploadInvalid', e.message)
        ensure
          FileUtils.rm_r(destination_path)
        end
      end

      post '/app_stash/matches' do
        response_payload = request_payload.select do |resource|
          resource.key?('sha1') && app_stash_blobstore.exists?(resource['sha1'])
        end

        json 200, response_payload
      end

      post '/app_stash/bundles' do
        destination_path = Dir.mktmpdir('app_stash')

        request_payload.each do |resource|
          validate_resource!(resource)

          sha1 = resource['sha1']
          fn = resource['fn']
          app_stash_blobstore.download_from_blobstore(sha1, File.join(destination_path, fn))
        end

        output_path = File.join(Dir.mktmpdir('app_stash'), 'bundle.zip')
        SafeZipper.zip(destination_path, output_path)

        status 200
        stream do |out|
          begin
            out << File.open(output_path).read
          ensure
            FileUtils.rm_rf(destination_path)
            FileUtils.rm_rf(output_path)
          end
        end
      end

      private

      def request_payload
        return @request_payload if @request_payload

        @request_payload = JSON.parse request.body.read
        unless @request_payload.is_a?(Array) && !@request_payload.empty?
          fail Errors::ApiError.new_from_details('UnprocessableEntity', 'must be a non-empty array.')
        end

        @request_payload
      rescue JSON::ParserError => e
        fail Errors::ApiError.new_from_details('MessageParseError', e.message)
      end

      def validate_resource!(resource)
        sha1 = resource['sha1']
        unless sha1 && sha1.to_s != ''
          fail Errors::ApiError.new_from_details('UnprocessableEntity', 'key `sha1` missing or empty')
        end

        fn = resource['fn']
        unless fn && fn.to_s != ''
          fail Errors::ApiError.new_from_details('UnprocessableEntity', 'key `fn` missing or empty')
        end

        unless app_stash_blobstore.exists?(sha1)
          fail Errors::ApiError.new_from_details('ResourceNotFound', "#{sha1} not found")
        end
      end
    end
  end
end
