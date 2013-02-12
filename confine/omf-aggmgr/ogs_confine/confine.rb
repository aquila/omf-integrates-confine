require 'omf-aggmgr/ogs/gridService'
require 'omf-aggmgr/ogs_confine/mockPortal'
require 'omf-aggmgr/ogs_inventory/mySQLInventory'
require 'omf-aggmgr/ogs_inventory/inventory'
require 'omf-aggmgr/ogs_sliceManager/sliceManager'
require 'omf-aggmgr/ogs_confine/OMFPortal'
require "omf-common/communicator/xmpp/omfXMPPServices"
require 'omf-common/omfVersion'

class ConfineService < GridService

  # used to register/mount the service, the service's url will be based on it
  name 'confine'
  description 'Service to to access the CONFINE portal'

  @@omf = nil
  @@config = nil
  @@portal = nil
  @@sliceMgr = nil
  @@serviceXMPPdb = nil
 
  ROOT = "OMF_#{OMF::Common::MM_VERSION()}"
  PUBSUB_DOMAIN = 'omf.confine'
  PUBSUB_USER = "aggmgr"
  PUBSUB_PWD = "123"
  PUBSUB_DEFAULT_SLICE = "default_slice" # irony, right?

  def self.getPortal
   	# Just reuse it if it already exist
   	if ( @@portal == nil )
     		# Otherwise create it
     		@@portal = Confine::MockPortal.new
   	end
   	@@portal
  end

  def self.getSliceMgr
        # Just reuse it if it already exists
        if ( @@sliceMgr == nil )
                # Otherwise create it
                @@sliceMgr = SliceManagerService.new
        end
        @@sliceMgr
  end

  def self.getOMF
	# Just reuse it if it already exist
        if ( @@omf == nil )
        	# Otherwise create it
      		@@omf = Confine::OMFPortal.new @@config
        end
        @@omf
  end

  #
  # Configure the service through a hash of options
  # Also lists all configuration default that should be in confine.yaml
  # If defaults are missing, this is reported as an error and hardcoded defaults are taken as default.
  #
  # - config = the Hash holding the config parameters for this service
  #
  def self.configure(config)
    # Check if default sliver configuration is correct
    if ((dc = config['sliver']) == nil)
      raise ServiceError, "Missing 'sliver' configuration in confine.yaml"
    end
    # Check if db configuration is correct
    @@config = getTestbedConfig(PUBSUB_DOMAIN, config)
  end

  def self.mknode(node)
	dom = SliceManagerService.getPubSubDomain("confine-test1")
	SliceManagerService.create_pubsub_node(dom, "/#{ROOT}/#{PUBSUB_DEFAULT_SLICE}/resources/#{node.to_s}")
  end

  #
  # Implements allocating a slice at the CONFINE testbed
  #
  s_description "Allocate a slice in the CONFINE testbed"
  service 'allocateSlice' do
	puts ">>>>> Start allocating a new sliver"
        # Each CONFINE slice will be mapped to a OMF testbed.
        result = getPortal.createSlice

        getOMF.addInvTestbed(result[:testbed])
	invId = getOMF.getInvTestbedId(result[:testbed])
	puts "Inventory id of the testbed: #{invId}"

        replyXML = InventoryService.buildXMLReply("SLICE", result, "Failed to allocate a new slice.") { |root,result|
                InventoryService.addXMLElement(root, "OMF_TESTBED_NAME", "#{result[:testbed]}")
        }
        replyXML
  end

  #
  # Implements allocating a slivergroup at the CONFINE testbed
  # with paramater a slivergroup-configuration
  #

  s_description "Allocate CONFINE slivers in the slice (id)"
  s_param :sliceid, 'sliceid', 'id of the slice in which you want to allocate slivers'
  s_param :names, 'names', 'array van hostnames'
  s_param :imageid, '[imageid]', 'id of the image you want on the slivers'
  s_param :nwifi, '[nwifi]', 'number of wireless interfaces'
  s_param :neth, '[neth]', 'number of wired interfaces'
  service 'allocateSliverGroup' do |sliceid, names, imageid, nwifi, neth|
    	puts "id via allocateSlice"
	info "Entering allocateSliverGroup"
	info "Arguments: sliceid #{sliceid} names #{names} imageid #{imageid} nwifi #{nwifi} neth #{neth}"
	if names == nil
	        return return_error("FAKE CALL")
 	end
	info "NAMES: #{names}"  
	sliverXML = []
	
	if names.is_a?(String)
	    names = [names]
	else
	    names = names.to_ary
	end
	names_str = names.join(',')

	begin
		slivers = getPortal.createSliverGroup(sliceid.to_s, names, 'test')
       	 	testbedId = getOMF.getInvTestbedId(sliceid.to_s)

        	for i in 0..(names.length-1)
                	puts "addInvLocation #{names[i]}"
               	 	getOMF.addInvLocation(slivers[i][:location][:name],
                        	                slivers[i][:location][:x],
                                	        slivers[i][:location][:y],
                                        	slivers[i][:location][:z],
                                       	 	testbedId)
                	puts "getInvLocation #{names[i]}"
                	locationId = getOMF.getInvLocationId(slivers[i][:location][:name],
                        	                slivers[i][:location][:x],
                       			        slivers[i][:location][:y],
                               	         	slivers[i][:location][:z],
                               	         	testbedId)
                	puts "locationId: #{locationId}"
                	getOMF.addInvNode(slivers[i][:node][:control_ip],
                                        	slivers[i][:node][:control_mac],
                                        	slivers[i][:node][:hostname],
                                        	slivers[i][:node][:hrn],
                                        	locationId)
                	 sliverXML[i] = slivers[i][:node]
			
			 puts "Create a XMPP resource for #{slivers[i][:node][:hostname]}."			 
			 # Add node to Openfire database.
			mknode(slivers[i][:node][:hostname])
			puts "Created the XMPP resource for #{slivers[i][:node][:hostname]}."
        	end

		# SUCCESSFULL
		replyXML = InventoryService.buildXMLReply("SLIVERGROUP", sliverXML, "Failed to allocate a new slivers.") { |root,sliverXML|
			sliverXML.each { |sliverx|
				sliverElem = root.add_element("SLIVER")
				InventoryService.addXMLElement(sliverElem, "HOSTNAME", "#{sliverx[:hostname]}")
				InventoryService.addXMLElement(sliverElem, "HRN", "#{sliverx[:hrn]}")
      				InventoryService.addXMLElement(sliverElem, "CONTROL_IP", "#{sliverx[:control_ip]}")
				InventoryService.addXMLElement(sliverElem, "CONTROL_MAC", "#{sliverx[:control_mac]}")
			}
		}
	rescue HTTPStatus::InternalServerError
		raise HTTPStatus::InternalServerError
	rescue Exception => ex
		error ex.message
		replyXML = return_error(ex.message)
	end
	puts "Leaving to end allocateSliverGroup."
    replyXML
  end

end
