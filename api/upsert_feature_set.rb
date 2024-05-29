#!/usr/bin/env ruby

# frozen_string_literal: true

# ==================================================================
# A Ruby example that demonstrates the workflow for uploading a
# feature set with annotations to Sentera's FieldAgent platform
# using the upsert_feature_set GraphQL mutation.
#
# Contact devops@sentera.com with any questions.
# ==================================================================

require 'net/http'
require 'json'
require 'digest'
require '../utils/parallel'
require '../utils/utils'

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
# @param [Array[string]] file_paths Array of file paths
# @param [string] survey_sentera_id Sentera ID of the survey
#                                   within FieldAgent that will
#                                   be the parent of the feature
#                                   set.
#
# @return [Hash] Hash containing results of the GraphQL request
#
def create_file_uploads(file_paths, survey_sentera_id)
  puts 'Create file uploads'

  files = file_paths.map do |file_path|
    {
      filename: File.basename(file_path),
      byte_size: File.size(file_path),
      checksum: Digest::MD5.base64digest(File.read(file_path)),
      content_type: 'application/octet-stream'
    }
  end

  gql = <<~GQL
    mutation CreateFileUploads(
      $file_upload_owner: FileUploadOwnerInput,
      $files: [FileUploadInput!]!
    ) {
      create_file_uploads(
        file_upload_owner: $file_upload_owner
        files: $files
      ) {
        id
        headers
        owner_sentera_id
        s3_url
        upload_url
      }
    }
  GQL

  variables = {
    file_upload_owner: {
      owner_type: 'FEATURE_SET',
      parent_sentera_id: survey_sentera_id
    },
    files: files
  }

  response = make_graphql_request(gql, variables)
  json = JSON.parse(response.body)
  json.dig('data', 'create_file_uploads')
end

#
# This method demonstrates how to upload a file to
# Sentera's cloud storage using the URL and headers
# that were retrieved via the create_file_upload
# GraphQL mutation.
#
# @param [Array[Object]] file_uploads FileUpload GraphQL
#                        objects created by the
#                        create_file_uploads mutation
# @param [Array[string]] file_paths Array of paths to
#                        the files to upload
#
# @return [void]
#
def upload_files(file_uploads, file_paths)
  puts 'Upload files'

  file_uploads_map = file_uploads.each_with_object({}) do |file_upload, map|
    s3_url = file_upload['s3_url']
    filename = File.basename(s3_url)
    map[filename] = file_upload
  end

  Parallel.each(file_paths, in_threads: 6) do |file_path|
    filename = File.basename(file_path)
    file_upload = file_uploads_map[filename]

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
end

#
# This method demonstrates how to use the IDs of the files that
# were previously uploaded to Sentera's cloud storage with the
# upsert_feature_set GraphQL mutation, to attach the files to
# a feature set.
#
# @param [string] survey_sentera_id Sentera ID of the survey
#                                   within FieldAgent that is
#                                   the parent of the feature set
# @param [string] feature_set_sentera_id ID of the feature set
#                                        to upsert
# @param [Array[Object]] file_uploads FileUpload GraphQL
#                        objects created by the
#                        create_file_uploads mutation
#
# @return [Hash] Hash containing results of the GraphQL request
#
def upsert_feature_set(geometry:, feature_set_sentera_id:, survey_sentera_id:, file_uploads:)
  puts 'Upsert feature set'

  gql = <<~GQL
    mutation UpsertFeatureSet(
      $feature_set: FeatureSetImport!
      $owner: FeatureSetOwnerInput!
    ) {
      upsert_feature_set(
        feature_set: $feature_set
        owner: $owner
      ) {
        succeeded {
          ... on FeatureSet {
            sentera_id
            name
            type
            status
            released
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
    owner: {
      owner_type: 'SURVEY',
      sentera_id: survey_sentera_id
    },
    feature_set: {
      sentera_id: feature_set_sentera_id,
      geometry: geometry,
      annotation_file_keys: file_uploads.map { |file_upload| file_upload['id'] }
    }
  }

  response = make_graphql_request(gql, variables)
  json = JSON.parse(response.body)
  json.dig('data', 'upsert_feature_set')
end

# MAIN

# **************************************************
# Set these variables based on the files you want
# to upload and the survey within FieldAgent to
# which you want to attach a feature set
files_path = ENV.fetch('FILES_PATH', '.') # Your fully qualified path to a folder containing the files to upload
file_ext = ENV.fetch('FILE_EXT', '*.*') # Your file extension
geometry_path = ENV.fetch('GEOMETRY_PATH', 'test.geojson') # Your fully qualified path to file containing the feature set geometry
survey_sentera_id = ENV.fetch('SURVEY_SENTERA_ID', 'sezjmpa_CO_arpmAcmeOrg_CV_deve_b822f1701_230330_110124') # Your survey Sentera ID
# **************************************************

file_paths = read_file_paths(files_path, file_ext)
raise "Geometry path #{geometry_path} does not exist" unless File.exist?(geometry_path)

geometry = File.read(geometry_path)

# Step 1: Create file uploads for the files that
#         will be attached to the feature set
file_uploads = create_file_uploads(file_paths, survey_sentera_id)
if file_uploads.nil?
  puts 'Failed'
  exit
end

num_annotations = file_uploads.size
feature_set_sentera_id = file_uploads.first['owner_sentera_id']

# Step 2: Upload the files
upload_files(file_uploads, file_paths)

# Step 3: Update the feature set with the annotation files
results = upsert_feature_set(
  geometry: geometry,
  feature_set_sentera_id: feature_set_sentera_id,
  survey_sentera_id: survey_sentera_id,
  file_uploads: file_uploads
)

if results && results['succeeded'].any?
  puts "Done! Feature set #{feature_set_sentera_id} was created with #{num_annotations} annotation files."
else
  puts "Failed due to error: #{results['failed'].inspect}"
end
