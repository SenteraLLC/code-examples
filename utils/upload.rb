# frozen_string_literal: true

# MIME content type mapping for common file extensions
CONTENT_TYPES = {
  '.geojson' => 'application/geo+json',
  '.json' => 'application/json',
  '.tif' => 'image/tiff',
  '.tiff' => 'image/tiff',
  '.jpg' => 'image/jpeg',
  '.jpeg' => 'image/jpeg',
  '.png' => 'image/png',
  '.pdf' => 'application/pdf',
  '.zip' => 'application/zip',
  '.txt' => 'text/plain',
  '.csv' => 'text/csv',
  '.xml' => 'application/xml',
  '.shp' => 'application/octet-stream',
  '.kml' => 'application/vnd.google-earth.kml+xml',
  '.kmz' => 'application/vnd.google-earth.kmz'
}.freeze

#
# Reads the files at a path for a specified extension
#
# @param [string] files_path Path to a directory containing
#                            the files
# @param [string] file_ext Extension of files to return
#
# @return [Array[string]] Array of file paths
#
def read_file_paths(files_path, file_ext)
  raise "Files path #{files_path} does not exist" unless Dir.exist?(files_path)

  files_path += '/' unless files_path.end_with?('/')
  Dir.glob("#{files_path}#{file_ext}")
end

#
# Reads file properties for files at a path with a specified extension.
# Returns an array of hashes containing file metadata including path, filename,
# byte size, MD5 checksum, and automatically detected content type based on
# file extension.
#
# @param [string] files_path Path to a directory containing the files
# @param [string] file_ext Extension of files to return
#
# @return [Array[Hash]] Array of hashes with keys: :path, :filename, :byte_size,
#                       :checksum, :content_type
#
def read_file_props(files_path, file_ext)
  raise "Files path #{files_path} does not exist" unless Dir.exist?(files_path)

  read_file_paths(files_path, file_ext).map do |file_path|
    ext = File.extname(file_path).downcase
    content_type = CONTENT_TYPES[ext] || 'application/octet-stream'

    {
      path: file_path,
      filename: File.basename(file_path),
      byte_size: File.size(file_path),
      checksum: Digest::MD5.base64digest(File.read(file_path)),
      content_type: content_type
    }
  end
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
# This method demonstrates how to upload files to
# Sentera's cloud storage using the URL and headers
# that were retrieved via the create_file_upload,
# create_file_uploads or create_image_uploads
# GraphQL mutations
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

  file_uploads_map = {}
  file_uploads.each.with_index do |file_upload, index|
    file_path = file_paths[index]
    file_uploads_map[file_path] = file_upload
  end

  Parallel.each(file_paths, in_threads: 6) do |file_path|
    file_upload = file_uploads_map[file_path]

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
# This method demonstrates how to upload files to
# Sentera's cloud storage using the URL and headers
# that were retrieved via the create_file_upload,
# create_file_uploads or create_image_uploads
# GraphQL mutations
#
# @param [Array[Object]] file_uploads FileUpload GraphQL
#                        objects created by the
#                        create_file_uploads mutation
# @param [Array[string]] file_paths Array of paths to
#                        the files to upload
#
# @return [void]
#
# def upload_files(file_uploads, file_paths)
#   puts 'Upload files'

#   file_uploads_map = file_uploads.each_with_object({}) do |file_upload, map|
#     s3_url = file_upload['s3_url']
#     filename = File.basename(s3_url)
#     map[filename] = file_upload
#   end

#   Parallel.each(file_paths, in_threads: 6) do |file_path|
#     filename = File.basename(file_path)
#     file_upload = file_uploads_map[filename]

#     uri = URI(file_upload['upload_url'])
#     file_contents = File.read(file_path)
#     Net::HTTP.start(uri.host) do |http|
#       puts "Upload #{file_path} to S3"
#       response = http.send_request('PUT',
#                                    uri,
#                                    file_contents,
#                                    file_upload['headers'])
#       puts "Done uploading #{file_path}, response.code = #{response.code}"
#     end
#   end
# end
