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


  publish: ({source, destination, s3Options}) ->
    source = resolve source
    compressedDir = resolve source, randomKey(16, "base64url")

    @deleteAll({destination})

    fs.mkdirSync compressedDir
    paths = glob(source, "**/*")
    all(
      @upload({sourceFile: join(source, path), compressedDir, destination, destinationFile: path, options: s3Options}) for path in paths
    )
    .then ->
      fs.rmdirSync compressedDir


  deleteAll: ({destination}) ->
    console.log "Deleting all files in S3 bucket '#{destination}'"
    # TODO: Implement functionality


  compress: ({sourceFile, compressedFile}, callback) ->
    readStream = fs.createReadStream(sourceFile)
    readStream.on "error", callback

    writeStream = fs.createWriteStream(compressedFile)
    writeStream.on "finish", -> callback?(null)
    writeStream.on "error", callback

    readStream.pipe(zlib.createGzip()).pipe(writeStream)


  upload: ({sourceFile, compressedDir, destination, destinationFile, options}) ->
    
    promise (resolve, reject) =>

      compressedFile = join compressedDir, randomKey(16, 'base64url')

      onFinish = ->
        fs.unlinkSync compressedFile

      onError = (err) ->
        console.log "Failed to upload file '#{sourceFile}' to S3 bucket '#{destination}'"
        onFinish()
        reject err

      @compress {sourceFile, compressedFile}, (err) ->
        return onError(err) if err?

        readStream = fs.createReadStream(compressedFile)

        params = 
          Bucket: destination
          Key: destinationFile
          ContentType: mime.lookup(sourceFile)
          ContentEncoding: "gzip"
          ContentLength: fs.statSync(compressedFile).size
          Body: readStream
        params = merge(params, options) if options?
        s3 = new AWS.S3()
        s3.putObject params, (err, data) -> 
          unless err?
            console.log "Sucessfully uploaded file '#{sourceFile}' to S3 bucket '#{destination}'"
            onFinish()
            resolve data
          else
            onError err
