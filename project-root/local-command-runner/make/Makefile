-include environment/Makefile
export

##@ General
help: ## Show help message
	@awk 'BEGIN {FS = ": .*##"; printf "\nUsage:\n make \033[36m<target>\033[0m\n"} /^[$$()% 0-9a-zA-Z_-]+(\\:[$$()% 0-9a-zA-Z_-]+)*:.*?##/ { gsub(/\\:/,":", $$1); printf " \033[36m%-30s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(firstword $(MAKEFILE_LIST))

coin-help: csh ## Show COIN Shell help message

##@ App
