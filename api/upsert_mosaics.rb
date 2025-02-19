#!/usr/bin/env ruby

# frozen_string_literal: true

# ==================================================================
# A Ruby example that demonstrates the workflow for uploading a
# mosaic to Sentera's FieldAgent platform using the
# upsert_mosaics GraphQL mutation.
#
# Contact devops@sentera.com with any questions.
# ==================================================================

require '../utils/utils'
verify_ruby_version

require 'net/http'
require 'json'
require 'digest'
require 'time'

# If you want to debug this script, run the following gem install
# commands. Then uncomment the require statements below, and put
# debugger statements in the code to trace the code execution.
#
# > gem install pry
# > gem install pry-byebug
#
# require 'pry'
# require 'pry-byebug'

#
# This method demonstrates how to use the create_file_uploads
# mutation in Sentera's GraphQL API to prepare files for
# upload to Sentera's cloud storage.
#
# @param [string] file_path Path to file
# @param [string] survey_sentera_id Sentera ID of the survey
#                                   within FieldAgent that will
#                                   be the parent of the mosaic.
#
# @return [Hash] Hash containing results of the GraphQL request
#
def create_file_upload(file_path, survey_sentera_id)
  puts 'Create file upload'

  gql = <<~GQL
    mutation CreateFileUpload(
      $byte_size: BigInt!
      $checksum: String!
      $content_type: String!
      $filename: String!
      $file_upload_owner: FileUploadOwnerInput
    ) {
      create_file_upload(
        byte_size: $byte_size
        checksum: $checksum
        content_type: $content_type
        filename: $filename
        file_upload_owner: $file_upload_owner
        ) {
        id
        headers
        upload_url
      }
    }
  GQL

  variables = {
    byte_size: File.size(file_path),
    checksum: Digest::MD5.base64digest(File.read(file_path)),
    content_type: 'image/tiff',
    filename: File.basename(file_path),
    file_upload_owner: {
      owner_type: 'MOSAIC',
      parent_sentera_id: survey_sentera_id
    }
  }

  response = make_graphql_request(gql, variables)
  json = JSON.parse(response.body)
  json.dig('data', 'create_file_upload')
end

#
# This method demonstrates how to upload a file to
# Sentera's cloud storage using the URL and headers
# that were retrieved via the create_file_upload
# GraphQL mutation.
#
# @param [Object] file_upload FileUpload GraphQL
#                        object created by the
#                        create_file_upload mutation
# @param [string] file_path Path of the file to upload
#
# @return [void]
#
def upload_file(file_upload, file_path)
  puts 'Upload file'

  uri = URI(file_upload['upload_url'])
  file_contents = File.read(file_path)
  Net::HTTP.start(uri.host) do |http|
    puts "Upload #{file_path} to S3"
    response = http.send_request('PUT',
                                  uri,
                                  file_contents,
                                  file_upload['headers'])
    puts "Done uploading #{file_path}, response.code = #{response.code}"
  end
end

#
# This method demonstrates how to use the ID of the file that
# was previously uploaded to Sentera's cloud storage with the
# upsert_mosaics GraphQL mutation, to attach the files to
# a mosaic.
#
# @param [string] mosaic_sentera_id ID of the mosaic to upsert
# @param [string] survey_sentera_id Sentera ID of the survey
#                                   within FieldAgent that is
#                                   the parent of the mosaic
# @param [Object] file_upload FileUpload GraphQL object created
#                             by the create_file_upload mutation
#
# @return [Hash] Hash containing results of the GraphQL request
#
def upsert_mosaic(mosaic_sentera_id:, survey_sentera_id:, file_upload:)
  puts 'Upsert mosaic'

  gql = <<~GQL
    mutation UpsertMosaic(
      $survey_sentera_id: ID!
      $mosaics: [MosaicImport!]!
    ) {
      upsert_mosaics(
        survey_sentera_id: $survey_sentera_id
        mosaics: $mosaics
      ) {
        succeeded {
          ... on Mosaic {
            sentera_id
          }
        }
        failed {
          attributes {
            key
            details
            attribute
          }
        }
      }
    }
  GQL

  variables = {
    survey_sentera_id: survey_sentera_id,
    mosaics: [
      {
        sentera_id: mosaic_sentera_id,
        quality: 'FULL',
        mosaic_type: 'RGB',
        captured_at: Time.now.iso8601,
        file_keys: [ file_upload['id'] ]
      }
    ]
  }

  response = make_graphql_request(gql, variables)
  json = JSON.parse(response.body)
  json.dig('data', 'upsert_mosaics')
end

# MAIN

# **************************************************
# Set these variables based on the file you want to
# upload and the survey within FieldAgent to which
# you want to attach a mosaic
file_path = ENV.fetch('FILE_PATH', '../test_files/test.tif') # Your fully qualified path to the mosaic file to upload
survey_sentera_id = ENV.fetch('SURVEY_SENTERA_ID', 'sezjmpa_CO_arpmAcmeOrg_CV_deve_b822f1701_230330_110124') # Your survey Sentera ID
# **************************************************

# Step 1: Create a file upload for the mosaic file
file_upload = create_file_upload(file_path, survey_sentera_id)
if file_upload.nil?
  puts 'Failed'
  exit
end
mosaic_sentera_id = file_upload['owner_sentera_id']

# Step 2: Upload the mosaic file
upload_file(file_upload, file_path)

# Step 3: Upsert the mosaic which associates
# the uploaded file with the mosaic record
results = upsert_mosaic(
  mosaic_sentera_id: mosaic_sentera_id,
  survey_sentera_id: survey_sentera_id,
  file_upload: file_upload
)

if results && results['succeeded'].any?
  puts "Done! Mosaic #{mosaic_sentera_id} was created and attached to survey #{survey_sentera_id}."
else
  puts "Failed due to error: #{results['failed'].inspect}"
end
