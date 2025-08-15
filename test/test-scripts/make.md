# Running from the Make Tool Test Cases

* Should create a `environment/make-env` file that sets environment variables for Make based on the current application environment
* Should NOT print any errors or warnings to the console regarding bad configuration state. 
* Should log to a file any detected bad configuration state
* Should be able to execute Make commands from either the project root directory or the `environment` subdirectory
* Should ignore dynamic lookups by default
* Should include dynamic lookups if DYNAMIC_RESOLUTION == "y" or
  * Failed dynamic lookups should print to the console
* Should treat DR=y the same as DYNAMIC_RESOLUTION=y