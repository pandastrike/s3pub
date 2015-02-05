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
    @s3 = new AWS.S3()

  publish: ({sourcePath, destinationBucket, destinationPath, s3Options}) ->
    sourcePath = resolve sourcePath
    compressedPath = resolve sourcePath, randomKey(16, "base64url")
    tempPath = randomKey(16, "base64url")
    @listAll({bucket: destinationBucket, path: destinationPath})
    .then (keys) =>
      if keys?
        all(
          for {Key} in keys
            @copy({destinationBucket, source: Key, destinationPath: tempPath})
        )
        .then =>
          @deleteAll({destinationBucket, destinationPath})
          .then =>
            fs.mkdirSync compressedPath
            paths = glob(sourcePath, "**/*")
            all(
              for path in paths
                @upload({sourcePath, sourceFile: path, compressedPath, destinationBucket, destinationPath, s3Options})
            )
            .finally =>
              @deleteAll({destinationBucket, destinationPath: tempPath})
              .then =>
                fs.rmdirSync compressedPath
      else
        resolve()
    .catch (err) =>
      @revertAll({destinationBucket, source: tempPath, destinationPath})

  listAll: ({bucket, path}) ->
    promise (resolve, reject) =>
      params =
        Bucket: bucket
        Prefix: path
      @s3.listObjects params, (err, keys) =>
        unless err?
          _keys = []
          for {Key} in keys.Contents
            _keys.push({Key})
          resolve _keys
        else
          reject err

  revertAll: (destinationBucket, source, destinationPath) ->
    promise (resolve, reject) =>
      @listAll({bucket: destinationBucket, path: source})
      .then (keys) =>
        unless keys?.length > 0
          all(
            for {Key} in keys
              newPath = join destinationPath, Key
              @copy({destinationBucket, source: destination, destinationPath: newPath})
          )
          .then =>
            resolve()
        else
          resolve()
        console.log "Failed to publish: ", err
        resolve()

  deleteAll: ({destinationBucket, destinationPath}) ->
    promise (resolve, reject) =>
      console.log "Deleting all files in S3 path '#{destinationBucket}/#{destinationPath}'"
      @listAll({bucket: destinationBucket, path: destinationPath})
      .then (keys) =>
        if keys?.length > 0
          params =
            Bucket: destinationBucket
            Delete:
              Objects: keys
          @s3.deleteObjects params, (err, data) =>
            unless err?
              console.log "Successfully deleted files from S3 path '#{destinationBucket}/#{destinationPath}'"
              resolve()
            else
              reject err
        else
          resolve()
      .catch (err) =>
        reject err

  compress: ({sourceFile, compressedFile}) ->
    promise (resolve, reject) =>
      readStream = fs.createReadStream(sourceFile)
      readStream.on "error", -> reject()

      writeStream = fs.createWriteStream(compressedFile)
      writeStream.on "finish", -> resolve()
      writeStream.on "error", -> reject()

      readStream.pipe(zlib.createGzip()).pipe(writeStream)

  copy: ({destinationBucket, source, destinationPath}) ->
    promise (resolve, reject) =>
      destinationPath = join destinationPath, source
      source = join destinationBucket, source
      params =
        Bucket: destinationBucket
        CopySource: source
        Key: destinationPath
      @s3.copyObject params, (err, data) =>
        if data?
          console.log "Successfully copied file from S3 path '#{source}' to '#{destinationBucket}/#{destinationPath}'"
          resolve()
        else
          reject err

  upload: ({sourcePath, sourceFile, compressedPath, destinationBucket, destinationPath, s3Options}) ->
    promise (resolve, reject) =>
      destinationFile = join destinationPath, sourceFile
      sourceFile = join sourcePath, sourceFile
      compressedFile = join compressedPath, randomKey(16, 'base64url')

      onFinish = ->
        fs.unlinkSync compressedFile

      onError = (err) ->
        console.log "Failed to upload file '#{sourceFile}' to S3 path '#{destinationBucket}/#{destinationFile}'"
        onFinish()
        reject err

      @compress({sourceFile, compressedFile})
      .then =>
        readStream = fs.createReadStream(compressedFile)
        params =
          Bucket: destinationBucket
          Key: destinationFile
          ContentType: mime.lookup(sourceFile)
          ContentEncoding: "gzip"
          ContentLength: fs.statSync(compressedFile).size
          Body: readStream
        params = merge(params, s3Options) if s3Options?
        @s3.putObject params, (err, data) ->
          unless err?
            console.log "Successfully uploaded file '#{sourceFile}' to S3 path '#{destinationBucket}/#{destinationPath}'"
            onFinish()
            resolve data
          else
            onError err
      .catch (err) =>
        onError err