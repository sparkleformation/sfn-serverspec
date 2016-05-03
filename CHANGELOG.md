# v1.0.0
* Added support for validating compute resources in nested stacks (#5)
* Added alias for `after_update` callback (#6)
* Breaking: updated `sfn` dependency to >= 3.0, < 4.0 (#7)

# v0.1.4
* Relax sfn constraint to allow 2.0 versions

# v0.1.2
* Use inherited bogo-ui instance for log messages
* Fix incorrect scoping of methods on Sfn::Callback instead of Sfn::Callback::ServerspecValidator
* Add sfn command for running on-demand validation of existing stack

# v0.1.0
* Initial release
