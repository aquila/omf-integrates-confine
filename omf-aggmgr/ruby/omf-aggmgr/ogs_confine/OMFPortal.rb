require 'omf-aggmgr/ogs_inventory/mySQLInventory'
require 'omf-aggmgr/ogs_inventory/inventory'

module Confine
	class OMFPortal
		@@config = nil

                def initialize(config)
                	@@config = config
	        end

	 	# Do generic database stuff
  		def doDB
        		begin
                		# Query the inventory
                		inv = InventoryService.getInv(@@config)
                		yield(inv)
        		rescue Exception => ex
                		error = "Inventory - Error connecting to the Inventory Database - '#{ex}''"
                		raise HTTPStatus::InternalServerError, error
        		end
 		end

		# Returns the id of the particular testbed in the OMF inventory.
		def getInvTestbedId(testbedName)
			result = Hash.new
			doDB { |inv|
                               	result = inv.getTestbedId(testbedName)
			}
			result['id']
		end

		# Returns the id of the particular location in the OMF inventory.
		def getInvLocationId(name, x, y, z, testbedId)
			result = Hash.new
			# Fill in the db id of the location of this node added in the db
                        doDB { |inv|
                                result = inv.getLocationId(name, x, y, z, testbedId)
                        }
			result['id']
		end
		
	        # Add a OMF testbed to the OMF inventory.
                def addInvTestbed(testbedName)
	                doDB { |inv|
                        	resultTestbed = inv.addTestbed(testbedName)
                       	}
		end
		
		# Add a OMF location, based on the CONFINE location, to the OMF inventory. 
		def addInvLocation(name, x, y, z, testbedId)
			location = makeInventoryLocation(name, x, y, z, testbedId)
			doDB do |inv|
                        	resultLocation = inv.addLocation(location)
			end
		end

		# Add a OMF node, based on the CONFINE sliver, to the OMF inventory.
		def addInvNode(control_ip, control_mac, hostname, hrn, locationId)
			node = makeInventoryNode(control_ip, control_mac, hostname, hrn, locationId)
			doDB do |inv|
				resultNode = inv.addNode(node)
			end
		end

		# Make up the location based on the CONFINE location of the sliver, for the OMF inventory.
                def makeInventoryLocation(name, x, y, z, testbedId)
                        location = Hash.new

                        # Fill in that received from CONFINE Portal
                        location['name'] = name
                        location['x'] = x
                        location['y'] = y
                        location['z'] = z
                        location['testbed_id'] = testbedId
			
			# DUMMY
			location['switch_ip'] = '10.0.0.201'
			location['switch_port'] = '1'

                        # return
                        location
                end

		# Make up the node based on the CONFINE sliver, for the OMF inventory.
  		def makeInventoryNode(control_ip, control_mac, hostname, hrn, locationId)
		        node = Hash.new

        		# Fill in that received from CONFINE Portal
        		node['control_ip'] = control_ip
        		node['control_mac'] = control_mac
    			node['hostname'] = hostname
		        node['hrn'] = hrn
			node['location_id'] = locationId

			# DUMMY values.
        		node['inventory_id'] = 1 
			node['chassis_sn'] = 'BOGUS SN 123'
			node['motherboard_id'] = 1
			node['pxeimage_id'] = 1
			node['disk'] = '/dev/sda'
			# return
			node
		end
	end
end
