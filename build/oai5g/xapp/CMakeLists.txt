# EMS E2SM metrics xApp.
#
# The gNB image copies build/oai5g/xapp into
# openair2/E2AP/flexric/examples/xApp/c/ems so the binary is produced by the
# FlexRIC build itself. That lets it link the e42_xapp target and inherit the
# exact E2AP/KPM versions the gNB E2 agent was compiled with, which is a
# hard requirement for the two to talk to each other.

set(FLEXRIC_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../..")

add_executable(ems_gnb_metrics_xapp
  ems_gnb_metrics_xapp.c
  ems_metrics_json.c
  frozen/frozen.c
)

target_include_directories(ems_gnb_metrics_xapp PRIVATE ${FLEXRIC_ROOT})

target_link_libraries(ems_gnb_metrics_xapp
  PUBLIC
  e42_xapp
  -pthread
  -lsctp
  -ldl
  )

install(TARGETS ems_gnb_metrics_xapp DESTINATION ${CMAKE_INSTALL_BINDIR})
