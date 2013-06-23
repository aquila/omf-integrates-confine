require 'rest_client'
require 'json'
require 'colorize'
require 'date'
require 'typhoeus'

module Confine
        class CONFINEPortal
		@token = nil
		@server = nil
		@control_iface = nil
		@username = nil
		@password = nil

		# Initialize the CONFINE portal with values out of the configuration file.
                def initialize
			begin
				puts "Initializing CONFINE portal...".green

				config_filepath = "/usr/share/omf-aggmgr-5.4/omf-aggmgr/ogs_confine/confine.conf"
				config = JSON.parse( IO.read(config_filepath) )
				
				puts "Configuration file loaded in CONFINEPortal.".green

				# Ruby instance variables 'spring' into life the first they are assigned to, so assign these values before requesting the token.

				# Path to the template on the local machine
				@local_template_uri = '/home/glenn/omf-openwrt-testing-rootfs-latest.tar.gz'

				## SERVER (AUTHENTICATION & AUTHORIZATION)
				# URL of the server
				@server = config["server_auth"]["server"]
				@server_restclient = config["server_auth"]["server_restclient"]
				@username = config["server_auth"]["username"]
				@password = config["server_auth"]["password"]
				puts "Trying to retrieve the correct user...".green
				@user = getUser(@username)
				if (@user != nil)
					puts "Retrieved user '#{@user["username"]}' from server.".green
				else
					raise "Retrieving user '#{@user["username"]}' failed."
				end
				
				puts "Trying to retrieve token...".green
				# Token which grants access to the CONFINE REST API.
				@token = getToken
				if (@token != nil) # ? can the result of getToken be nil
                                        puts "Retrieved token '#{@token}' from server.".green
                                else
                                        raise "Retrieving token '#{@token}' failed."
                                end

				# Pubsub gateway
				@pubsub_gateway_name = config["pubsub"]["pubsub_gateway_name"]
				@pubsub_gateway_ip = config["pubsub"]["pubsub_gateway_ip"]

				# The control interface on the OMF RC that communicates with OMF.
				@control_iface = config["sliver_omf_control_iface"]
								
				# Experiment data dir uri
				@exp_data_dir_uri = config["exp_data_uri"]

				## DEFAULT TEMPLATE
				## Begin default template configuration
				default_template_conf = Hash.new
				default_template_conf['name'] = config["default_template"]["name"]
				default_template_conf['description'] = config["default_template"]["description"]
				default_template_conf['type'] = config["default_template"]["type"]
				default_template_conf['node_archs'] = config["default_template"]["node_archs"]
				default_template_conf['is_active'] = config["default_template"]["is_active"]
				default_template_conf['local_uri'] = config["default_template"]["local_uri"]
				## End default template configuration
				# Check if template with that name already exists.
				@default_template = getTemplate(default_template_conf['name'])
				if (@default_template == nil)
					@default_template = postTemplate(default_template_conf)
					puts "Default template '#{@default_template["name"]}' is created.".green
				else
					puts "Default template '#{@default_template["name"]}' does (already) exist.".green
				end

				## DEFAULT GROUP
				default_groupname = config["default_group"]
				@default_group = getGroup(default_groupname)
				if (@default_group == nil)
					raise "Default group #{default_groupname} does NOT exist!"
				else
					puts "Default group '#{@default_group["name"]}' does exist.".green
				end

				if (@default_group['allow_nodes'] == true && @default_group['allow_slices'] == true)
					puts "Default group '#{@default_group["name"]}' allows nodes and slices.".green
				else
					raise "Default group '#{@default_group["name"]}' does not allow nodes AND slices."
				end

				if (getIsAdmin)
					puts "'#{@user["username"]}' is admin in the group '#{@default_group["name"]}'.".green
				else
					raise "'#{@user["username"]}' is NOT admin in the group '#{@default_group["name"]}'."
				end

				puts "Initialization of the CONFINE portal complete.".green

				# A hash of arrays: each hash key, i.e. a slicename, corresponds to the already used nodes in that slice
				@slice_node_allocation = Hash.new{|hash, key| hash[key] = Array.new}
			rescue => e
				puts "Aborting initialization of CONFINE Portal: #{e.message}".red
				puts e.backtrace.join("\n").red
			end
                end

		def getToken
			#response = RestClient.post "#{@server}/api-token-auth/", {"username" => @username, "password" => @password}, :accept => :json
                        #response = Typhoeus.get("#{@server}/api/users/")

			response = Typhoeus::Request.new(
 	 			"#{@server}/api-token-auth/",
  				{ 	:method => :post,
					:headers => { :accept => "application/json" },
                                        :body => { "username" => @username, "password" => @password }
				}
			).run

			#puts "response :: #{response.body}"
			tokenAnswer = JSON.parse(response.body)
			return tokenAnswer['token']
		end

		# Request the URI to the default template
		# @param name The name of the template that is requested.
		# @return Return the URI if the template is found, otherwise return nil
		def getTemplate(name)
			response = RestClient.get("#{@server_restclient}/api/templates/")
			templates = JSON.parse(response)
			templates.each do |template|
				if (template['name'] == name)
					return template
				end
			end
			return nil
		end

		# Post the given template to the server.
		# @param template The template information about the template you want to post to the controller.
		# @return The template received from the server - based on the parameters that were given
		def postTemplate(template)
			begin
				puts "Uploading the template to the server... (please be patient)".green
				#response = Typhoeus::Request.new(
                                #"#{@server}/api/templates/",
                                # {       :method => :post,
                                #        :headers => { "Authorization" => "Token #{@token}", :accept => "application/json" },
                                #        :body => {      :image_uri => { :file => File.new("#{template["local_uri"]}", 'rb') },
				#			:name => template["name"],
                                #                        :description => template["description"],
				#			:type => template["type"],
                                #                        :node_archs => template["node_archs"],
                                #                        :is_active => true
                                #                 },
                                #}
                        	#).run
				response = RestClient.post "#{@server_restclient}/api/templates/",
					{
							:image_uri => File.new("#{template["local_uri"]}", 'rb'), 
							:name => template["name"], 
							:description => template["description"],
							:type => template["type"],
							:node_archs => template["node_archs"],
							:is_active => template["is_active"]
						}, 
						{	
							:accept => :json,
							"Authorization" => "Token #{@token}"
						}

				puts "POST a template '#{template["name"]}' with response code #{response.code}".green
				return getTemplate(template['name'])
			rescue RestClient::Exception => e
  				raise "POST a template failed:  #{e.response}"
			rescue => e
				raise "POST a templatess failed: #{e.message}"
				raise "POST a templates failed:  #{e.response}"
			end
		end

		# Request the URI to the default template
		# @param The name of the group you want.
		# @return Return the URI if the template is found, otherwise return nil
		def getGroup(name)
			response = RestClient.get "#{@server_restclient}/api/groups"
                        #response = Typhoeus.get("#{@server}/api/groups/")
			groups = JSON.parse(response)
			groups.each do |group|
				if (group['name'] == name)
					return group
				end
			end
			return nil
		end

		# Returns all the nodes set at the controller.
		# @return All the nodes in the controller.
                def getAllNodes
                        response = RestClient.get "#{@server_restclient}/api/nodes"
			#response = Typhoeus.get("#{@server}/api/nodes/")
                        nodes = JSON.parse(response)
			return nodes
                end

		# Get the uri's from the nodes in the group
		# @param name The name of the group of which we want the nodes
		# @return The uri's of the nodes of the group
		def getNodesInGroup(name)
			# Get the group
			group = getGroup(name)
			if group["nodes"].length == 0
				raise "Getting the nodes from the group: no nodes in the group"
			else
				return group["nodes"]
			end
		end

		# Get the user with the given username from the server
		# @param username The username of the user we want
		# @return The user based on the given username, nil if this user is not found
		def getUser(username)
			# response = Typhoeus.get("#{@server}/api/users/")
			response = RestClient.get "#{@server_restclient}/api/users/"
			users = JSON.parse(response)
			users.each do |user|
				if (user['username'] == username)
					return user
				end
			end
			return nil
		end
		
		# Check if the user defined in the initialization is an admin of the default_group also defined in the initialization
		# @return Returns true if the user is an admin, false otherwise.
		def getIsAdmin
			@user['group_roles'].each do |group|
				if (group['group']['uri'] == @default_group['uri'])
					if (group['is_admin'] == true)
						return true
					else
						return false
					end
				end
			end
			return false
		end

		# Returns the slice with the given slicename.
		# @param The name of the slice you want to be returned.
		# @return The slice with the given slicename or nil in case the slice does not exist.
		def getSlice(slicename)
			response = RestClient.get "#{@server_restclient}/api/slices"
			#response = Typhoeus.get("#{@server}/api/slices/")
			slices = JSON.parse(response)
			slices.each do |slice|
				if (slice['name'] == slicename)
					return slice
				end
			end
			return nil
		end

		# Generates a random slice name which is not yet used on the server
		# @return The slice name, random created.
		def genRandomSliceName
			slicename = ""
			# length of the random string			
			length = 6
			begin
				# generates random strings of lowercase a-z and 0-9
				random = rand(36**length).to_s(36)
				slicename = "omf_#{random}"
			end while (getSlice(slicename) != nil)
			return slicename
		end

		# Generates an expiration date ending in 1 month of today
		# @return The date one month from today.
		def genExpirationDate
			date = Date.today
			next_month = (date >> 1).to_s
			return next_month
		end
		
		# Post a a new slice in REGISTER state with a unique, random name to the server. Slices made for the OMF/CONFINE integration always start with 'omf_'.
		# @return The slice you just added to the server.
                def postSliceRegister
			name = genRandomSliceName
			expires_on = genExpirationDate
			# For the template, we use our default OMF template.
			template = JSON.generate Hash["uri", @default_template["uri"]]
			# For the group, we use our default OMF group.
			group = JSON.generate Hash["uri", @default_group["uri"]]
			description = "A auto-generated slice for the OMF/CONFINE integration."
			set_state = "register"
			vlan_nr = -1
			instance_sn = 0
			new_sliver_instance_sn = 0
			begin
  				response = RestClient.post "#{@server_restclient}/api/slices/", 
						{
							:group => group, 
						        :template => template, 
							:name => name,
							:description => description,
							:set_state => set_state,
							:vlan_nr => vlan_nr,
							:instance_sn => instance_sn,
							:new_sliver_instance_sn => new_sliver_instance_sn,
							:expires_on => expires_on
						}, 
						{
							:accept => :json,
							"Authorization" => "Token #{@token}"
						}
				puts "POST a slice '#{name}' (REGISTER state) with response code #{response.code}".green
				@slice_node_allocation[name] = Array.new
				return getSlice(name)
			rescue RestClient::Exception => e
  				raise "POST a slice (REGISTER state) failed (REST):  #{e.response}"
			rescue => e
				raise "POST a slice (REGISTER state) failed: #{e.message}"
			end
                end

		# PUT the slice with the given slice name in START state.
		# @param The name of the slice that you want to set to START state.
		# @return The slice you just added to the server.
		def putSliceStart(slice_name)
			slice = getSlice(slice_name)
			name = slice['name']
                        expires_on = slice['expires_on']
                        # For the template, we use our default OMF template.
                        template =  JSON.generate Hash["uri", @default_template["uri"]]
                        # For the group, we use our default OMF group.
                        group = JSON.generate Hash["uri", @default_group["uri"]]
                        description = "A auto-generated slice for the OMF/CONFINE integration."
                        set_state = "start"
                        vlan_nr = -1
                        instance_sn = 0
                        new_sliver_instance_sn = 0
                        begin
                                response = RestClient.put "#{slice['uri']}",
                                                {
                                                        :group => group,
                                                        :template => template,
                                                        :name => name,
                                                        :description => description,
                                                        :set_state => set_state,
                                                        :vlan_nr => vlan_nr,
                                                        :instance_sn => instance_sn,
                                                        :new_sliver_instance_sn => new_sliver_instance_sn,
                                                        :expires_on => expires_on
                                                },
                                                {
                                                        :accept => :json,
                                                        "Authorization" => "Token #{@token}"
                                                }
                                puts "PUT a slice '#{name}' (START state) with response code #{response.code}".green
                                @slice_node_allocation[name] = Array.new
                                return getSlice(name)
                        rescue RestClient::Exception => e
                                raise "PUT a slice (START state) failed (REST):  #{e.response}"
                        rescue => e
                                raise "PUT a slice (START state) failed: #{e.message}"
                        end

		end

		# Slices always have to be REGISTERed first, and STARTed later.
		# @return The slice that you added. Value nil if the creating of the slice failed.
		def createSlice
			puts "Trying to REGISTER a new slice...".green
			# Return the slice as it is returned by the server.
			slice = postSliceRegister
			puts "REGISTERed slice with name #{slice['name']}".green
			if slice != nil
				puts "Trying to START slice #{slice['name']}...".green
	                        return putSliceStart(slice['name'])
			else
				raise "REGISTERing the slice failed."
			end
			return nil
		end
		
		# Post the sliver to the controller.
		# @param slice_uri The uri where the sliver is added to.
		# @param node_uri The uri of the node where the sliver is added to.
		# @param extra_interfaces The interfaces that needs to be allocated for the experiments.
		# @return The URI of the newly added sliver.
		def postSliver(slice_uri, node_uri, extra_interfaces = nil)
			# The CONFINE sliver private (priv) interface.
			interfaces = Array.new
			interfacePriv = Hash["type", "private", "name", "priv"]
			interfaces.push interfacePriv
			interfaceMgmt = Hash["type", "management", "name", "mgmt0"]
			interfaces.push interfaceMgmt
			# Push the extra needed (for the OMF) experiment interfaces to the array.
			interfaces.concat extra_interfaces
			interfaces = JSON.generate interfaces

			description = "A auto-generated sliver for the OMF/CONFINE integration."
			slice = JSON.generate Hash["uri", slice_uri]
			node = JSON.generate Hash["uri", node_uri]
			template = JSON.generate Hash["uri", @default_template["uri"]]
			instance_sn = 0
			begin
  				response = RestClient.post "#{@server_restclient}/api/slivers/", 
						{
							:description => description, 
							:slice => slice, 
							:node => node,
							:interfaces => interfaces,
							:template => template,
							:instance_sn => instance_sn,
						}, 
						{
							:accept => :json,
							"Authorization" => "Token #{@token}"
						}
				puts "POST a sliver with response code #{response.code}".green
				parsedResponse = JSON.parse response
				
				# Return the uri of the sliver.
				return parsedResponse['uri']
			rescue RestClient::Exception => e
				if e.response.code == 422
					raise "POST a sliver failed (REST), probably wrong parent_name of isolated interface.  #{e.response}"
				else
	                                raise "POST a sliver failed (REST):  #{e.response}"
				end
			rescue => e
				raise "POST a sliver failed: #{e.message}"
			end

		end
		
		# Create specific CONFINE experiment data for the sliver for the given hrn.
		# @param slice The slice that needs to be filled in the OMF configuration file.
		# @param hrn The hrn of the OMF node (= CONFINE sliver).
		# @param control_if The control interface of OMF.
		# @param ifaces The extra interfaces of the experiment.
		# @return The uri to the newly created experiment data.
		def createExpData(slice, hrn, control_if, ifaces)
			file_name = "omf-resctl.yaml"
			full_path = "#{@exp_data_dir_uri}/default_etc/omf-resctl-5.4/#{file_name}"
			text = File.read(full_path)
  			text.gsub!(/_control_if_/, control_if)
			text.gsub!(/_pubsub_gateway_/, @pubsub_gateway_name)
			text.gsub!(/_name_/, hrn)
			text.gsub!(/_slice_/, slice)
			
			new_root_dir = "#{@exp_data_dir_uri}/etc"
			if (Dir["#{new_root_dir}"]) != nil
				system("rm -R #{new_root_dir}")
			end
			Dir.mkdir("#{new_root_dir}")

			Dir.mkdir("#{new_root_dir}/omf-resctl-5.4")
			new_full_path = "#{new_root_dir}/omf-resctl-5.4/omf-resctl.yaml"	
			File.open(new_full_path, "w") {|file| file.puts text} 

			file_name_hosts = "hosts"
                        full_path_hosts = "#{@exp_data_dir_uri}/default_etc/#{file_name_hosts}"
                        new_full_path_hosts = "#{new_root_dir}/#{file_name_hosts}"
			text_hosts = File.read(full_path_hosts)
                        text_hosts.gsub!(/_ipserver_/, @pubsub_gateway_ip)
                        text_hosts.gsub!(/_name_/, @pubsub_gateway_name)
			File.open(new_full_path_hosts, "w") {|file_hosts| file_hosts.puts text_hosts}

			Dir.mkdir("#{@exp_data_dir_uri}/etc/init.d")
			Dir.mkdir("#{@exp_data_dir_uri}/etc/rc.d")

			ipset_cmd = ""
			ifaces.each do |iface, addr|
				# WATCH OUT: the mask is manually set here! ASSUMING 10.0.0.0/8 adress!
				ipset_cmd << "cmd#{iface}=\"ip addr add #{addr}/8 dev #{iface}\"\n"
				ipset_cmd << "eval $cmd#{iface}\n" 
			end

			file_name_experiment = "omf-experiment"
			full_path_experiment = "#{@exp_data_dir_uri}/default_etc/init.d/#{file_name_experiment}"
			new_full_path_experiment = "#{new_root_dir}/init.d/#{file_name_experiment}"
			text_experiment = File.read(full_path_experiment)
			text_experiment.gsub!(/_command_/, ipset_cmd)
			File.open(new_full_path_experiment, "w") {|file_exp| file_exp.puts text_experiment}
			File.chmod(0755, new_full_path_experiment)

			new_full_path_experiment_symlink = "#{new_root_dir}/rc.d/S94#{file_name_experiment}"			

			File.symlink("../init.d/#{file_name_experiment}", new_full_path_experiment_symlink)
                        File.chmod(0755, new_full_path_experiment_symlink)

                        new_exp_data_name = "exp_data__#{hrn}__#{slice}__"
			new_exp_data_name = new_exp_data_name.gsub!(/\./, "_")
			output = system("cd #{@exp_data_dir_uri} && tar -zcvf #{new_exp_data_name}.tgz etc/ > /dev/null 2>&1")
			exp_data_uri = "#{@exp_data_dir_uri}/#{new_exp_data_name}.tgz"
				
			#puts "Created new #{exp_data_uri}."
						
			return exp_data_uri
		end

		# Uploads the experiment data to the sliver.
		# Cause of the temporarily implementation of the CONFINE controller API, first the sliver needs to be allocated before a exp_data file can be uploaded.
		# @param sliver_uri The uri of the sliver to which you want to upload the experiment data.
		# @param exp_data_uri The uri of the experiment data you want to upload to the sliver.
		def uploadSliverExpData(sliver_uri, exp_data_uri)
                        begin
				puts "Trying to upload experiment data (#{exp_data_uri}) to the sliver #{sliver_uri}.".green
                                response = RestClient.post "#{sliver_uri}/ctl/upload-exp-data/",
                                                {
                                                        :exp_data => File.new("#{exp_data_uri}", 'rb')
                                                },
                                                {
                                                        :accept => :json,
                                                        "Authorization" => "Token #{@token}"
                                                }
                                puts "POST experiment data to the sliver with response code #{response.code}".green
                        rescue RestClient::Exception => e
                                raise "POST experiment data to the sliver failed (REST):  #{e.response}"
                        rescue => e
                                raise "POST experiment data to the sliver failed: #{e.message}"
                        end
		end

		# Picks the node in the default group with the least slivers on it. Also, the node can NOT already have a sliver of this slice.
		# @param slicename The slice for which we pick a node
		# @return The URI of the node with the least load (= slivers) on it.
		def pickLeastLoadedNode(slicename)
			llnode_uri = ""
			least_load = 1000 # random (too) high value
			#puts "Come in pickLeastLoadedNode"
			#node_uris = getNodesInGroup(@default_group['name'])
			node_uris = getAllNodes # Returns all nodes, the 'uri' is in there.
			node_uris.each do |node_uri|
				response = RestClient.get "#{node_uri['uri']}"
                        	node = JSON.parse(response)

				# Retrieve the management adddress of the node.
				nodeMgmtIPv6 = node['mgmt_net']['addr'];

				# Get the info from the node itself...
				responseNode = Typhoeus.get("http://[#{nodeMgmtIPv6}]/confine/api/node/")
				if (responseNode.code == 200)
					nodeFromNode = JSON.parse(responseNode.body)
					# Only if the node is in production state, you can allocate slivers on this node.
					if (nodeFromNode["state"] == "production")
						puts "Node #{node_uri['uri']} is in PRODUCTION state (least loaded node election).".green
						load = node['slivers'].length
						if (load < least_load && !@slice_node_allocation[slicename].include?(node_uri['uri']))
							least_load = load
							llnode_uri = node_uri['uri']
						end
					else
						puts "Node #{node_uri['uri']} is not in PRODUCTION state, but in #{nodeFromNode["state"]} state (least loaded node election).".green
					end
				else
	                                puts "State link request to node #{node_uri['uri']} not successfull: node is not considered (least loaded node election).".green 
				end
				#puts "The load of node #{node['name']} is #{load}."
				#puts node
			end
			puts "Selected node (#{llnode_uri}) with least load.".green
			@slice_node_allocation[slicename].push llnode_uri
			#puts "Least load node_uri #{llnode_uri}"	
			return llnode_uri
		end

		def checkForSliverData(sliver_uri, node_uri)
			puts "Trying to retrieve information about new sliver (#{sliver_uri}).".green
			response = RestClient.get "#{node_uri}"
                        node = JSON.parse(response)
                        # Retrieve the management adddress of the node.
                        nodeMgmtIPv6 = node['mgmt_net']['addr'];

			# Get the sliver id out of the url.
			# The id is the number after the last "/".
			splitArray = sliver_uri.split("/")
			sliver_id = splitArray[(splitArray.length - 1)]

			# Compose the uri to retrieve the sliver data.
			sliver_info_uri = "http://[#{nodeMgmtIPv6}]/confine/api/slivers/#{sliver_id}/"

                        responseNode = Typhoeus.get("#{sliver_info_uri}")
			puts "Trying to reach sliver information on #{sliver_info_uri} (please be patient): ".green
			print "<".green
			nr_of_seconds = 0
			# Keep hitting the url until you get a valid connection (response code 200).
			while (responseNode.code != 200) do
				print "| #{responseNode.code} |".green
				STDOUT.flush
				sleep 10
                                responseNode = Typhoeus.get("#{sliver_info_uri}")
				nr_of_seconds = nr_of_seconds + 10
			end
			print ">".green
			puts "Retrieved sliver information after #{nr_of_seconds} seconds.".green
                       	sliverFromNode = JSON.parse(responseNode.body)
			
			# This will hold the ipv4 addr, retrieved from the sliver data.
			control_iface_ipv4 = ""
			# Run through the hash until you find the control interface.
                        sliverFromNode['interfaces'].each do |key, value|
                                if key['name'] == @control_iface 
                                        control_iface_ipv4 = key['ipv4_addr']
                                end
                        end
                        if control_iface_ipv4 == ""
                                raise "No #{control_iface} control interface found on sliver."
                        end
                        return control_iface_ipv4
		end


		# Create a sliver in the given slice with the hrn name and the number of interfaces.
		# @param slicename The slice to which you want to add the sliver.
		# @param hrn The hrn of the OMF node (= CONFINE sliver).
		# @param wired_ifaces JSON with the wired interfaces needed for the experiment.
		# @param wireless_ifaces JSON with the wireless interfaces needed for the experiment.
		# @return The sliver information.
                def createSliver(slicename, hrn, wired_ifaces, wireless_ifaces)
			extra_interfaces = Array.new
			
			wired_ifaces_hash = JSON.parse wired_ifaces
			wireless_ifaces_hash = JSON.parse wireless_ifaces

			# Add all the interfaces to this Hash, which will be used in the createExpData method.
			ifaces = Hash.new

			wireless_count = 0
			wireless_ifaces_hash.each do |iface, addr|
                                puts "Extra interface (#{iface}) added.".green
                                interface = Hash.new
                                interface['parent_name'] = "wlan#{wireless_count}"
                                interface['type'] = 'isolated'
                                interface['name'] = "#{iface}"
				ifaces["#{iface}"] = "#{addr}"
                                extra_interfaces.push interface
				wireless_count = wireless_count + 1
                        end

			wired_count = 0
			wired_ifaces_hash.each do |iface, addr|
				puts "Extra interface (#{iface}) added.".green
				interface = Hash.new
				interface['parent_name'] = "eth#{wired_count}"
				interface['type'] = 'isolated'
				interface['name'] = "#{iface}"
				ifaces["#{iface}"] = "#{addr}"
				extra_interfaces.push interface
				wired_count = wired_count + 1
			end

			# This is the OMF control (omfc) interface that we'll need for controlling/communicating (about) the OMF experiment.
                        control_if = @control_iface
                        control_interface = Hash["type", "public4", "name", "#{control_if}"]
                        extra_interfaces.push control_interface

			exp_data_uri = createExpData(slicename, hrn, control_if, ifaces)

			slice_uri = getSlice(slicename)["uri"]
			node_uri = pickLeastLoadedNode(slicename)
			sliver_uri = postSliver(slice_uri, node_uri, extra_interfaces)
			uploadSliverExpData(sliver_uri, exp_data_uri)
			control_iface_ipv4 = checkForSliverData(sliver_uri, node_uri)

			puts "Created a new sliver on CONFINE slice '#{slicename}'.".green
			sliver = Hash.new{|hash, key| hash[key] = Hash.new}
                        sliver[:node][:control_ip] = control_iface_ipv4 # dummy value
                        sliver[:node][:control_mac] = '00:03:2D:08:1A:88' # dummy value
                        sliver[:node][:hostname] = "#{hrn}" # NOT right
                        sliver[:node][:hrn] = "#{hrn}"
                        sliver[:location][:x] = rand(15).to_s
                        sliver[:location][:y] = rand(15).to_s
                        sliver[:location][:z] = rand(15).to_s
                        sliver[:location][:name] = "CONFINE.#{sliver[:location][:x]}.#{sliver[:location][:y]}.#{sliver[:location][:z]}"
                        sliver[:location][:testbedname] = "#{slicename}"
			sliver
          	end

		def checkAvailability
                        # Check if there are enough nodes available
                        #nodes = getNodesInGroup(@default_group['name'])
			nodes = getAllNodes
			return nodes.length
		end
        end
end

#portal = Confine::CONFINEPortal.new
#puts portal.getNodesInGroup("omf_group")
#portal.createTemplate('/home/glenn/Downloads/omf-openwrt-testing-rootfs-latest.tar.gz', 'test6', 'Descripton of template6', 'debian6', 'x86', true)
#puts portal.postSlice
#puts portal.postSliver
