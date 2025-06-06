cmake_minimum_required(VERSION 3.15)
project(template_component_package)

# default to C99
if(NOT CMAKE_C_STANDARD)
  set(CMAKE_C_STANDARD 99)
endif()

# default to C++20
if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 20)
endif()

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# find dependencies
find_package(ament_cmake_auto REQUIRED)
find_package(ament_cmake_python REQUIRED)

include(InstallAicaDescriptions)

ament_auto_find_build_dependencies()

include_directories(include)

### Register C++ Components ###

# Register CPPComponent
ament_auto_add_library(cpp_component SHARED ${PROJECT_SOURCE_DIR}/src/CPPComponent.cpp)
rclcpp_components_register_nodes(cpp_component "${PROJECT_NAME}::CPPComponent")
list(APPEND COMPONENTS cpp_component)
# Register CPPLifecycleComponent
ament_auto_add_library(cpp_lifecycle_component SHARED ${PROJECT_SOURCE_DIR}/src/CPPLifecycleComponent.cpp)
rclcpp_components_register_nodes(cpp_lifecycle_component "${PROJECT_NAME}::CPPLifecycleComponent")
list(APPEND COMPONENTS cpp_lifecycle_component)

###############################

install(TARGETS ${COMPONENTS}
        ARCHIVE DESTINATION lib
        LIBRARY DESTINATION lib
        RUNTIME DESTINATION bin)

install_aica_descriptions(./component_descriptions ${CMAKE_INSTALL_PREFIX}/component_descriptions)

# install Python modules
ament_python_install_package(${PROJECT_NAME} SCRIPTS_DESTINATION lib/${PROJECT_NAME})

if(BUILD_TESTING)
  find_package(ament_cmake_gtest REQUIRED)
  find_package(ament_cmake_pytest REQUIRED)

  # run cpp tests
  foreach(COMPONENT IN LISTS COMPONENTS)
    get_target_property(COMPONENT_LINK_LIBRARIES ${COMPONENT} LINK_LIBRARIES)
    list(APPEND LINK_LIBRARIES ${COMPONENT_LINK_LIBRARIES})
  endforeach()

  file(GLOB_RECURSE TEST_CPP_SOURCES ${PROJECT_SOURCE_DIR}/test/test_*.cpp)

  if(TEST_CPP_SOURCES)
    ament_add_gtest(test_cpp_components ${TEST_CPP_SOURCES})
    target_include_directories(test_cpp_components PRIVATE include)
    target_link_libraries(test_cpp_components ${COMPONENTS} ${LINK_LIBRARIES})

    # uncomment below if the test requires extra fixtures
    # target_compile_definitions(test_cpp_components PRIVATE TEST_FIXTURES="${CMAKE_CURRENT_SOURCE_DIR}/test/fixtures/")

    # prevent pluginlib from using boost
    target_compile_definitions(test_cpp_components PUBLIC "PLUGINLIB__DISABLE_BOOST_FUNCTIONS")
  endif()

  # run python tests
  file(GLOB_RECURSE TEST_PYTHON_SOURCES ${PROJECT_SOURCE_DIR}/test/ test_*.py)

  foreach(TEST_PYTHON IN LISTS TEST_PYTHON_SOURCES)
    get_filename_component(TEST_FILENAME ${TEST_PYTHON} NAME_WE)
    ament_add_pytest_test(${TEST_FILENAME} ${TEST_PYTHON})
  endforeach()

endif()

ament_auto_package()
