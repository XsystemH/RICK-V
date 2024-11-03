open_hw_manager
connect_hw_server
open_hw_target
set mydev [ get_hw_devices xc7a35t_0 ]
current_hw_device $mydev
# refresh_hw_device -update_hw_probes false
set_property PROGRAM.FILE [lindex $argv 0] $mydev
set_property PROBES.FILE {} $mydev
set_property FULL_PROBES.FILE {} $mydev
program_hw_devices
refresh_hw_device
disconnect_hw_server localhost:3121
