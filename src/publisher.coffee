fs = require("fs")
zlib = require("zlib")
{resolve, join, dirname} = require "path"
{merge} = require "fairmont"
glob = require "panda-glob"
{promise, all} = require "when"
mime = require "mime"
{randomKey} = require "key-forge"
AWS = require "aws-sdk"

module.exports = class Publisher

  constructor: ({accessKeyId, secretAccessKey, region}) ->
    AWS.config.update {
      accessKeyId
      secretAccessKey
      region
    }

  publish: ({sourcePath, destinationBucket, destinationPath, s3Options}) ->
    sourcePath = resolve sourcePath
    compressedPath = resolve sourcePath, randomKey(16, "base64url")

    console.log()
    @deleteAll({destinationBucket, destinationPath})
    .then =>
      fs.mkdirSync compressedPath
      paths = glob(sourcePath, "**/*")
      all(
        @upload({sourcePath, sourceFile: path, compressedPath, destinationBucket, destinationPath, s3Options}) for path in paths
      )
      .finally ->
        fs.rmdirSync compressedPath
        console.log()

  deleteAll: ({destinationBucket, destinationPath}) ->
    promise (resolve, reject) ->
      console.log "Deleting all files in S3 bucket '#{destinationBucket}/#{destinationPath}'"
      # TODO: Implement functionality
      resolve()

  compress: ({sourceFile, compressedFile}, callback) ->
    readStream = fs.createReadStream(sourceFile)
    readStream.on "error", callback

    writeStream = fs.createWriteStream(compressedFile)
    writeStream.on "finish", -> callback?(null)
    writeStream.on "error", callback

    readStream.pipe(zlib.createGzip()).pipe(writeStream)


  upload: ({sourcePath, sourceFile, compressedPath, destinationBucket, destinationPath, s3Options}) ->
    
    promise (resolve, reject) =>

      destinationFile = join destinationPath, sourceFile
      sourceFile = join sourcePath, sourceFile
      compressedFile = join compressedPath, randomKey(16, 'base64url')

      onFinish = ->
        fs.unlinkSync compressedFile

      onError = (err) ->
        console.log "Failed to upload file '#{sourceFile}' to S3 bucket '#{destinationBucket}/#{destinationPath}'"
        onFinish()
        reject err

      @compress {sourceFile, compressedFile}, (err) ->
        return onError(err) if err?

        readStream = fs.createReadStream(compressedFile)

        params = 
          Bucket: destinationBucket
          Key: destinationFile
          ContentType: mime.lookup(sourceFile)
          ContentEncoding: "gzip"
          ContentLength: fs.statSync(compressedFile).size
          Body: readStream
        params = merge(params, s3Options) if s3Options?
        s3 = new AWS.S3()
        s3.putObject params, (err, data) -> 
          unless err?
            console.log "Sucessfully uploaded file '#{sourceFile}' to S3 bucket '#{destinationBucket}/#{destinationPath}'"
            onFinish()
            resolve data
          else
            onError err
