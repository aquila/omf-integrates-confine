require 'omf-expctl/handlerCommands'
require 'colorize'
require 'json'

class OMF::EC::Node < MObject
    attr_reader :w0
    attr_reader :w1
    attr_reader :w0_value
    attr_reader :w1_value
    
    attr_reader :e0
    attr_reader :e1
    attr_reader :e0_value
    attr_reader :e1_value
end

module Confine

    # A node with extra info.
    module Node
        def confineInit
            @e0 = @e1 = @w0 = @w1 = false
	    @e0_value = @e1_value = @w1_value = @w2_value = ""
        end
    
        # Changed configure path function
        # When configuring a path, store that it is being used.
	# Here is checked if the path values are equal to the interfaces, if so store this in the node.
        def configure path, value, status = 'Unknown'
	    if path[0] == "net" && path[1] == 'e0'
                @e0 = true
		@e0_value = value
            end
	    if path[0] == "net" && path[1] == 'e1'
		@e1 = true
		@e1_value = value
	    end
            if path[0] == "net" && path[1] == 'w0'
                @w0 = true
		@w0_value = value
            end
            if path[0] == "net" && path[1] == 'w1'
                @w1 = true
		@w2_value = value
            end
        end
    end

    # Alternative OEDL processor, with different side effects
    class OEDLPreprocessor
        include Singleton
        include OMF::EC::NodeSetHelper
        
        def initialize
            @nodes = []
        end
        
        def defProperty(name, defaultValue, description)
            ExperimentProperty.create(name, defaultValue, description)
        end
        
        #
        # Return the context for setting experiment wide properties
        #
        # [Return] a Property Context
        #
        def prop
            return PropertyContext
        end

        alias :property :prop
        
        def defTopology(refName, nodeArray = nil, &block)
            topo = Topology.create(refName, nodeArray)
            if (! block.nil?)
                block.call(topo)
            end
            return topo
        end
        
        def defPrototype(refName, name = nil, &block)
            p = Prototype.create(refName)
            p.name = name
        end
        
        def defGroup(groupName, selector = nil, &block)
            ns = selectNodeSet groupName, selector
            
            ns.each do |node|
                node.extend Node
                node.confineInit
                @nodes << node
            end
            
            return RootNodeSetPath.new(ns, nil, nil, block)
        end
        
        def group(groupName, &block)
            ns = NodeSet[groupName.to_s]
            if (ns == nil)
                return EmptyGroup.new
            end
            return RootNodeSetPath.new(ns, nil, nil, block)
        end
        
        def resource(resName)
        end
        
        def allGroups(&block)
            NodeSet.freeze
            ns = DefinedGroupNodeSet.instance
            return RootNodeSetPath.new(ns, nil, nil, block)
        end
        
        def allNodes!(&block)
        end
        
        def defEvent(name, interval = 5, &block)
        end
        
        def onEvent(name, consumeEvent = false, &block)
            if name != :EXPERIMENT_DONE
                yield
            end
        end
        
        def every(name, interval = 60, initial = nil, &block)
            yield block
        end
        
        def everyNS(selector, interval = 60, &block)
            ns = NodeSet[nodesSelector]
            if ns == nil
                raise "Every: Unknown node set '#{nodesSelector}"
            end
            path = RootNodeSetPath.new(ns)
            path.call &block
        end
        
        def antenna(x, y, precision = nil)
        end
        
        def msSenderName
        end
        
        def addTab(tName, opts = {}, &initProc)
        end
        
        def t1()
        end
        
        def wait(time)
        end
        
        def info(*msg)
        end
        
        def warn(*msg)
        end
        
        def error(*msg)
        end
        
        def quit()
        end
        
        def lsx(xpath = nil)
        end
        
        def ls(xpath = nil)
        end
        
        # Print a small overview for the nodes
        def printOverview
            @nodes.each do |node|
                puts node.nodeID + " " + (node.e0.to_s) + " " + node.e0_value.to_s +
                                         (node.e1.to_s) + " " + node.e1_value.to_s +
                                         (node.w0.to_s) + " " + node.w0_value.to_s +
                                         (node.w1.to_s) + " " + node.w1_value.to_s
            end
        end
        
        # Start the reservation of the sliver for the OMF experiment.
	# Will allocate a CONFINE slice first and afterwards the necessary CONFINE slivers which correspond to the OMF nodes.
        def startReservation
	    puts "CONFINE start reservation.".green 
            confine = OMF::Services.confine
	    nr_resources = 0
	    response = confine.checkForResources
	    if response == nil
		raise "Error: Got NO response from server. Cancelling reservation."
	    end
	    resources_el = response.elements.first
            if resources_el.name == "CHECK_FOR_RESOURCES"
	            nr_resources = resources_el.elements['NR_RESOURCES'].first
		    #puts "NUMBER OF RESOURCES : #{nr_resources}"
            else
                    raise "ERROR while checking for resources: " + resources_el.text
            end
	   # puts "#{nr_resources} >= #{@nodes.length}"
	    if (nr_resources >= @nodes.length)
		    response = confine.allocateSlice
		    slicename = ""            
       	 	    slice_el = response.elements.first
       	            if slice_el.name == "SLICE"
			# Id of the testbed (~ CONFINE slice) in the OMF inventory.
			# The CONFINE sliceId (~ OMF testbed name)
                		slicename = slice_el.elements['OMF_TESTBED_NAME'].first
				puts "The slice on which we will allocate slivers is '#{slicename}'".green
            	    else
                		raise "ERROR while receiving slicename in startReservartion: " + slice_el.text
            	    end
            
		    wired_interfaces = Hash.new
		    wireless_interfaces = Hash.new
            	    @nodes.each do |node|
			if node.e0
				wired_interfaces['eth0'] = node.e0_value
			end
			if node.e1
				wired_interfaces['eth1'] = node.e1_value
			end
			if node.w0
				wireless_interfaces['wlan0'] = node.w0_value
			end
			if node.w1
				wireless_interfaces['wlan1'] = node.w1_value
			end

			wired_interfaces_json = JSON.generate wired_interfaces
                        wireless_interfaces_json = JSON.generate wireless_interfaces
		
			puts "Node #{node.nodeID} wants #{wired_interfaces.length} ethernet interfaces and #{wireless_interfaces.length} wireless interfaces.".green
       	        	# Not looking at interface yet, just reserve 2 wired
       	        	# and 2 wireless links.
       		        # Also not looking at the "imageID".
       	       		g = confine.allocateSliver(
					:slicename => slicename, 
       	                                :hrn => node.nodeID,
                                        :wired_ifaces => wired_interfaces_json,
					:wireless_ifaces => wireless_interfaces_json
					)
			puts "Allocated a new CONFINE sliver (with hrn = #{node.nodeID}) as a OMF resource on slice #{slicename}.".green
            	end
            else
		raise "ERROR Not enough CONFINE resources to execute this OMF experiment."
	    end
        end
        
        def get_binding
            binding
        end
    end
end
