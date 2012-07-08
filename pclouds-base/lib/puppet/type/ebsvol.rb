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

    newproperty(:attachedto) do
	desc "The 'Name' of an EC2 instanca, which the volume should be attached to"
	defaultto nil
	validate do |value|
		if (value != nil && resource[:device] == nil)
			raise ArgumentError, "You need to specify the device when using the attachedto property"
		end
	end
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
