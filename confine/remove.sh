#!/bin/bash

# Install the CONFINE components in the OMF environment
sudo rake ../Rakefile omf_dev:remove_confine
echo "> CONFINE components removed from OMF environment."

# Install the OMF environment on the local machine
sudo rake ../Rakefile omf_dev:remove
echo "> OMF removed from local machine."

# Reverse patch Aggregate manager
patch -R ../omf-aggmgr/ruby/omf-aggmgr/ogs_inventory/mySQLInventory.rb < patches/omf-aggmgr/mySQLInventory.patch
patch -R ../omf-aggmgr/ruby/omf-aggmgr/ogs.rb < patches/omf-aggmgr/ogs.patch
patch -R ../omf-aggmgr/ruby/omf-aggmgr/ogs_sliceManager/sliceManager.rb < patches/omf-aggmgr/sliceManager.patch

# Reverse patch Experiment controller
patch -R ../omf-expctl/ruby/omf-expctl/experiment.rb < patches/omf-expctl/experiment.patch
patch -R ../omf-expctl/ruby/omf-expctl/handlerCommands.rb < patches/omf-expctl/handlerCommands.patch
patch -R ../omf-expctl/ruby/omf-expctl/nodeHandler.rb < patches/omf-expctl/nodeHandler.patch
patch -R ../omf-expctl/ruby/omf-expctl/oconfig.rb < patches/omf-expctl/oconfig.patch
patch -R ../omf-expctl/share/repository/system/exp/stdlib.rb < patches/omf-expctl/stdlib.patch

# Reverse patch the Rakefile
patch -R ../Rakefile < patches/rakefile.patch
