# File        : s3-svn-config.rb
# Description : Settings file for s3-backup-svn
# Copyright   : Copyright (c) 2011 Lee Robert
# License     : See the LICENSE file

# Your Amazon ID
AWS_ID     = 'YOUR_AMAZON_ID'
# Your secret Amazon Key
AWS_KEY    = 'YOUR_SECRET_AMAZON_KEY'
# The name of the S3 bucket. It will be prefixed with a
#  Base64-encoded SHA1 hash of your AWS_ID (see #create_bucket_name)
BUCKET     = 'svn-backups'
# The directory that contains all your svn repositories
REPO_DIR   = '/path/to/your/svn-repository'
# A directory that the backup script can write to
WORK_DIR   = '/path/writable_for_the_svn_user'
# The Location of the SVN Binaries {svnadmin, svnlook}
SVN_BINDIR = '/usr/local/bin'
# Full path to gzip
GZIP       = '/usr/bin/gzip'
# Full path to gunzip
GUNZIP     = '/usr/bin/gunzip'
# Full path to write the log
LOG_FILE   = '/path/where_the/logfile_goes/s3-backup.log'
# Set to true if you want to keep the local copies of the backups
KEEP_FILES = false
# A list of SVN Projects. 'ValidS3Name' => 'RepoName'
# Below shows the example to backup /var/svn/MySVNProject
SVN_PROJECTS = {
    'MySVNBackup' => 'MySVNProject'
}
##############################################################
# DO NOT EDIT AFTER THIS
##############################################################

# Generates a hash to prefix your bucket-name with.
# This ensures that we always have a unique name on S3
def full_bucket_name
    "#{Base64.encode64(SHA1.digest(AWS_ID)).gsub(/\W/,'')}-#{BUCKET}"
end

# Connects to Amazon S3
def connect!
    begin
        AWS::S3::Base.establish_connection!(
            :access_key_id     => AWS_ID,
            :secret_access_key => AWS_KEY
        )
        LOG.info "Connection to Amazon AWS established."
    rescue => e
        LOG.fatal e
        exit 1
    end
end
