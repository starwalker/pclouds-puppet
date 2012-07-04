#!/usr/bin/ruby
#
# Create facts for all of the arguments entered in the user-data field.
# Run the bash script helper and create the facts.

arguments = `/etc/puppet/modules/pclouds-base/lib/facter/ec2_user_data_helper.sh`
if (arguments != nil) 
	#print "#{arguments}";
	arguments.each {|x|
		fact,value = x.split(':==:')
		Facter.add("pclouds_#{fact}") do

  			setcode do
				value
  			end
		end
	}
else
	raise "Sorry, I could not read any arguments"
end
	
