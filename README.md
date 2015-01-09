s3pub
=====

Simple module to publish assets to S3.

You can use s3pub from the command line to upload static assets to S3.
    
    s3pub <s3-access-key-id> <s3-secret-access-key> <s3-region> <source-dir> <destination-s3-bucket>

  or

    s3pub <path/to/options.cson>

See *[Options][0]* below.

You can also use s3pub's interface to upload files to S3.

```coffeescript
  {Publisher} = require "s3pub"

  publisher = new Publisher options

  # you can publish all files in a source directory to a destination bucket
  publisher.publish options

  # you can upload individual files as well
  publisher.upload "<source-file>", "<temp-path-to-store-compressed-files>", <destination-s3-bucket>", "<destination-file>", {"CacheControl": "max-age=86400"}
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
    s3Options: {}
```

[0]:#options
