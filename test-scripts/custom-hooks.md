# Custom Hooks Test Cases

* Should execute hooks that are configured in `environment/constants.sh`
    * Hooks added to the `COIN_BEFORE_HOOKS` array should run after the current environment configurations are loaded but before any COIN commands execute
    * Hooks added to the `COIN_AFTER_SWITCH_ENV_HOOKS` array should be run after the user executes `make sce`