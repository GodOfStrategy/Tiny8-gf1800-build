
# Load the standard LibreLane PDN configuration
source $::env(SCRIPTS_DIR)/openroad/common/pdn_cfg.tcl

# Add the SRAM-specific power grid
source $::env(DESIGN_DIR)/pdn_3v3_sram.tcl
