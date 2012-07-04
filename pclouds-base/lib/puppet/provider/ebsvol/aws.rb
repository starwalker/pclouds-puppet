require 'rubygems'
require 'fog'

$debug=true

Puppet::Type.type(:ebsvol).provide(:aws) do
    desc "AWS provider to ebsvol types"

    commands :fog => '/usr/bin/fog'
    confine :ec2_profile => 'default-paravirtual'

    def create
    	region = resource[:availability_zone].to_s.gsub(/.$/,'') 
	print "Region is #{region}\n" if $debug
	print "availability_zone is #{resource[:availability_zone]}\n" if $debug
	compute = Fog::Compute.new(:provider => 'aws', :region => "#{region}")
	# create the requested volume
	response = compute.create_volume(resource[:availability_zone],resource[:size])	
	if (response.status == 200)
		volumeid = response.body['volumeId']
		print "I created volume #{volumeid}.\n" if $debug
		# now tag the volume with volumename so we can identify it by name
		# and not the volumeid
		response = compute.create_tags(volumeid,{ :Name => resource[:volume_name] })
		if (response.status == 200)
			print "I tagged #{volumeid} with Name = #{resource[:volume_name]}\n" if $debug
		end
	else
		raise "I couldn't create the ebs volume, sorry!"
	end
    end

    def destroy
	print "I would destroy\n"
    end

    def exists?
	# list the volumes in the required region and check for the existence of a volume
	# tagged with the same Name as this resource.
    	region = resource[:availability_zone].to_s.gsub(/.$/,'') 
	compute = Fog::Compute.new(:provider => 'aws', :region => "#{region}")
	volumes = compute.describe_volumes
	if (volumes.status == 200)
		# check each of the volumes in our availability zone which match our name.
		volumes.body['volumeSet'].each {|x|
			# Match the name unless the volume is actually being deleted...
			if (x['tagSet']['Name'] == resource[:volume_name] && x['status'] != "deleting")
				print "Volume #{x['volumeId']} has Name = #{resource[:volume_name]}\n" if $debug
				return true
			end
		}
	else
		raise "I couldn't read the volumes in region #{region}"
	end
	false
    end
end
