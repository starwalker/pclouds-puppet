require 'rubygems'
require 'facter'
require 'fog'

Puppet::Type.newtype(:ebsvol) do
    @doc = "Manage EBS Volumes"

    # Allow to be ensurable
    ensurable
    # Automatically select the aws provider for this type.
    #resource[:provider] = :aws
    
    newparam(:volume_name) do
        desc "The friendly Name (tag) of an AWS EBS Volume"
	isnamevar
	isrequired
    end

    newparam(:size) do
        desc "The size of the volume in GB"
	defaultto "1"
	validate do |value|
		unless value =~ /^[0-9]+$/
                	raise ArgumentError , "%s is not a valid size" % value
		end
	end
    end

    # Allow us to set the availability zone of use the one that
    # matches the host by default.  
    newparam(:availability_zone) do
        desc "The availability_zone containing the volume"
	defaultto do
		Facter.value('ec2_placement_availability_zone') 
	end
    end

    newparam(:instance_id) do
        desc "The instance_id of AWS Instance to attach to"
    end

    newparam(:device) do
        desc "A linux device to attach a volume to, e.g. /dev/sdb"

        validate do |value|
            unless value =~ /^\/dev\/sd[a-z]$/
                raise ArgumentError , "%s is not a valid device name" % value
            end
        end
    end
end
