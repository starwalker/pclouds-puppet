require 'rubygems'
require 'fog'

$debug=true

Puppet::Type.type(:ebsvol).provide(:aws) do
    desc "AWS provider to ebsvol types"

    commands :fog => '/usr/bin/fog'
    confine :ec2_profile => 'default-paravirtual'

    def create
    	region = resource[:availability_zone].to_s.gsub(/.$/,'') 
	print "ebsvol[aws]->create: Region is #{region}\n" if $debug
	print "ebsvol[aws]->create: Availability_zone is #{resource[:availability_zone]}\n" if $debug
	compute = Fog::Compute.new(:provider => 'aws', :region => "#{region}")
	# create the requested volume
	response = compute.create_volume(resource[:availability_zone],resource[:size])	
	if (response.status == 200)
		volumeid = response.body['volumeId']
		print "ebsvol[aws]->create: I created volume #{volumeid}.\n" if $debug
		# now tag the volume with volumename so we can identify it by name
		# and not the volumeid
		response = compute.create_tags(volumeid,{ :Name => resource[:volume_name] })
		if (response.status == 200)
			print "ebsvol[aws]->create: I tagged #{volumeid} with Name = #{resource[:volume_name]}\n" if $debug
		end
	else
		raise "ebsvol[aws]->create: I couldn't create the ebs volume, sorry!"
	end
    end

    def destroy
	# remove an existing ebsvolume - exists? must be true
	# if it is attached to an instance then it must be detached first
    	region = resource[:availability_zone].to_s.gsub(/.$/,'') 
	compute = Fog::Compute.new(:provider => 'aws', :region => "#{region}")

	volume = volinfo(compute,resource[:volume_name])
	# check if volume is attached to something- detach before delete.
	if (volume == nil) 
		raise "ebsvol[aws]->destroy: Sorry! I couldn't find the volume #{resource[:volume_name]} to delete"
	else
		if ( volume['volumeId'] == nil )
			raise "ebsvol[aws]->destroy: Error, couldn't lookup the volumeId of #{resource[:volume_name]}"
		else
			print "ebsvol[aws]->destroy: Looking at status and attachment set...\n" if $debug
			if ( volume['status'] == 'in-use' && volume['attachmentSet'] != nil )
				if ( volume['attachmentSet'][0]['status'] == 'attached' && 
					volume['attachmentSet'][0]['device'] != nil && volume['attachmentSet'][0]['instanceId'] != nil)
					# detach the volume
					print "ebsvol[aws]->destroy: detaching #{volume['volumeId']} from #{volume['attachmentSet'][0]['instanceId']}\n" if $debug
					detach_vol(compute,volume)
				end
			end
			print "ebsvol[aws]->destroy: deleting #{volume['volumeId']}\n" if $debug
			response = compute.delete_volume(volume['volumeId'])
			if ( response.status == 200) 
				print "ebsvol[aws]->destroy: I successfully deleted #{volume['volumeId']}\n" if $debug
			else
				raise "ebsvol[aws]->destroy: Sorry, I could not delete the volume!"
			end
		end
	end
    end

    def exists?
    	region = resource[:availability_zone].to_s.gsub(/.$/,'') 
	compute = Fog::Compute.new(:provider => 'aws', :region => "#{region}")
	volume = volinfo(compute,resource[:volume_name])
	if (volume != nil && volume['status'] != 'deleting')
		true
	else
		false
	end
    end

    # helper function to retrieve a volumes information or nil
    # list the volumes in the region and look for one with a Name tag which matches our name.
    # returns the volumeSet associative array...
    def volinfo(compute,name)
	volumes = compute.describe_volumes
	if (volumes.status == 200)
		# check each of the volumes in our availability zone which match our name.
		volumes.body['volumeSet'].each {|x|
			# Match the name unless the volume is actually being deleted...
			if (x['tagSet']['Name'] == resource[:volume_name] )
				#print "ebsvol[aws]->volinfo: Volume #{x['volumeId']} has Name = #{resource[:volume_name]}\n" if $debug
				return x
			end
		}
	else
		raise "ebsvol[aws]->volinfo: I couldn't read the volumes in region #{region}"
	end
	nil
    end

    # helper function to attach a volume to an instance
    #
    def attach_vol(compute,volume,instance,device)
    end

	
    # helper function to detach a volume to an instance
    #
    def detach_vol(compute,volume)
	response = compute.detach_volume(volume['volumeId'], 
			{ 'Device' => volume['attachmentSet'][0]['device'], 
			'Force' => true, 
			'InstanceId' => volume['attachmentSet'][0]['instanceId'] })
	if (response.status == 200)
		# now wait for it to detach!
		check = volinfo(compute,resource[:volume_name])
		while ( check['status'] != 'available' ) do
			print "ebsvol[aws]->destroy: status is #{check['status']}\n" if $debug
			sleep 5
			check = volinfo(compute,resource[:volume_name])
		end
		sleep 5  # allow aws to propigate the fact
		print "ebsvol[aws]->destroy: volume is now detached\n" if $debug
	else
		raise "ebsvol[aws]->destroy: Sorry, I could not detach #{volume['volumeId']} from #{volume['attachmentSet'][0]['instanceId']}"
	end
    end	

end
