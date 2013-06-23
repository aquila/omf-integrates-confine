require 'omf-aggmgr/ogs/gridService'
require 'omf-aggmgr/ogs_inventory/mySQLInventory'
require 'omf-aggmgr/ogs_inventory/inventory'
require 'omf-aggmgr/ogs_sliceManager/sliceManager'
require 'omf-aggmgr/ogs_confine/OMFPortal'
require 'omf-aggmgr/ogs_confine/CONFINEPortal'
require "omf-common/communicator/xmpp/omfXMPPServices"
require 'omf-common/omfVersion'
require 'json'
require 'colorize'

class ConfineService < GridService

  # used to register/mount the service, the service's url will be based on it
  name 'confine'
  description 'Service to to access the CONFINE portal'

  @@omf = nil
  @@config = nil
  @@portal = nil
  @@sliceMgr = nil
  @@serviceXMPPdb = nil
 
  config_filepath = "/usr/share/omf-aggmgr-5.4/omf-aggmgr/ogs_confine/confine.conf"
  config = JSON.parse( IO.read(config_filepath) )

  ROOT = "OMF_#{OMF::Common::MM_VERSION()}"
  PUBSUB_DOMAIN = config['pubsub']['pubsub_domain']
  PUBSUB_USER = config['pubsub']['pubsub_username']
  PUBSUB_PWD = config['pubsub']['pubsub_passwd']
  # PUBSUB_DEFAULT_SLICE = "default_slice" # irony, right?

  def self.getPortal
   	# Just reuse it if it already exist
   	if ( @@portal == nil )
     		# Otherwise create it
     		@@portal = Confine::CONFINEPortal.new
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

  def self.mkNode(slice, node)
	dom = SliceManagerService.getPubSubDomain("confine-test1")
	SliceManagerService.create_pubsub_node(dom, "/#{ROOT}/#{slice}/resources/#{node.to_s}")
  end

  def self.mkSlice(slice)
	dom = SliceManagerService.getPubSubDomain("confine-test1")
	SliceManagerService.create_pubsub_node(dom, "/#{ROOT}/#{slice}")
	SliceManagerService.create_pubsub_node(dom, "/#{ROOT}/#{slice}/resources")
  end

  #
  # Service that returns the number of available resources.
  #
  s_description "Checks for enough CONFINE resources"
  service 'checkForResources' do
	nr_resources = getPortal.checkAvailability
	result = Hash[ "nr_resources", nr_resources ]
        replyXML = InventoryService.buildXMLReply("CHECK_FOR_RESOURCES", result, "Failed to check for resources.") { |root,result|
                InventoryService.addXMLElement(root, "NR_RESOURCES", "#{result['nr_resources']}")
        }
        replyXML
  end

  #
  # Service that implements allocating a slice at the CONFINE testbed
  #
  s_description "Allocate a slice in the CONFINE testbed"
  service 'allocateSlice' do
        # Each CONFINE slice will be mapped to a OMF testbed.
	result = getPortal.createSlice

	if result == nil
		raise "Creating a slice failed..."
	end

        getOMF.addInvTestbed(result["name"])
	invId = getOMF.getInvTestbedId(result["name"])
	#puts "Inventory id of the testbed: #{invId}"

        mkSlice(result["name"])

        replyXML = InventoryService.buildXMLReply("SLICE", result, "Failed to allocate a new slice.") { |root,result|
                InventoryService.addXMLElement(root, "OMF_TESTBED_NAME", "#{result['name']}")
        }
        replyXML
  end

  #
  # Implements allocating a slivergroup at the CONFINE testbed
  # with paramater a slivergroup-configuration
  #
  s_description "Allocate CONFINE sliver in the slice(name)"
  s_param :slicename, 'slicename', 'name of the slice in which you want to allocate sliver'
  s_param :hrn, 'hrn', 'OMF hrn of this sliver'
  s_param :wired_ifaces, 'wired_ifaces', 'Wired interfaces'
  s_param :wireless_ifaces, 'wireless_ifaces', 'Wireless interfaces'
  service 'allocateSliver' do |slicename, hrn, wired_ifaces, wireless_ifaces|	
	begin
		sliver = getPortal.createSliver(slicename.to_s, hrn.to_s, wired_ifaces.to_s, wireless_ifaces.to_s)
       	 	testbedId = getOMF.getInvTestbedId(slicename.to_s)

               	#puts "addInvLocation #{hrn}"
          	getOMF.addInvLocation(sliver[:location][:name],
                      	                sliver[:location][:x],
                               	        sliver[:location][:y],
                                       	sliver[:location][:z],
                             	 	testbedId)
                #puts "getInvLocation #{hrn}"
                locationId = getOMF.getInvLocationId(sliver[:location][:name],
                      	                sliver[:location][:x],
                		        sliver[:location][:y],
                                 	sliver[:location][:z],
                                 	testbedId)
                #puts "locationId: #{hrn}"
                getOMF.addInvNode(sliver[:node][:control_ip],
                                       	sliver[:node][:control_mac],
                                       	sliver[:node][:hostname],
                                       	sliver[:node][:hrn],
                                       	locationId)
                sliverXML = sliver[:node]
			
		# puts "Create a XMPP resource for #{sliver[:node][:hostname]}."			 
		# Add node to Openfire database.
		mkNode(slicename.to_s, sliver[:node][:hostname])
		#puts "Created the XMPP resource for #{sliver[:node][:hostname]}."
        	
		# SUCCESSFULL
		replyXML = InventoryService.buildXMLReply("SLIVERGROUP", sliverXML, "Failed to allocate a new slivers.") { |root,sliverXML|
				sliverElem = root.add_element("SLIVER")
				InventoryService.addXMLElement(sliverElem, "HOSTNAME", "#{sliverXML[:hostname]}")
				InventoryService.addXMLElement(sliverElem, "HRN", "#{sliverXML[:hrn]}")
      				InventoryService.addXMLElement(sliverElem, "CONTROL_IP", "#{sliverXML[:control_ip]}")
				InventoryService.addXMLElement(sliverElem, "CONTROL_MAC", "#{sliverXML[:control_mac]}")
		}
	rescue HTTPStatus::InternalServerError
		raise HTTPStatus::InternalServerError
	rescue Exception => ex
		error ex.message
		replyXML = return_error(ex.message)
	end
    	replyXML
  end

end
