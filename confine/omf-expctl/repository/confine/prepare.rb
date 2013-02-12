# Puts the experiment in prepare state;
#  loads the "preparing" experiment.
#  prints an overview

Experiment.prepare!

puts "testing everything"

defProperty('confine_experiment_file', '/home/glenn/experiments/helloworld.rb', 'The experiment to prepare...')

puts "here!!!!"

OConfig.load(property.confine_experiment_file.value, true, '.rb', 
             Confine::OEDLPreprocessor.instance.get_binding)

puts "I PREPARED... #{property.confine_experiment_file}"

Confine::OEDLPreprocessor.instance.printOverview
Confine::OEDLPreprocessor.instance.startReservation

Experiment.done

Experiment.close
