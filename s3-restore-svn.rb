#!/usr/bin/env ruby
# File        : s3-restore-svn.rb
# Description : Restores a previously backed up SVN repository 
#             : from amazon's S3 service.
# Copyright   : Copyright (c) 2011 Lee Robert
# License     : See the LICENSE file
%w{rubygems logger base64 sha1 aws/s3}.each{|lib| require lib}
require File.join(File.dirname($0), 's3-svn-config')

LOG = Logger.new(STDOUT)

def usage!
    puts "Usage: #{$0} path/to/new_repo s3Name\n"
    puts "Repository S3 Names that are defined in the configuration are:\n"
    SVN_PROJECTS.each do | s3Name, repo |
        puts "#{s3Name}\n"
    end
    exit 0
end
usage! if ARGV[0] =~ /^(?:-h|--help)$/ || ARGV.empty? || ARGV.count < 2
REPONAME = ARGV[1];
include AWS::S3

def load_dumps!(bucket_name, repo)
    begin
        pattern = /^#{Regexp.escape(REPONAME)}_rev_(\d+)_(\d+).*$/
        prefix = lambda{|p| "#{REPONAME}_rev_#{p}_"}
        rev1 = 0
        while true
            o = Bucket.objects(bucket_name, :prefix => prefix.call(rev1), :max_keys => 1).first
            break unless o
            raise "Unexpected file pattern: #{o.key}" unless pattern.match(o.key)
            rev2 = $2.to_i
            LOG.info "Restoring revisions #{rev1} - #{rev2}"
            dump_file = File.join(WORK_DIR, o.key)
            File.open(dump_file, 'w') do |f|
                o.value do |seg|
                    f.write seg
                end
            end
            # Create a new repository
            `svnadmin create #{repo}`
            # Load the dump file into the repository
            `#{GUNZIP} -c #{dump_file} | svnadmin load #{repo}`
            s = $?.exitstatus
            raise "'svnadmin load' failed for #{dump_file} with status #{s}" unless s == 0
            File.unlink(dump_file) unless KEEP_DUMP_FILES
            rev1 = rev2 + 1
        end
    rescue => e
        LOG.fatal e
        exit 1
    end
end

def main(repo)
    connect!
    LOG.info "#{REPONAME}\n"
    load_dumps!(get_bucket_name, repo)
end

main(ARGV[0])
