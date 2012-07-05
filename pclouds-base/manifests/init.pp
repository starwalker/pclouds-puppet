# Class: pclouds-base
#
# Version 1.2
#
# 1.2 - Add install of fog
#
# This module manages base instance packages and config
#
# Please 'import' this module rather than 'include' it, so that it automatically sets up the run stages
# and includes itself in the base stage.  All you need in your sites.pp or nodes.pp is: -
# import "pclouds-base"
#
# This module does not expect any parameters or define any resources.
#
# Define our extra run stages...
# 1. base - core install of packages, ruby gems and files needed by the other stages
# 2. infrastructure - set up infrastructure, such as attaching EBS storage, S3, Route 53 or
#            attaching to an elastic load balancer.
# 3. main - where normal classes run to set up software
# 4. post - any clean up that needs to run AFTER the main stage.

stage { [base, infrastructure, post]: }
Stage[base] -> Stage[infrastructure]  -> Stage[main] -> Stage[post]

# Include the pclouds-base class and assign it to the 'base' stage...
class { "pclouds-base": stage => base }

class pclouds-base {
	case $operatingsystem {
		'CentOS': { $ephdevice="/dev/xvde2" }
		default:  { $ephdevice="/dev/xvda2" }
	}		

	# ensure the /data mount point exists
	file { "ephemeralmountpoint":
		path => "/data",
		ensure => "directory",
		owner => "root",
		group => "root",
		mode => "0755",
	}

	# format the volume, but only if it exists and is not formated
	exec { "formatit":
		command => "mkfs.ext4 $ephdevice",
		path => "/usr/bin:/usr/sbin:/bin:/sbin",
		logoutput => "true",
		# use test in order to return 0 if command failed!
		# which is what we want as blkid will fail if it is not formatted.
		onlyif => [ "ls $ephdevice", "test ! `blkid $ephdevice`" ],
	}

	# mount the ephemeral volume to /data
	mount { "ephemeraldisk":
		device => $ephdevice,
		ensure => mounted,
		name => "/data",
		options => "defaults",
		fstype => "ext4",
		require => [ File["ephemeralmountpoint"], Exec["formatit"] ],
		provider => "parsed",
	}

	# Automatically set the timezone according to which region the node
	# is running in

	file { "/etc/localtime":
		ensure => file,
		source => $ec2_placement_availability_zone ? {
			/^eu-west/ => "/usr/share/zoneinfo/GB",
			/^us-west/ => "/usr/share/zoneinfo/US/Pacific",
			/^us-east/ => "/usr/share/zoneinfo/US/Eastern",
			/^ap-/ => "/usr/share/zoneinfo/Japan",
			default => undef,
		},
		notify => [ Service['rsyslog'], Service['crond'] ],
	}

	service { "rsyslog":
		ensure => running,
		hasrestart => true,
		enable => true,
		require => File['/etc/localtime'],
	}
		
	service { "crond":
		ensure => running,
		hasrestart => true,
		enable => true,
		require => File['/etc/localtime'],
	}

	# Make sure we have the yum fast mirror plugin installed and vim
	$extra_packages = [ "vim-enhanced", "yum-plugin-fastestmirror.noarch" ]	
	package { $extra_packages: ensure => present }
		
	file { "/etc/profile.d/vim.sh":
		ensure => file,
		owner => 'root',
		group => 'root',
	 	mode => 0755,
		source => "puppet:///modules/pclouds-base/vim.sh",
		require => Package['vim-enhanced'],
	}

	# make sure that fog is available for running cloud commands...
	# ruby and ruby gems packages
	$ruby_packages= ["ruby", "ruby-rdoc", "ruby-ri", "ruby-libs", "ruby-shadow", "rubygems", "rubygem-rake"]
	package { $ruby_packages:
		ensure => present
	}
		
	$fog_requires=[ "make", "ruby-devel", "libxml2-devel", "gcc", "libxslt-devel" ]
	package { $fog_requires: ensure => present }
	
	# install the fog gem
	$ruby_gems = [ "fog" ]
	package { $ruby_gems:
			ensure => present,
			provider => gem,
			require => [ Package[$ruby_packages], Package[$fog_requires] ]
	}
}

