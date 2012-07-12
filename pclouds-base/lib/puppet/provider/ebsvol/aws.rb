require 'rubygems'
require 'fog'

$debug=true

Puppet::Type.type(:ebsvol).provide(:aws) do
    desc "AWS provider to ebsvol types"

    commands :fog => '/usr/bin/fog'
    confine :ec2_profile => 'default-paravirtual'

    def create
    	region = resource[:availability_zone].to_s.gsub(/.$/,'') 
	compute = Fog::Compute.new(:provider => 'aws', :region => "#{region}")
	print "ebsvol[aws]->create: Region is #{region}\n" if $debug
	print "ebsvol[aws]->create: Availability_zone is #{resource[:availability_zone]}\n" if $debug
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
	if (volume != nil) 
		if ( volume['status'] == 'in-use' && volume['attachmentSet'] != nil )
			if ( volume['attachmentSet'][0]['status'] == 'attached' && 
			volume['attachmentSet'][0]['device'] != nil && volume['attachmentSet'][0]['instanceId'] != nil)
				# detach the volume
				detachvol(compute,volume)
			end
		end
		print "ebsvol[aws]->destroy: deleting #{volume['volumeId']}\n" if $debug
		response = compute.delete_volume(volume['volumeId'])
		if ( response.status == 200) 
			print "ebsvol[aws]->destroy: I successfully deleted #{volume['volumeId']}\n" if $debug
		else
			raise "ebsvol[aws]->destroy: Sorry, I could not delete the volume!"
		end
	else
		raise "ebsvol[aws]->destroy: Sorry! I couldn't find the volume #{resource[:volume_name]} to delete"
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

    # Helper Methods.  These are not called by puppet, only the methods above.

    # retrieve a volumes information given its Name tag
    # list the volumes in the region and look for one with a Name tag which matches our name.
    # returns the volumeSet associative array... or nil
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
		raise "ebsvol[aws]->volinfo: I couldn't list the ebsvolumes"
	end
	nil
    end

    # for looking up information about an ec2 instance given the Name tag
    def instanceinfo(compute,name)
	resp = compute.describe_instances	
	if (resp.status == 200)
		# check through the instances looking for one with a matching Name tag
		resp.body['reservationSet'].each { |x|
			x['instancesSet'].each { |y| 
				if ( y['tagSet']['Name'] == name)
					return y
				end
			}
		}
	else
		raise "ebsvol[aws]->instanceinfo: I couldn't list the instances"
	end
	nil
    end	

    # helper function to attach a volume to an ec2 instance
    def attachvol(compute,volume,instance,device)
    	if (volume['status'] != "in-use" )
		# check instance is in the same availability zone
		if ( volume['availabilityZone'] != instance['placement']['availabilityZone'])
			raise "ebsvol[aws]->attachvol: Sorry, volumes must be in the same availability zone as the instance to be attached to.\nThe volume #{volume['tagSet']['Name']} is in availability zone #{volume['availabilityZone']} and the instance is in #{instance['placement']['availabilityZone']}"  
		else
			# check that the device is available
			inuse = false
			instance['blockDeviceMapping'].each { |x| inuse=true if x['deviceName'] == device }
			if ( inuse )
				raise "ebsvol[aws]->attachvol: Sorry, the device #{device} is already in use on #{instance['tagSet']['Name']}"  
			else
				resp = compute.attach_volume(instance['instanceId'],volume['volumeId'],device)
				if (response.status == 200)
					# now wait for it to attach!
					check = volinfo(compute,volume['tagSet']['Name'])
					while ( check['status'] != 'attached' ) do
						print "ebsvol[aws]->attachvol: status is #{check['status']}\n" if $debug
						sleep 5
						check = volinfo(compute,volume['tagSet']['Name'])
					end
					sleep 5  # allow aws to propigate the fact
					print "ebsvol[aws]->attachvol: volume is now attached\n" if $debug
				end
			end
		end
	else
		raise "ebsvol[aws]->destroy: Sorry, I could not detach #{volume['volumeId']} from #{volume['attachmentSet'][0]['instanceId']}"
	end
    end

    # detach a volume from the instance it is attached to.
    def detachvol(compute,volume)
	print "ebsvol[aws]->destroy: detaching #{volume['volumeId']} from #{volume['attachmentSet'][0]['instanceId']}\n" if $debug
	response = compute.detach_volume(volume['volumeId'], 
		{ 'Device' => volume['attachmentSet'][0]['device'], 
		'Force' => true, 
		'InstanceId' => volume['attachmentSet'][0]['instanceId'] })
	if (response.status == 200)
		# now wait for it to detach!
		check = volinfo(compute,volume['tagSet']['Name'])
		while ( check['status'] != 'available' ) do
			print "ebsvol[aws]->destroy: status is #{check['status']}\n" if $debug
			sleep 5
			check = volinfo(compute,volume['tagSet']['Name'])
		end
		sleep 5  # allow aws to propigate the fact
		print "ebsvol[aws]->destroy: volume is now detached\n" if $debug
	else
		raise "ebsvol[aws]->destroy: Sorry, I could not detach #{volume['volumeId']} from #{volume['attachmentSet'][0]['instanceId']}"
	end
    end

end
