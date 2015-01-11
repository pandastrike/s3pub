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

    @deleteAll({destinationBucket, destinationPath})
    .then =>
      fs.mkdirSync compressedPath
      paths = glob(sourcePath, "**/*")
      all(
        @upload({sourcePath, sourceFile: path, compressedPath, destinationBucket, destinationPath, s3Options}) for path in paths
      )
      .finally =>
        fs.rmdirSync compressedPath
    .catch (err) =>
      console.log "Exception caught - ", err

  deleteAll: ({destinationBucket, destinationPath}) ->
    promise (resolve, reject) =>
      console.log "Deleting all files in S3 path '#{destinationBucket}/#{destinationPath}'"
      params =
        Bucket: destinationBucket
        Prefix: destinationPath
      s3 = new AWS.S3()
      s3.listObjects params, (err, keys) =>
        unless err?
          paths = []
          for {Key} in keys.Contents
            paths.push({Key})
          if paths.length > 0
            params =
              Bucket: destinationBucket
              Delete:
                Objects: paths
            s3.deleteObjects params, (err, data) =>
              unless err?
                console.log "Sucessfully deleted files from S3 path '#{destinationBucket}/#{destinationPath}'"
                resolve()
              else
                console.log "Error: ", err
                reject err
          else
            resolve()
        else
          console.log "Error: ", err
          reject err

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
        console.log "Failed to upload file '#{sourceFile}' to S3 path '#{destinationBucket}/#{destinationPath}'"
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
            console.log "Sucessfully uploaded file '#{sourceFile}' to S3 path '#{destinationBucket}/#{destinationPath}'"
            onFinish()
            resolve data
          else
            onError err
