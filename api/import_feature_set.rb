#!/usr/bin/env ruby

# frozen_string_literal: true

# ==================================================================
# A Ruby example that demonstrates the workflow for uploading a
# feature set with annotation files to Sentera's FieldAgent platform
# using the import_feature_set GraphQL mutation.
#
# Contact devops@sentera.com with any questions.
# ==================================================================

require '../utils/utils'
verify_ruby_version

require 'net/http'
require 'json'
require 'digest'
require '../utils/parallel'
require '../utils/upload'

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
# This method demonstrates how to use the create_file_upload
# mutation in Sentera's GraphQL API to prepare a geometry file
# for upload to Sentera's cloud storage.
#
# @param [string] geometry_path Path to geometry file
# @param [string] survey_sentera_id Sentera ID of the survey
#                                   within FieldAgent that will
#                                   be the parent of the feature
#                                   set.
#
# @return [Hash] Hash containing results of the GraphQL request
#
def create_geometry_file_upload(geometry_path, survey_sentera_id)
  puts 'Create geometry file upload'

  gql = <<~GQL
    mutation CreateGeometryFileUpload(
      $file_upload_owner: FileUploadOwnerInput
      $byte_size: BigInt!
      $checksum: String!
      $content_type: String!
      $filename: String!
    ) {
      create_file_upload(
        file_upload_owner: $file_upload_owner
        byte_size: $byte_size
        checksum: $checksum
        content_type: $content_type
        filename: $filename
        ) {
        id
        headers
        owner_sentera_id
        upload_url
      }
    }
  GQL

  variables = {
    file_upload_owner: {
      owner_type: 'FEATURE_SET',
      parent_sentera_id: survey_sentera_id
    },
    byte_size: File.size(geometry_path),
    checksum: Digest::MD5.base64digest(File.read(geometry_path)),
    content_type: 'application/geo+json',
    filename: File.basename(geometry_path)
  }

  response = make_graphql_request(gql, variables)
  json = JSON.parse(response.body)
  json.dig('data', 'create_file_upload')
end

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
# @param [string] feature_set_sentera_id Sentera ID of the feature set
#
# @return [Hash] Hash containing results of the GraphQL request
#
def create_file_uploads(file_paths, survey_sentera_id, feature_set_sentera_id)
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
        upload_url
      }
    }
  GQL

  variables = {
    file_upload_owner: {
      owner_sentera_id: feature_set_sentera_id,
      parent_sentera_id: survey_sentera_id
    },
    files: files
  }

  response = make_graphql_request(gql, variables)
  json = JSON.parse(response.body)
  json.dig('data', 'create_file_uploads')
end

#
# This method demonstrates how to use the IDs of the files that
# were previously uploaded to Sentera's cloud storage with the
# import_feature_set GraphQL mutation, to attach the files to
# a feature set.
#
# @param [string] feature_set_sentera_id ID of the feature set
#                                        to upsert
# @param [Object] geometry_file_upload FileUpload GraphQL
#                        object created by the
#                        create_file_upload mutation
# @param [Array[Object]] file_uploads FileUpload GraphQL
#                        objects created by the
#                        create_file_uploads mutation
#
# @return [Hash] Hash containing results of the GraphQL request
#
def import_feature_set(feature_set_sentera_id:, geometry_file_upload:, file_uploads:)
  puts 'Upsert feature set'

  gql = <<~GQL
    mutation ImportFeatureSet(
      $feature_set_sentera_id: ID
      $name: String!
      $type: FeatureSetType!
      $geometry_file_key: FileKey
      $annotation_file_keys: [FileKey!]
    ) {
      import_feature_set(
        feature_set_sentera_id: $feature_set_sentera_id
        name: $name
        type: $type
        geometry_file_key: $geometry_file_key
        annotation_file_keys: $annotation_file_keys
      ) {
        status
      }
    }
  GQL

  variables = {
    feature_set_sentera_id: feature_set_sentera_id,
    name: 'My Feature Set',
    type: 'UNKNOWN',
    geometry_file_key: geometry_file_upload['id'],
    annotation_file_keys: file_uploads.map { |file_upload| file_upload['id'] }
  }

  response = make_graphql_request(gql, variables)
  json = JSON.parse(response.body)
  json.dig('data', 'import_feature_set')
end

# MAIN

# **************************************************
# Set these variables based on the files you want
# to upload and the survey within FieldAgent to
# which you want to attach a feature set
files_path = ENV.fetch('FILES_PATH', '.') # Your fully qualified path to a folder containing the files to upload
file_ext = ENV.fetch('FILE_EXT', '*.*') # Your file extension
geometry_path = ENV.fetch('GEOMETRY_PATH', '../test_files/test.geojson') # Your fully qualified path to file containing the feature set geometry
survey_sentera_id = ENV.fetch('SURVEY_SENTERA_ID', 'sezjmpa_CO_arpmAcmeOrg_CV_deve_b822f1701_230330_110124') # Your survey Sentera ID
# **************************************************

# Step 1: Create a file upload for the geometry file that
#         will be attached to the feature set
geometry_file_upload = create_geometry_file_upload(geometry_path, survey_sentera_id)
if geometry_file_upload.nil?
  puts 'Failed'
  exit
end

# Step 2: Create file uploads for the annotation files that
#         will be attached to the feature set
file_paths = read_file_paths(files_path, file_ext)
feature_set_sentera_id = geometry_file_upload['owner_sentera_id']
file_uploads = create_file_uploads(file_paths, survey_sentera_id, feature_set_sentera_id)
if file_uploads.nil?
  puts 'Failed'
  exit
end

# Step 3: Upload the geometry file
upload_files([geometry_file_upload], [geometry_path])

# Step 4: Upload the annotation files
upload_files(file_uploads, file_paths)

# Step 5: Update the feature set with the files
results = import_feature_set(
  feature_set_sentera_id: feature_set_sentera_id,
  geometry_file_upload: geometry_file_upload,
  file_uploads: file_uploads
)

if results
  puts "Done! Feature set #{feature_set_sentera_id} with #{file_uploads.size} files was queued for importing."
else
  puts 'Failed'
end
