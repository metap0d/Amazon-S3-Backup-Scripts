#!/usr/bin/env ruby
# File        : s3-backup-svn.rb
# Description : Creates a copy of multiple SVN repositories 
#             : on amazon's S3 service.
# Copyright   : Copyright (c) 2011 Lee Robert
# License     : See the LICENSE file

%w{rubygems logger base64 sha1 aws/s3}.each{|lib| require lib}
require File.join(File.dirname($0), 's3-svn-config')

LOG = Logger.new(LOG_FILE)

def usage!    
    puts "To use #{$0} you simply make sure that the repositories you want backed up are declared in s3-svn-config.rb\n"
    exit 0
end
usage! if ARGV[0] =~ /^(?:-h|--help)$/

repo = ARGV[0] || REPO_DIR
#rev  = (ARGV[1] || `#{SVN_BINDIR}/svnlook youngest #{repo}`.strip).to_i

# We need the AWS S3 Package
include AWS::S3

# returns -1 when no revision was found
def get_latest_backup_revision(bucket, s3Name)
    # Pattern of the S3Object-keys
    pattern = /^#{Regexp.escape(s3Name)}_rev_(\d+)_(\d+).*$/
    rev = -1
    # S3Objects can come theoretically in any order...
    bucket.each do |o|
        if o.key.match(pattern)
            rev = $2.to_i if $2.to_i > rev
        end
    end
    rev
end

# creates an incremental/delta/gzipped dump from rev1 to rev2
def dump_repository(repo, rev1, rev2, s3Name)
    dump_file = File.join(WORK_DIR, "#{s3Name}_rev_#{rev1}_#{rev2}.dump.gz")
    `#{SVN_BINDIR}/svnadmin dump #{repo} --incremental --deltas -q -r #{rev1}:#{rev2} | #{GZIP} -f >#{dump_file}`
    if !FileTest.exist?(dump_file) || $?.exitstatus != 0
        LOG.fatal "'svnadmin dump' to file #{dump_file} failed"
        exit 1
    end
    dump_file
end

def write_to_s3!(file, bucket_name)
    begin
        S3Object.store(
            File.basename(file),
            open(file),
            bucket_name
        )
    rescue => e
        LOG.fatal "Failed to write to S3!"
        LOG.fatal e
        #        exit 1
    end
end

def main()
    
    # Connect to S3
    connect!
    
    # Make sure we have a bucket that we can use
    bucket_name = get_bucket_name
    begin
        bucket = Bucket.find(bucket_name)
    rescue NoSuchBucket
        LOG.info "Creating new bucket #{bucket_name}"
        Bucket.create(bucket_name)
        bucket = Bucket.find(bucket_name)
    end
    
    # Try to backup each repository on the list
    SVN_PROJECTS.each do | s3Name, repo |
        
        current_repo_dir = REPO_DIR + repo
        current_revision = `#{SVN_BINDIR}/svnlook youngest #{current_repo_dir}`.strip.to_i
        
        LOG.info "Current Repo: #{current_repo_dir}"
        latest_backup_revision = get_latest_backup_revision(bucket, s3Name) + 1
        if latest_backup_revision >= current_revision
            LOG.info "Skipping Backup for #{repo}. Latest backup is revision #{latest_backup_revision}, and the current is  #{current_revision}."
            next
        end
        #  dump_file = dump_repository(repo, next_rev, current_revision)
        dump_file = dump_repository(current_repo_dir, 0, current_revision, s3Name)
        write_to_s3!(dump_file, bucket_name)
        LOG.info "Backup of #{repo} revision #{next_rev} to #{current_revision} finished"
        File.unlink(dump_file) unless KEEP_DUMP_FILES
    end
end

main()
