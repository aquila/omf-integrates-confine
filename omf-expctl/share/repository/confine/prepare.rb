require 'colorize'

#  Puts the experiment in prepare state;
#  loads the "preparing" experiment.

Experiment.prepare!

# If no confine_experiment_file is found, load this default one...
defProperty('confine_experiment_file', '/home/glenn/experiments/helloworld.rb', 'The experiment to prepare...')

# Template properties
#defProperty('confine_template_image_uri', 'test.tar.gz', 'The image for the slice')
#defProperty('confine_template_descr', 'Default description', 'The description for the template')
#defProperty('confine_template_type', 'debian6', 'The type of the template')
#defProperty('confine_template_node_archs', 'x86', 'The node architecture')
#defProperty('confine_template_node_isactive', 'true', 'Active or not')

OConfig.load(property.confine_experiment_file.value, true, '.rb', 
             Confine::OEDLPreprocessor.instance.get_binding)

#Confine::OEDLPreprocessor.instance.printOverview
Confine::OEDLPreprocessor.instance.startReservation

#Experiment.done

#Experiment.close

# By unprepraring, OMF can start the actual experiment.
Experiment.unprepare!

puts "All CONFINE resources are allocated.".green
