
# SRAM macro power delivery
# SRAM power pins are available on Metal3.
# Connect the macro power grid to Metal4.

define_pdn_grid \
    -macro \
    -instances cpu.data_ram \
    -name sram_macros_NS \
    -starts_with POWER \
    -halo "1.0 1.0"

add_pdn_connect \
    -grid sram_macros_NS \
    -layers "Metal4 Metal3"
