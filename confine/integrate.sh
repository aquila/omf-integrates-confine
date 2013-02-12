#!/bin/bash

patch ../Rakefile < patches/rakefile.patch

# Install the CONFINE components in the OMF environment
sudo rake ../Rakefile omf_dev:install_confine
echo "> CONFINE components installed in OMF environment."

# Install the OMF environment on the local machine
sudo rake ../Rakefile omf_dev:install
echo "> OMF installed on local machine."

# Patch Aggregate manager
patch ../omf-aggmgr/ruby/omf-aggmgr/ogs_inventory/mySQLInventory.rb < patches/omf-aggmgr/mySQLInventory.patch
patch ../omf-aggmgr/ruby/omf-aggmgr/ogs.rb < patches/omf-aggmgr/ogs.patch
patch ../omf-aggmgr/ruby/omf-aggmgr/ogs_sliceManager/sliceManager.rb < patches/omf-aggmgr/sliceManager.patch

# Patch Experiment controller
patch ../omf-expctl/ruby/omf-expctl/experiment.rb < patches/omf-expctl/experiment.patch
patch ../omf-expctl/ruby/omf-expctl/handlerCommands.rb < patches/omf-expctl/handlerCommands.patch
patch ../omf-expctl/ruby/omf-expctl/nodeHandler.rb < patches/omf-expctl/nodeHandler.patch
patch ../omf-expctl/ruby/omf-expctl/oconfig.rb < patches/omf-expctl/oconfig.patch
patch ../omf-expctl/share/repository/system/exp/stdlib.rb < patches/omf-expctl/stdlib.patch
