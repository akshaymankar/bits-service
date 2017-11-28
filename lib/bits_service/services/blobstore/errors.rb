# frozen_string_literal: true

module BitsService
  module Blobstore
    class FileNotFound < StandardError
    end

    class BlobstoreError < StandardError
    end

    class ConflictError < StandardError
    end

    class UnsafeDelete < StandardError
    end

    class SigningRequestError < BlobstoreError
    end
  end
end
