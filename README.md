s3pub
=====

s3pub is a simple utility to publish assets to S3.

You can use s3pub in two ways.

> Warning: s3pub deletes all the contents in the destination bucket before uploading files from source path.

## Upload assets from the command line

You can use s3pub as a command line tool to upload assets to S3.

By passing the required parameters as arguments:
```
  s3pub <s3-access-key-id> <s3-secret-access-key> <s3-region> <source-dir> <destination-s3-bucket>
```
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
  publisher.upload "<source-file>", "<temp-path-to-store-compressed-files>", "<destination-s3-bucket>", "<destination-file>", {"CacheControl": "max-age=86400"}
```

## Options

You can also pass the path to an options file as an argument to s3pub. The options file should be in CSON format.

```
  options: 
    accessKeyId: "<s3-access-key-id>"
    secretAccessKey: "<s3-secret-access-key>"
    region: "<s3-region>"
    source: "<path-to-source-files>"
    destination: "<s3-bucket>"
    s3Options: 
      "CacheControl": "max-age=86400"
```

[0]:#options
