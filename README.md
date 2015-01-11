s3pub
=====

s3pub is a simple utility to publish assets to S3.

> Warning: s3pub deletes all the contents in the destination bucket before uploading files from source path.

> Limitation:  If there are more than 1000 files in the bucket only 1000 will get deleted

You can use s3pub in two ways.

## Upload assets from the command line

You can use s3pub as a command line tool to upload assets to S3.

By passing the required parameters as arguments:
```
  s3pub <s3-access-key-id> <s3-secret-access-key> <s3-region> <source-path> <destination-s3-bucket> <destination-s3-path>
```
> If `source-path` is a directory, s3pub will recursively upload all files in the directory and subdirectories

Or by passing an options file as an argument (see *[Options file format][0]* below.): 
```
  s3pub <path/to/options.cson>
```

## Upload assets programmatically

You can also use s3pub's Publisher class to upload assets to S3 programmatically.

```coffeescript
  {Publisher} = require "s3pub"

  publisher = new Publisher options

  # you can publish all files in a source directory to a destination bucket
  publisher.publish options

  # you can upload individual files as well
  publisher.upload "<source-file>", "<temp-path-to-store-compressed-files>", "<destination-s3-bucket>", "<destination-s3-path-to-file>", {"CacheControl": "max-age=86400"}
```

## Options

You can also pass the path to an options file as an argument to s3pub. The options file should be in CSON format.

```
  options: 
    accessKeyId: "<s3-access-key-id>"
    secretAccessKey: "<s3-secret-access-key>"
    region: "<s3-region>"
    sourcePath: "<path-to-source-files>"
    destinationBucket: "<s3-bucket>"
    destinationPath: "<s3-path>"
```

[0]:#options
